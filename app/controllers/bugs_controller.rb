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

# Controller that works with the {Bug Bugs} in a {Project}'s {Environment}.
#
# Common
# ======
#
# Path Parameters
# ---------------
#
# |                  |                       |
# |:-----------------|:----------------------|
# | `project_id`     | The Project's slug.   |
# | `environment_id` | The Environment name. |

class BugsController < ApplicationController
  include ActionView::Helpers::NumberHelper

  # Maps values for the `sort` query parameters to an array of the `bugs` column
  # to sort by and the default sort direction. "latest" is the default.
  SORTS             = {
      'first'       => %w(bugs.first_occurrence ASC),
      'latest'      => %w(bugs.latest_occurrence DESC),
      'occurrences' => %w(bugs.occurrences_count DESC)
  }
  SORTS.default     = SORTS['latest']

  # Valid columns to filter the bug list on.
  VALID_FILTER_KEYS = %w( fixed irrelevant assigned_user_id deploy_id search any_occurrence_crashed )

  # Number of Bugs to return per page.
  PER_PAGE          = 50

  before_filter :find_project
  before_filter :find_environment
  before_filter :find_bug, except: [:index, :count, :notify_deploy, :notify_occurrence]
  before_filter :membership_required, only: [:update, :destroy]

  respond_to :html, :atom, :json

  # Generally, displays a list of a Bugs.
  #
  # HTML
  # ====
  #
  # Renders a page with a sortable table displaying the Bugs in an Environment.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/environments/:environment_id/bugs`
  #
  # JSON
  # ====
  #
  # Powers said sortable table; returns a paginating list of 50 Bugs, sorted
  # according to the query parameters.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/environments/:environment_id/bugs.json`
  #
  # Query Parameters
  # ----------------
  #
  # |        |                                                                                                           |
  # |:-------|:----------------------------------------------------------------------------------------------------------|
  # | `sort` | How to sort the list of Bugs; see {SORTS}.                                                                |
  # | `dir`  | The direction of sort, "ASC" or "DESC" (ignored otherwise).                                               |
  # | `last` | The number of the last Bug of the previous page; used to determine the start of the next page (optional). |
  #
  # Atom
  # ====
  #
  # Returns a feed of the most recently received bugs.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/environments/:environment_id/bugs.atom`

  def index
    respond_to do |format|
      format.html do
        @filter_users  = User.where(id: @environment.bugs.select('assigned_user_id').uniq.limit(PER_PAGE).map(&:assigned_user_id)).order('username ASC')
        # index.html.rb
      end

      format.json do
        filter = (params[:filter] || {}).slice(*VALID_FILTER_KEYS)
        filter.each { |k, v| filter[k] = nil if v == '' }

        filter.delete('deploy_id') if filter['deploy_id'].nil? # no deploy set means ANY deploy, not NO deploy
        filter.delete('any_occurrence_crashed') if filter['any_occurrence_crashed'].nil?

        # sentinel values
        filter.delete('assigned_user_id') if filter['assigned_user_id'] == 'somebody'
        filter.delete('assigned_user_id') if filter['assigned_user_id'] == 'anybody'
        filter['assigned_user_id'] = nil if filter['assigned_user_id'] == 'nobody'
        query = filter.delete('search')

        sort_column, default_dir = SORTS[params[:sort]]

        dir = if params[:dir].kind_of?(String) then
                SORT_DIRECTIONS.include?(params[:dir].upcase) ? params[:dir].upcase : default_dir
              else
                default_dir
              end

        @bugs = @environment.bugs.where(filter).order("#{sort_column} #{dir}, bugs.number #{dir}").limit(PER_PAGE)
        @bugs = @bugs.where('assigned_user_id IS NOT NULL') if params[:filter] && params[:filter][:assigned_user_id] == 'somebody'
        @bugs = @bugs.query(query) if query.present?

        last = params[:last].present? ? @environment.bugs.find_by_number(params[:last]) : nil
        @bugs = @bugs.where(infinite_scroll_clause(sort_column, dir, last, 'bugs.number')) if last

        begin
          render json: decorate_bugs(@bugs)
        rescue => err
          if (err.kind_of?(ActiveRecord::StatementInvalid) ||
              (defined?(ActiveRecord::JDBCError) && err.kind_of?(ActiveRecord::JDBCError))) &&
              err.to_s =~ /syntax error in tsquery/
            head :unprocessable_entity
          else
            raise
          end
        end
      end

      format.atom { @bugs = @environment.bugs.order('first_occurrence DESC').limit(100) }
    end
  end

  # Displays a page with information about a Bug.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/environments/:environment_id/bugs/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                          |
  # |:-----|:-------------------------|
  # | `id` | The Bug number (not ID). |

  def show
    @aggregation_dimensions  = Occurrence::AGGREGATING_FIELDS.
        map { |field| [Occurrence.human_attribute_name(field), field.to_s] }.
        unshift(['', nil])

    # We use `duplicate_of_number` on the view and `duplicate_of_id` in the
    # backend, so we need to copy between those values.
    @bug.duplicate_of_number = @bug.duplicate_of.try(:number)

    @new_issue_url = Service::JIRA.new_issue_link(summary:     t('controllers.bugs.show.jira_link.summary',
                                                                 class_name: @bug.class_name,
                                                                 file_name:  File.basename(@bug.file),
                                                                 line:       @bug.special_file? ? t('controllers.bugs.show.jira_link.not_applicable') : @bug.line,
                                                                 locale:     @bug.environment.project.locale),
                                                  environment: @environment.name,
                                                  description: t('controllers.bugs.show.jira_link.description',
                                                                 class_name: @bug.class_name,
                                                                 file:       File.basename(@bug.file),
                                                                 line:       @bug.special_file? ? t('controllers.bugs.show.jira_link.not_applicable') : @bug.line,
                                                                 message:    @bug.message_template,
                                                                 revision:   @bug.revision,
                                                                 url:        project_environment_bug_url(@project, @environment, @bug),
                                                                 locale:     @bug.environment.project.locale),
                                                  issuetype:   1)

    respond_with @project, @environment, @bug.as_json.merge(watched: current_user.watches?(@bug))
  end

  # Updates the bug management and tracking information for a Bug.
  #
  # Routes
  # ------
  #
  # * `PUT /projects/:project_id/environments/:environment_id/bugs/:id.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                          |
  # |:-----|:-------------------------|
  # | `id` | The Bug number (not ID). |
  #
  # Body Parameters
  # ---------------
  #
  # The body can be JSON- or form URL-encoded.
  #
  # |           |                                                                                       |
  # |:----------|:--------------------------------------------------------------------------------------|
  # | `bug`     | A parameterized hash of Bug fields.                                                   |
  # | `comment` | A parameterized hash of fields for a Comment to be created along with the Bug update. |

  def update
    # We use `duplicate_of_number` on the view and `duplicate_of_id` in the
    # backend, so we need to copy between those values.
    add_error = false
    if (number = params[:bug][:duplicate_of_number]).present?
      original_bug = @environment.bugs.where(number: number).first
      if original_bug
        @bug.duplicate_of_id = original_bug.id
      else
        add_error = true
      end
    else
      @bug.duplicate_of_id = nil
    end

    # hacky fix for the JIRA status dropdown
    params[:bug][:jira_status_id] = params[:bug][:jira_status_id].presence

    if !add_error && @bug.update_attributes(params[:bug], as: current_user.role(@bug))
      if params[:comment].kind_of?(Hash) && params[:comment][:body].present?
        @comment      = @bug.comments.build(params[:comment], as: :creator)
        @comment.user = current_user
        @comment.save
      end
      if params[:notification_threshold]
        if params[:notification_threshold][:threshold].blank? && params[:notification_threshold][:period].blank?
          current_user.notification_thresholds.where(bug_id: @bug.id).delete_all
        else
          @notification_threshold = current_user.notification_thresholds.where(bug_id: @bug.id).create_or_update(params[:notification_threshold], as: :user)
        end
      end
    else
      @bug.errors.add :duplicate_of_id, :not_found if add_error
      @bug.errors[:duplicate_of_id].each { |error| @bug.errors.add :duplicate_of_number, error }
    end

    respond_with @project, @environment, @bug.reload # reload to grab the new cached counter values
  end

  # Deletes a Bug. (Ideally it's one that probably won't just recur in a few
  # days.)
  #
  # Routes
  # ------
  #
  # * `DELETE /projects/:project_id/environments/:environment_id/bugs/:id.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                          |
  # |:-----|:-------------------------|
  # | `id` | The Bug number (not ID). |

  def destroy
    @bug.destroy

    respond_to do |format|
      format.html { redirect_to project_environment_bugs_url(@project, @environment), flash: {success: t('controllers.bugs.destroy.deleted', number: number_with_delimiter(@bug.number))} }
    end
  end

  # Toggles a Bug as watched or unwatched (see {Watch}).
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/environments/:environment_id/bugs/:id/watch.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                          |
  # |:-----|:-------------------------|
  # | `id` | The Bug number (not ID). |

  def watch
    if (watch = current_user.watches?(@bug))
      watch.destroy
    else
      watch = current_user.watches.where(bug_id: @bug.id).find_or_create
    end

    respond_to do |format|
      format.json do
        head(watch.destroyed? ? :no_content : :created)
      end
    end
  end

  # Toggles on or off email notifications to the current user when the Bug's
  # resolution commit is deployed.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/environments/:environment_id/bugs/:id/notify_deploy.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                          |
  # |:-----|:-------------------------|
  # | `id` | The Bug number (not ID). |

  def notify_deploy
    Bug.transaction do
      find_bug

      list = @bug.notify_on_deploy

      if list.include?(current_user.id)
        list.delete current_user.id
      else
        list << current_user.id
      end

      @bug.notify_on_deploy = list
      @bug.save!
    end

    respond_to do |format|
      format.json { render json: decorate_bug(@bug), location: project_environment_bug_url(@project, @environment, @bug) }
    end
  end

  # Toggles on or off email notifications to the current user when new
  # Occurrences of this Bug are received.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/environments/:environment_id/bugs/:id/notify_occurrence.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                          |
  # |:-----|:-------------------------|
  # | `id` | The Bug number (not ID). |

  def notify_occurrence
    Bug.transaction do
      find_bug

      list = @bug.notify_on_occurrence

      if list.include?(current_user.id)
        list.delete current_user.id
      else
        list << current_user.id
      end

      @bug.notify_on_occurrence = list
      @bug.save!
    end

    respond_to do |format|
      format.json { render json: decorate_bug(@bug), location: project_environment_bug_url(@project, @environment, @bug) }
    end
  end

  private

  def find_bug
    @bug          = @environment.bugs.find_by_number!(params[:id])
    @bug.modifier = current_user
  end

  def decorate_bugs(bugs)
    bugs.map { |bug| decorate_bug bug }
  end

  def decorate_bug(bug)
    bug.as_json(only: [:number, :class_name, :message_template, :file, :line, :occurrences_count, :comments_count, :latest_occurrence]).merge(
        href:                 project_environment_bug_url(@project, @environment, bug),
        notify_on_deploy:     bug.notify_on_deploy.include?(current_user.id),
        notify_on_occurrence: bug.notify_on_occurrence.include?(current_user.id)
    )
  end
end
