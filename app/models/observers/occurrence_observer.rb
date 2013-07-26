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

# This observer on the {Occurrence} model:
#
# * sends an email when a Bug is critical, and
# * creates {DeviceBug DeviceBugs} as necessary.

class OccurrenceObserver < ActiveRecord::Observer
  # @private
  def after_commit_on_create(occurrence)
    # send emails
    BackgroundRunner.run OccurrenceNotificationMailer, occurrence.id

    # notify pagerduty
    BackgroundRunner.run PagerDutyNotifier, occurrence.id
  end

  # @private
  def after_create(occurrence)
    if occurrence.device_id.present?
      occurrence.bug.device_bugs.where(device_id: occurrence.device_id).find_or_create!
    end
  end
end
