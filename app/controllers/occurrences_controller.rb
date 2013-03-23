# Copyright 2012 Square Inc.
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
        dir = 'desc' unless SORT_DIRECTIONS.include?(dir.try(:upcase))

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
  # |              |                                                                                                                |
  # |:-------------|:---------------------------------------------------------------------------------------------------------------|
  # | `dimensions` | A parameterized array of up to four dimensions. All must be {OccurrenceData::AGGREGATING_FIELDS valid fields}. |
  # | `size`       | The number of buckets (and thus, the time range).                                                              |
  # | `step`       | The time interval to bucket results by (milliseconds).                                                         |

  def aggregate
    dimensions = Array.wrap(params[:dimensions]).reject(&:blank?)
    dimensions.uniq!
    return head(:unprocessable_entity) if dimensions.size > 4 || dimensions.any? { |d| !OccurrenceData::AGGREGATING_FIELDS.include?(d) }

    if dimensions.empty?
      return respond_to do |format|
        format.json { render json: [].to_json }
      end
    end
    dimensions.map!(&:to_sym)

    # build a hash mapping dimension names to an array of hashes each with two
    # keys: label (the value) and data (an array of points, x being the
    # timestamp (ms) and y being the percentage of occurrences in that time
    # bucket with that value):
    #
    # {
    #   'operating_system' => [
    #     {label: 'Mac OS X', data: [[9/1 12 AM, 100%]]},
    #     ...
    #   ],
    #   ...
    # }

    # In order to do this, we'll have to execute two map/reduces in Mongo: the
    # first will generate a result set that counts up dimension name/value pairs
    # (such as "operating_system"/"Mac OS X").
    #
    # The result will be a temporary collection whose documents have compound
    # keys consisting of a dimension name (such as "operating_system"), a
    # dimension value (such as "Mac OS X"), and the timestamp of a bucket, in
    # milliseconds, quantized to the hour. The document's value will be the
    # total number of occurrences applying to that key.

    collection_name = "aggregate_#{@bug.id}_#{Time.now.to_i}" #TODO not perfectly threadsafe

    result = OccurrenceData.where(bug_id: @bug.id, :occurred_at.gte => 30.days.ago).
        map_reduce(ERB.new(<<-ERB).result(binding), <<-JS).out(replace: collection_name)
            function() {
              <% dimensions.each do |dimension| %>
                emit({
                  dim: "<%= dimension %>",
                  value: this.<%= dimension %>,
                  ts: Math.floor(this.occurred_at.getTime()/3600000)*3600000
                }, {count: 1});
              <% end %>
            }
          ERB
            function(key, values) {
              var result = {count: 0};
              values.forEach(function(value) { result.count += value.count; });
              return result;
            }
          JS
    result.counts # execute the first map/reduce

    # Now, we will map/reduce those results to generate a new result set that
    # organizes a dimension name and timestamp with the set of possible values
    # for that dimension and the percentage of occurrences falling in that time
    # bucket having that value (basically, a vertical slice of the final graph).
    #
    # The result will be a collection whose documents have compound keys
    # consisting of a dimension name and a timestamp. The document value will be
    # an array of pairs, a pair consisting of a dimension value and the
    # percentage applicable to that value.

    result = Mongoid::Contextual::MapReduce.new(result.session[collection_name], OccurrenceData.criteria, <<-JS, <<-JS).out(inline: true).to_a
              function() {
                emit({dim: this._id.dim, ts: this._id.ts}, {colval: this._id.value, total: this.value.count, values: [[this._id.value, 100.0]]});
                // emit both the "values" key (which would be used if the reduce function is never
                // called because there is only one mapped value), and also the "total" and "colval"
                // keys (used by the reduce function)
              }
            JS
              function(key, values) {
                var total = 0;

                var dimensionValues = new Object();
                values.forEach(function(value) {
                  if (dimensionValues[value.colval] == undefined)
                    dimensionValues[value.colval] = 0;
                  dimensionValues[value.colval] += value.total;
                  total += value.total
                });

                var result = [];
                for (var dimensionValue in dimensionValues) {
                  if (!dimensionValues.hasOwnProperty(dimensionValue)) continue;
                  result.push([dimensionValue, dimensionValues[dimensionValue]/total*100]);
                }
                return {values: result};
              }
            JS

    # clean up temp collection
    Mongoid.default_session[collection_name].drop

    # OK, almost there. Now we have to convert the result from Mongo's format to
    # the JSON format we want it in.

    dimension_values = result.inject({}) do |hsh, dimension_ts|
      dimension_name      = dimension_ts['_id']['dim']
      hsh[dimension_name] ||= Array.new
      dimension_ts['value']['values'].each do |(label, percent)|
        value_element = hsh[dimension_name].detect { |v| v[:label] == label }
        value_element ||= begin
          ve = {label: label, data: []}
          hsh[dimension_name] << ve
          ve
        end

        time_bucket = dimension_ts['_id']['ts'].to_i
        value_element[:data] << [time_bucket, percent]
      end

      hsh
    end

    # Sort each array of pairs by time.
    dimension_values.each { |_, values| values.each { |value| value[:data].sort_by!(&:first) } }

    respond_to do |format|
      format.json { render json: dimension_values.to_json }
    end
  end

  def histogram
    result = OccurrenceData.where(bug_id: @bug.id, :occurred_at.gte => 30.days.ago).
        map_reduce(<<-JS, <<-JS).out(inline: true).to_a
          function() {
            emit(Math.floor(this.occurred_at.getTime()/3600000)*3600000, {count: 1});
          }
        JS
          function(key, values) {
            var result = {count: 0};
            values.forEach(function(value) { result.count += value.count; });
            return result;
          }
        JS

    result.map! { |value| [value['_id'].to_i, value['value']['count'].to_i] }
    result.sort_by!(&:first)

    if result.empty?
      deploys = Array.new
    else
      deploys = @environment.deploys.where('deployed_at >= ?', Time.at(result.first.first/1000)).order('deployed_at DESC').limit(30)
    end

    respond_to do |format|
      format.json { render json: {occurrences: result, deploys: decorate_deploys(deploys)}.to_json }
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
