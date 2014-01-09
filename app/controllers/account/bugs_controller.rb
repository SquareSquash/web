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

# Controller that works with the {Bug Bugs} {Watch watched} by the current
# {User}.

class Account::BugsController < ApplicationController
  # Number of Bugs to return per page.
  PER_PAGE = 50

  respond_to :json

  # Powers a table of a User's watched or assigned Bugs; returns a paginating
  # list of 50 Bugs, chosen according to the query parameters.
  #
  # Routes
  # ------
  #
  # * `GET /account/bugs.json`
  #
  # Query Parameters
  # ----------------
  #
  # |        |                                                                                                                                                                 |
  # |:-------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------|
  # | `type` | If `watched`, returns Bugs the User is watching. Otherwise, returns Bugs the User is assigned to.                                                               |
  # | `last` | The ID (`type` is `watched`) or number (`type` is not `watched`) of the last Bug of the previous page; used to determine the start of the next page (optional). |

  def index
    if params[:type].try!(:downcase) == 'watched'
      watches = current_user.watches.order('created_at DESC').includes(bug: [{environment: :project}, :assigned_user]).limit(PER_PAGE)
      last = params[:last].present? ? current_user.watches.joins(:bug).where(bug_id: params[:last]).first : nil
      watches = watches.where(infinite_scroll_clause('created_at', 'DESC', last, 'watches.bug_id')) if last
      @bugs = watches.map(&:bug)
    else
      @bugs = current_user.assigned_bugs.order('latest_occurrence DESC, bugs.number DESC').limit(PER_PAGE).includes(:assigned_user, environment: :project)
      last = params[:last].present? ? current_user.assigned_bugs.find_by_number(params[:last]) : nil
      @bugs = @bugs.where(infinite_scroll_clause('latest_occurrence', 'DESC', last, 'bugs.number')) if last
    end

    respond_with decorate(@bugs)
  end

  private

  def decorate(bugs)
    bugs.map do |bug|
      bug.as_json(only: [:number, :class_name, :message_template, :file, :line, :occurrences_count, :comments_count, :latest_occurrence]).merge(
          id:            bug.id, #TODO don't send the ID up to the view
          href:          project_environment_bug_url(bug.environment.project, bug.environment, bug),
          project:       bug.environment.project.as_json,
          environment:   bug.environment.as_json,
          assigned_user: bug.assigned_user.as_json,
          watch_url:     watch_project_environment_bug_url(bug.environment.project, bug.environment, bug, format: 'json')
      )
    end
  end
end
