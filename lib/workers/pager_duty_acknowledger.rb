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

# Tells PagerDuty to acknowledge the incident associated with a Bug. This occurs
# when a Bug is marked as irrelevant or assigned to a User.

class PagerDutyAcknowledger
  include BackgroundRunner::Job

  # Creates a new instance and sends a PagerDuty acknowledgement.
  #
  # @param [Fixnum] bug_id The ID of a Bug.

  def self.perform(bug_id)
    new(Bug.find(bug_id)).perform
  end

  # Creates a new worker instance.
  #
  # @param [Bug] bug A Bug that was assigned.

  def initialize(bug)
    @bug = bug
  end

  # Sends a PagerDuty API call acknowledging an incident.

  def perform
    @bug.environment.project.pagerduty.acknowledge @bug.pagerduty_incident_key,
                                                   description,
                                                   details
  end

  private

  def description
    if @bug.fixed?
      I18n.t 'workers.pagerduty.acknowledge.description.fixed',
             class_name: @bug.class_name,
             file_name:  File.basename(@bug.file),
             locale:     @bug.environment.project.locale
    elsif @bug.irrelevant?
      I18n.t 'workers.pagerduty.acknowledge.description.irrelevant',
             class_name: @bug.class_name,
             file_name:  File.basename(@bug.file),
             locale:     @bug.environment.project.locale
    else
      I18n.t 'workers.pagerduty.acknowledge.description.assigned',
             class_name: @bug.class_name,
             file_name:  File.basename(@bug.file),
             user:       @bug.assigned_user.name,
             locale:     @bug.environment.project.locale
    end
  end

  def details
    {
        'assigned_user' => @bug.assigned_user.try!(:name)
    }
  end
end
