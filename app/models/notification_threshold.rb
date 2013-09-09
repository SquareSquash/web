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

# An indication that a User wishes to be notified should a Bug occur over a
# certain threshold within a certain period of time. If the threshold is
# exceeded, an email is sent. The threshold then resets for the length of the
# period.
#
# The actual monitoring of the threshold and delivery of emails is handled by
# {OccurrenceObserver}.
#
# Associations
# ============
#
# |        |                                              |
# |:-------|:---------------------------------------------|
# | `user` | The {User} that set this notification.       |
# | `bug`  | The {Bug} to which the notification applies. |
#
# Properties
# ==========
#
# |                   |                                                                   |
# |:------------------|:------------------------------------------------------------------|
# | `threshold`       | The number of times the Bug must occur within the period.         |
# | `period`          | The amount of time, in seconds, the threshold is calculated over. |
# | `last_tripped_at` | The last time this threshold was exceeded.                        |

class NotificationThreshold < ActiveRecord::Base
  belongs_to :user, inverse_of: :notification_thresholds
  belongs_to :bug, inverse_of: :notification_thresholds

  self.primary_keys = [:user_id, :bug_id]

  validates :user,
            presence: true
  validates :bug,
            presence: true
  validates :period,
            presence:     true,
            numericality: {greater_than: 0, only_integer: true}
  validates :threshold,
            presence:     true,
            numericality: {greater_than: 0, only_integer: true}

  # @return [true, false] Whether or not this Bug has occurred `threshold` times
  #   in the past `period` seconds.

  def tripped?
    (last_tripped_at.nil? || last_tripped_at < period.seconds.ago) &&
        bug.occurrences.where("occurred_at >= ?", threshold.seconds.ago).count >= threshold
  end
end
