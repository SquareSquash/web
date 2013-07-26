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

# Adds a method to decorate {Event Events} with additional attributes before
# rendering them as XML or JSON.

module EventDecoration
  protected

  # Decorates an array of events. This method will use the `@project`,
  # `@environment`, and `@bug` fields if set; otherwise it will use the
  # associated objects on the event.
  #
  # @param [Array<Event>, ActiveRecord::Relation] events The events to decorate.
  # @return [Array<Hash<Symbol, Object>>] The decorated attributes.

  def decorate(events)
    events.map do |event|
      project     = @project || event.bug.environment.project
      environment = @environment || event.bug.environment
      bug         = @bug || event.bug

      json = event.as_json.merge(
          icon:           icon_for_event(event),
          user_url:       event.user ? user_url(event.user) : nil,
          assignee_url:   event.assignee ? user_url(event.assignee) : nil,
          occurrence_url: event.occurrence ? project_environment_bug_occurrence_url(project, environment, bug, event.occurrence) : nil,
          comment_body:   event.comment ? markdown.(event.comment.body) : nil,
          revision_url:   event.data['revision'] ? project.commit_url(event.data['revision']) : nil,
          user_you:       event.user_id == current_user.id,
          assignee_you:   event.data['assignee_id'] == current_user.id
      )

      json[:original_url] = project_environment_bug_url(project, environment, bug.duplicate_of) if event.kind == 'dupe' && bug.duplicate_of

      json
    end
  end

  private

  def icon_for_event(event)
    case event.kind
      when 'assign' then 'user'
      when 'comment' then 'comment'
      when 'deploy' then 'truck'
      when 'dupe' then 'copy'
      when 'email' then 'envelope'
      when 'open' then 'exclamation-sign'
      when 'reopen' then 'warning-sign'
      when 'close'
        case event.data['status']
          when 'fixed' then 'ok-sign'
          when 'irrelevant' then 'remove-sign'
        end
      else 'question-sign'
    end
  end
end
