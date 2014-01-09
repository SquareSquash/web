# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'csv'

# Controller for working with a {Bug}'s {Occurrence Occurrences}.
#
# Common
# ======
#
# Path Parameters
# ---------------
#
# |                  |                          |
# |:-----------------|:-------------------------|
# | `project_id`     | The {Project}'s slug.    |
# | `environment_id` | The {Environment} name.  |
# | `bug_id`         | The Bug number (not ID). |

class OccurrencesController < ApplicationController
  include ActionView::Helpers::NumberHelper

  # A map of client library identifiers to those fields which are relevant
  # enough to warrant being displayed in the {#index} table. All clients include
  # the `number`, `occurred_at`, and `message` fields.
  INDEX_FIELDS           = {
      'ruby'    => [:host],
      'rails'   => [:host, :controller, :action],
      'ios'     => [:device_type, :operating_system, :version],
      'cocoa'   => [:device_type, :operating_system, :os_version, :version],
      'java'    => [:host],
      'jetty'   => [:host, :path],
      'android' => [:device_type, :operating_system, :version]
  }
  INDEX_FIELDS.default   = []
  # Maximum number of records to load for aggregation.
  MAX_AGGREGATED_RECORDS = 5000

  before_filter :find_project
  before_filter :find_environment
  before_filter :find_bug
  before_filter :find_occurrence, only: :show

  respond_to :html, only: [:show, :count]
  respond_to :json, :atom, only: :index

  # Generally, displays a list of Occurrences.
  #
  # JSON
  # ====
  #
  # Returns a infinitely scrollable list of Occurrences.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/environments/:environment_id/bugs/:bug_id/occurrences.json`
  #
  # Query Parameters
  # ----------------
  #
  # |        |                                                                                                                  |
  # |:-------|:-----------------------------------------------------------------------------------------------------------------|
  # | `last` | The number of the last Occurrence of the previous page; used to determine the start of the next page (optional). |
  #
  # Atom
  # ====
  #
  # Returns a feed of the most recent Occurrences of a Bug.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/environments/:environment_id/bugs/:bug_id/occurrences.atom`

  def index
    respond_to do |format|
      format.json do
        dir = params[:dir]
        dir = 'DESC' unless SORT_DIRECTIONS.include?(dir.try!(:upcase))

        @occurrences = @bug.occurrences.order("occurred_at #{dir}").limit(50)

        last = params[:last].present? ? @bug.occurrences.find_by_number(params[:last]) : nil
        @occurrences = @occurrences.where(infinite_scroll_clause('occurred_at', dir, last, 'occurrences.number')) if last

        render json: decorate(@occurrences)
      end
      format.atom { @occurrences = @bug.occurrences.order('occurred_at DESC').limit(100) } # index.atom.builder
    end
  end

  # Returns aggregate information about Occurrences across up to four
  # dimensions. Values are aggregated by time and partitioned by dimension value
  # combinations.
  #
  # A time range must be specified. Regardless of the time range, only up to a
  # maximum of {MAX_AGGREGATED_RECORDS} is loaded.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/environments/:environment_id/bugs/:bug_id/occurrences/aggregate.json`
  #
  # Query Parameters
  # ----------------
  #
  # |              |                                                                                                            |
  # |:-------------|:-----------------------------------------------------------------------------------------------------------|
  # | `dimensions` | A parameterized array of up to four dimensions. All must be {Occurrence::AGGREGATING_FIELDS valid fields}. |
  # | `size`       | The number of buckets (and thus, the time range).                                                          |
  # | `step`       | The time interval to bucket results by (milliseconds).                                                     |

  def aggregate
    dimensions = Array.wrap(params[:dimensions]).reject(&:blank?)
    dimensions.uniq!
    return head(:unprocessable_entity) if dimensions.size > 4 || dimensions.any? { |d| !Occurrence::AGGREGATING_FIELDS.include?(d) }

    if dimensions.empty?
      return respond_to do |format|
        format.json { render json: [].to_json }
      end
    end
    dimensions.map!(&:to_sym)

    occurrences      = @bug.occurrences.
        where("occurred_at >= ?", 30.days.ago).
        order('occurred_at ASC').
        limit(MAX_AGGREGATED_RECORDS)

    # create a hash mapping dimension names to a hash mapping dimension values
    # to a hash mapping timestmaps to the bucket count of that value in that
    # time period:
    #
    # {
    #   'operating_system' => {
    #     'Mac OS X' => {
    #       <9/1 12 AM> => 12
    #     }
    #   }
    # }
    #
    # In addition, build a hash of total occurrences for each time bucket:
    #
    # {
    #   'operating_system' => {
    #     <9/1 12 AM> => 12
    #   }
    # }

    dimension_values = dimensions.inject({}) { |hsh, dim| hsh[dim] = {}; hsh }
    totals           = Hash.new(0)
    top_values       = dimensions.inject({}) { |hsh, dim| hsh[dim] = Hash.new(0); hsh }

    occurrences.each do |occurrence|
      time = occurrence.occurred_at.change(min: 0, sec: 0, usec: 0).to_i * 1000
      dimensions.each do |dimension|
        dimension_values[dimension][occurrence.send(dimension)]       ||= Hash.new(0)
        dimension_values[dimension][occurrence.send(dimension)][time] += 1
        top_values[dimension][occurrence.send(dimension)]             += 1
      end
      totals[time] += 1
    end

    top_values.each do |dimension, value_totals|
      top_values[dimension] = value_totals.sort_by(&:last).reverse.map(&:first)[0, 5]
    end

    # convert it to a hash mapping dimension names to an array of hashes each
    # with two keys: label (the value) and data (an array of points, x being the
    # timestamp (ms) and y being the percentage of occurrences in that time
    # bucket with that value):
    #
    # {
    #   'operating_system' => [
    #     {label: 'Mac OS X', data: [[9/1 12 AM, 100%]]}
    #   ]
    # }

    dimension_values.each do |dim, values|
      dimension_values[dim] = Array.new
      values.each do |value, times|
        next unless top_values[dim].include?(value)
        series       = {label: value, data: []}
        dimension_values[dim] << series
        totals.each do |time, total|
          series[:data] << [time, total.zero? ? 0 : (times[time]/total.to_f)*100]
        end
      end
    end

    respond_to do |format|
      format.json { render json: dimension_values.to_json }
    end
  end

  def histogram
    occurrences = @bug.occurrences.
        where('occurred_at >= ?', 30.days.ago).
        group("date_trunc('hour', occurred_at)").
        count.map do |date, count|
      [date.to_i * 1000, count]
    end
    occurrences.sort_by!(&:first)
    if occurrences.empty?
      deploys = Array.new
    else
      deploys = @environment.deploys.where('deployed_at >= ?', Time.at(occurrences.first.first/1000)).order('deployed_at DESC').limit(30)
    end

    respond_to do |format|
      format.json { render json: {occurrences: occurrences, deploys: decorate_deploys(deploys)}.to_json }
    end
  end

  # Displays a page with detailed information about an Occurrence.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/environments/:environment_id/bugs/:bug_id/occurrences/:id.json`
  #
  # Query Parameters
  # ----------------
  #
  # |      |                                 |
  # |:-----|:--------------------------------|
  # | `id` | The Occurrence number (not ID). |

  def show
    respond_with @project, @environment, @bug
  end

  private

  def find_occurrence
    @occurrence = @bug.occurrences.find_by_number!(params[:id])
  end

  def decorate(occurrences)
    occurrences.map do |occurrence|
      occurrence.as_json(only: [:number, :occurred_at, :message], methods: INDEX_FIELDS[@bug.client]).merge(
          href: project_environment_bug_occurrence_url(@project, @environment, @bug, occurrence)
      )
    end
  end

  def decorate_deploys(deploys)
    deploys.map do |deploy|
      {
          deployed_at: deploy.deployed_at.to_i * 1000,
          revision:    deploy.revision,
          url:         @project.commit_url(deploy.revision),
          id:          deploy.id
      }
    end
  end
end
