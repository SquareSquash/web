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

# This observer pre-fills (or empties) a User's feed (stored in the
# `user_events` table) when a User watches or unwatches a Bug.

class WatchObserver < ActiveRecord::Observer
  # @private
  def after_create(watch)
    fill_feed watch
  end

  # @private
  def after_destroy(watch)
    empty_feed watch
  end

  private

  def fill_feed(watch)
    # add the bug's last 10 events to the user's feed
    UserEvent.connection.execute <<-SQL
      INSERT INTO user_events
        (user_id, event_id, created_at)
      SELECT #{watch.user_id}, id, created_at
        FROM events
        WHERE bug_id = #{watch.bug_id}
        ORDER BY created_at DESC
        LIMIT 10
    SQL
  end

  def empty_feed(watch)
    # remove all events from the user's feed pertaining to that bug
    UserEvent.connection.execute <<-SQL
      DELETE FROM user_events
        USING events
        WHERE user_events.event_id = events.id
          AND events.bug_id = #{watch.bug_id}
          AND user_events.user_id = #{watch.user_id}
    SQL
  end
end
