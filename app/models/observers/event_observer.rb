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

# This observer
#
# * copies {Event Events} to the `user_events` table for each User watching a
#   {Bug}'s events, and
# * sends emails notifying of Bug status changes.

class EventObserver < ActiveRecord::Observer
  # @private
  def after_create(event)
    copy_events_for_users event
    send_emails event
  end

  private

  def copy_events_for_users(event)
    # make user events for all the users watching this bug
    UserEvent.connection.execute <<-SQL
      INSERT INTO user_events
        (user_id, event_id, created_at)
      SELECT user_id, #{event.id}, #{Event.connection.quote event.created_at}
        FROM watches
        WHERE bug_id = #{event.bug_id}
    SQL
  end

  def send_emails(event)
    if event.kind == 'assign' &&
        !event.bug.fixed? && !event.bug.irrelevant? &&
        event.user && event.assignee && event.user != event.assignee

      Squash::Ruby.fail_silently do
        NotificationMailer.assign(event.bug, event.user, event.assignee).deliver
      end
    end

    if event.kind == 'close' &&
        ((event.user_id && event.user_id != event.bug.assigned_user_id) || # a user other than the assigned user performed the action
        (!event.user_id && event.bug.assigned_user_id)) &&                 # or no user performed the action but there is an assigned user
        !(event.data['status'] == 'fixed' && event.bug.irrelevant?) &&     # an irrelevant bug was not marked as fixed
        !(event.data['status'] == 'irrelevant' && event.bug.fixed?)        # a fixed bug was not marked as irrelevant
      Squash::Ruby.fail_silently do
        NotificationMailer.resolved(event.bug, event.user).deliver
      end
    end
  end
end
