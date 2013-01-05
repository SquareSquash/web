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

# This observer on the {Occurrence} model:
#
# * sends an email when a Bug is critical, and
# * updates `any_occurrence_crashed` field on the associated {Bug}s.

class OccurrenceObserver < ActiveRecord::Observer
  # @private
  def after_commit_on_create(occurrence)
    # send emails
    Multithread.spinoff("OccurrenceNotificationMailer:#{occurrence.id}", 80) { OccurrenceNotificationMailer.perform(occurrence.id) }
    # force-reload the occurrence to load triggered changes

    # notify pagerduty
    Multithread.spinoff("PagerDutyNotifier:#{occurrence.id}", 80) { PagerDutyNotifier.perform(occurrence.id) }
  end

  # @private
  def after_create(occurrence)
    occurrence.bug.update_attribute(:any_occurrence_crashed, true) if occurrence.crashed?

    if occurrence.device_id.present?
      DeviceBug.transaction do
        if occurrence.bug.device_bugs.where(device_id: occurrence.device_id).none?
          occurrence.bug.device_bugs.create device_id: occurrence.device_id
        end
      end
    end
  end
end
