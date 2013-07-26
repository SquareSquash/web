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

# Worker that finds open bugs linked to JIRA issues, checks if those issues have
# been resolved, and then marks the bug as fixed if so.
#
# You will need to invoke this worker (or the `jira:update` Rake task) in a cron
# task, or otherwise periodically, to fully support JIRA integration.

class JiraStatusWorker
  include BackgroundRunner::Job

  # Creates a new instance and updates bug statuses.

  def self.perform
    new.perform
  end

  # Iterates through all open bugs that are linked to JIRA issues. Checks the
  # JIRA issue status for each such bug, and marks the bug as fixed as
  # appropriate.

  def perform
    Bug.where(fixed: false).cursor.each do |bug|
      next unless bug.jira_issue && bug.jira_status_id

      issue = Service::JIRA.issue(bug.jira_issue)
      next unless issue
      next unless issue.status.id.to_i == bug.jira_status_id

      bug.modifier = issue
      bug.update_attribute :fixed, true
    end
  end
end
