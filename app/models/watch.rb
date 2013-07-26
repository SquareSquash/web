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

# An association created when a {User} watches a {Bug}. {Event Events} created
# for that Bug will appear in the User's feed.
#
# Associations
# ============
#
# |        |                              |
# |:-------|:-----------------------------|
# | `user` | The {User} watching the Bug. |
# | `bug`  | The {Bug} being watched.     |

class Watch < ActiveRecord::Base
  self.primary_keys = :user_id, :bug_id

  belongs_to :user, inverse_of: :watches
  belongs_to :bug, inverse_of: :watches

  validates :user,
      presence: true
  validates :bug,
      presence: true
  validate :user_cannot_watch_foreign_bug

  # @private
  def as_json(options=nil)
    options ||= {}
    options[:except] = Array.wrap(options[:except]) + [:user_id, :bug_id]
    options[:include] = Array.wrap(options[:include]) + [:user, :bug]
    super options
  end

  private

  def user_cannot_watch_foreign_bug
    errors.add(:bug_id, :no_permission) unless user.role(bug.environment.project)
  end
end
