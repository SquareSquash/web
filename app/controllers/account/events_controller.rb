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

# Controller for working with {Event Events} of a {Bug} that the current {User}
# is {Watch watching}.

class Account::EventsController < ApplicationController
  include EventDecoration

  # Number of Events to return per page.
  PER_PAGE = 50

  respond_to :json

  # Returns a infinitely scrollable list of Events.
  #
  # Routes
  # ------
  #
  # * `GET /account/events.json`
  #
  # Query Parameters
  # ----------------
  #
  # |        |                                                                                                             |
  # |:-------|:------------------------------------------------------------------------------------------------------------|
  # | `last` | The number of the last Event of the previous page; used to determine the start of the next page (optional). |


  def index
    event_ids = current_user.user_events.order('created_at DESC').limit(PER_PAGE)
    last      = params[:last].present? ? current_user.user_events.find_by_event_id(params[:last]) : nil
    event_ids = event_ids.where(infinite_scroll_clause('created_at', 'DESC', last, 'event_id')) if last
    @events = Event.where(id: event_ids.pluck(:event_id)).order('created_at DESC').includes({user: :emails}, bug: {environment: {project: :slugs}})
    Event.preload @events.to_a

    respond_with decorate(@events)
  end

  protected

  # probably not the best way to do this
  def decorate(events)
    super.zip(events).map do |(hsh, event)|
      hsh.merge(
          bug:         event.bug.as_json.merge(
                           url: project_environment_bug_url(event.bug.environment.project, event.bug.environment, event.bug)
                       ),
          environment: event.bug.environment.as_json,
          project:     event.bug.environment.project.as_json
      )
    end
  end
end
