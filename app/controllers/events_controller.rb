# Copyright 2013 Square Inc.
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

# Controller for working with a {Bug}'s {Event Events}.
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

class EventsController < ApplicationController
  include EventDecoration

  before_filter :find_project
  before_filter :find_environment
  before_filter :find_bug

  respond_to :json

  # Returns a infinitely scrollable list of Events.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/environments/:environment_id/bugs/:bug_id/events.json`
  #
  # Query Parameters
  # ----------------
  #
  # |        |                                                                                                             |
  # |:-------|:------------------------------------------------------------------------------------------------------------|
  # | `last` | The number of the last Event of the previous page; used to determine the start of the next page (optional). |

  def index
    @events = @bug.events.order('created_at DESC').limit(50).includes({user: :emails}, bug: {environment: {project: :slugs}})

    last = params[:last].present? ? @bug.events.find_by_id(params[:last]) : nil
    @events = @events.where(infinite_scroll_clause('created_at', 'DESC', last, 'events.id')) if last
    Event.preload @events

    respond_with @project, @environment, @bug, (request.format == :json ? decorate(@events) : @events)
  end
end
