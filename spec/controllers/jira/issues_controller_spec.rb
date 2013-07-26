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

describe Jira::IssuesController do
  describe "#show" do
    it "should return information about a JIRA issue" do
      FakeWeb.register_uri :get,
                           jira_url("/rest/api/2/issue/FOO-123"),
                           response: Rails.root.join('spec', 'fixtures', 'jira_issue.json')

      get :show, id: 'FOO-123', format: 'json'
      response.status.should eql(200)
      body = JSON.parse(response.body)
      body['fields']['summary'].should eql("Double RTs on coffee bar Twitter monitor")
    end

    it "should 404 if the JIRA issue is not found" do
      FakeWeb.register_uri :get,
                           jira_url("/rest/api/2/issue/FOO-124"),
                           response: Rails.root.join('spec', 'fixtures', 'jira_issue_404.json')

      get :show, id: 'FOO-124', format: 'json'
      response.status.should eql(404)
    end
  end
end unless Squash::Configuration.jira.disabled?
