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

# Tells PagerDuty to resolve the incident associated with a Bug. This occurs
# when a Bug is marked as fixed.

class PagerDutyResolver < PagerDutyAcknowledger

  # Sends a PagerDuty API call resolving an incident.

  def perform
    @bug.environment.project.pagerduty.resolve @bug.pagerduty_incident_key,
                                               description
  end

  private

  def description
    I18n.t 'workers.pagerduty.resolve.description',
           class_name: @bug.class_name,
           file_name:  File.basename(@bug.file),
           locale:     @bug.environment.project.locale
  end
end
