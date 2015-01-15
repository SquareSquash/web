# Copyright 2014 Square Inc.
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

require 'rails_helper'

RSpec.describe JiraStatusWorker do
  describe "#perform" do
    it "should update bugs linked to newly-closed JIRA tickets" do
      FakeWeb.register_uri :get,
                           jira_url('/rest/api/2/issue/FOO-123'),
                           response: Rails.root.join('spec', 'fixtures', 'jira_issue_resolved.json')
      FakeWeb.register_uri :get,
                           jira_url('/rest/api/2/issue/FOO-124'),
                           response: Rails.root.join('spec', 'fixtures', 'jira_issue.json')

      Bug.destroy_all

      env           = FactoryGirl.create(:environment)
      linked_bugs   = [
          FactoryGirl.create(:bug, environment: env, jira_issue: 'FOO-123', jira_status_id: 5),
          FactoryGirl.create(:bug, environment: env, jira_issue: 'FOO-123', jira_status_id: 5)
      ]
      unlinked_bugs = [
          FactoryGirl.create(:bug, environment: env, jira_issue: 'FOO-123', jira_status_id: 1),
          FactoryGirl.create(:bug, environment: env, jira_issue: 'FOO-124', jira_status_id: 5),
          FactoryGirl.create(:bug, environment: env, jira_issue: 'FOO-123'),
          FactoryGirl.create(:bug, environment: env, jira_status_id: 5),
          FactoryGirl.create(:bug, environment: env)
      ]

      JiraStatusWorker.perform

      linked_bugs.each { |bug| expect(bug.reload).to be_fixed }
      unlinked_bugs.each { |bug| expect(bug.reload).not_to be_fixed }

      expect(linked_bugs.first.events.last.kind).to eql('close')
      expect(linked_bugs.first.events.last.data['issue']).to eql('FOO-123')
      expect(linked_bugs.first.events.last.user).to be_nil
    end
  end
end unless Squash::Configuration.jira.disabled?
