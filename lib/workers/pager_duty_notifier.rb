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

# Notifies PagerDuty of a new Occurrence. This is converted into a PagerDuty
# incident. The incident key is shared with other Occurrences of the same Bug.

class PagerDutyNotifier
  include BackgroundRunner::Job

  # Creates a new instance and sends a PagerDuty notification.
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

  # Sends a PagerDuty API call creating a new incident (if appropriate).

  def perform
    if should_notify_pagerduty?
      @occurrence.bug.environment.project.pagerduty.trigger description,
                                                            @occurrence.bug.pagerduty_incident_key,
                                                            details
    end
  end

  private

  def should_notify_pagerduty?
    !@occurrence.bug.irrelevant? &&
        !@occurrence.bug.assigned_user_id &&
        @occurrence.bug.environment.notifies_pagerduty? &&
        @occurrence.bug.environment.project.pagerduty_enabled? &&
        @occurrence.bug.environment.project.pagerduty_service_key &&
        (@occurrence.bug.occurrences_count > @occurrence.bug.environment.project.critical_threshold ||
            @occurrence.bug.environment.project.always_notify_pagerduty?)

  end

  def description
    I18n.t 'workers.pagerduty.incident.description',
           class_name: @occurrence.bug.class_name,
           file_name:  File.basename(@occurrence.bug.file),
           line:       @occurrence.bug.special_file? ? I18n.t('workers.pagerduty.not_applicable') : @occurrence.bug.line,
           message:    @occurrence.message,
           locale:     @occurrence.bug.environment.project.locale
  end

  def details
    {
        'environment' => @occurrence.bug.environment.name,
        'revision'    => @occurrence.revision,
        'hostname'    => @occurrence.hostname,
        'build'       => @occurrence.build
    }
  end
end
