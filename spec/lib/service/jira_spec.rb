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

require 'spec_helper'

describe Service::JIRA do
  describe ".new_issue_link" do
    it "should return a proper issue link" do
      Service::JIRA.new_issue_link(foo: 'bar').
          should eql(Squash::Configuration.jira.api_host +
                         Squash::Configuration.jira.api_root +
                         Squash::Configuration.jira.create_issue_details +
                         '?foo=bar'
                 )
    end
  end

  describe ".issue" do
    it "should locate a JIRA issue by key" do
      FakeWeb.register_uri :get,
                           jira_url("/rest/api/2/issue/FOO-123"),
                           response: Rails.root.join('spec', 'fixtures', 'jira_issue.json')

      issue = Service::JIRA.issue('FOO-123')
      issue.key.should eql('FOO-123')
      issue.summary.should eql("Double RTs on coffee bar Twitter monitor")
    end

    it "should return nil for an unknown issue" do
      FakeWeb.register_uri :get,
                           jira_url("/rest/api/2/issue/FOO-124"),
                           response: Rails.root.join('spec', 'fixtures', 'jira_issue_404.json')

      Service::JIRA.issue('FOO-124').should be_nil
    end
  end

  describe ".statuses" do
    it "should return all known issue statuses" do
      FakeWeb.register_uri :get,
                           jira_url("/rest/api/2/status"),
                           response: Rails.root.join('spec', 'fixtures', 'jira_statuses.json')

      statuses = Service::JIRA.statuses
      statuses.map(&:name).
          should eql(["Open", "In Progress", "Reopened", "Resolved", "Closed",
                      "Needs Review", "Approved", "Hold Pending Info", "IceBox",
                      "Not Yet Started", "Started", "Finished", "Delivered",
                      "Accepted", "Rejected", "Allocated", "Build", "Verify",
                      "Pending Review", "Stabilized", "Post Mortem Complete"])
    end
  end

  describe ".projects" do
    it "should return all known projects" do
      FakeWeb.register_uri :get,
                           jira_url("/rest/api/2/project"),
                           response: Rails.root.join('spec', 'fixtures', 'jira_projects.json')

      projects = Service::JIRA.projects
      projects.map(&:name).
          should eql(["Alert", "Android", "Bugs", "Business Intelligence",
                      "Checker", "Coffee Bar", "Compliance"])
    end
  end
end unless Squash::Configuration.jira.disabled?
