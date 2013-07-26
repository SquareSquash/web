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

# Simple worker class that sends the following emails when appropriate:
#
# * everyone on a {Bug}'s `notify_on_occurrence` list,
# * frequency-based email notifications when frequency thresholds are tripped,
#   and
# * the project-wide critical email if the critical threshold was breached.
#
# See {NotificationThreshold} for more information on frequency-based
# notification.

class OccurrenceNotificationMailer
  include BackgroundRunner::Job

  # Creates a new instance and sends notification emails.
  #
  # @param [Fixnum] occurrence_id The ID of a new Occurrence.

  def self.perform(occurrence_id)
    new(Occurrence.find(occurrence_id)).perform
  end

  # Creates a new worker instance.
  #
  # @param [Occurrence] occurrence A new Occurrence.

  def initialize(occurrence)
    @occurrence = occurrence
  end

  # Emails all Users who enabled per-occurrence notifications, and all
  # frequency-based notifications as appropriate.

  def perform
    if @occurrence.bug.occurrences_count == @occurrence.bug.environment.project.critical_threshold &&
        !@occurrence.bug.fixed? && !@occurrence.bug.irrelevant?
      NotificationMailer.critical(@occurrence.bug).deliver
    end

    User.where(id: @occurrence.bug.notify_on_occurrence).each do |user|
      NotificationMailer.occurrence(@occurrence, user).deliver
    end

    @occurrence.bug.notification_thresholds.cursor.each do |thresh|
      begin
        if thresh.tripped?
          NotificationMailer.threshold(@occurrence.bug, thresh.user).deliver
          thresh.touch :last_tripped_at
        end
      rescue => err
        # for some reason the cursors gem eats exceptions
        Squash::Ruby.notify err, occurrence: @occurrence, notification_threshold: thresh
      end
    end
  end
end
