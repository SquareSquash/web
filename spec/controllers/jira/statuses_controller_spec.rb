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

describe Jira::StatusesController do
  describe "#index" do
    it "should a list of known statuses" do
      FakeWeb.register_uri :get,
                           jira_url("/rest/api/2/status"),
                           response: Rails.root.join('spec', 'fixtures', 'jira_statuses.json')

      get :index, format: 'json'
      response.status.should eql(200)
      body = JSON.parse(response.body)
      body.map { |st| st['name'] }.
          should eql(["Open", "In Progress", "Reopened", "Resolved", "Closed",
                      "Needs Review", "Approved", "Hold Pending Info", "IceBox",
                      "Not Yet Started", "Started", "Finished", "Delivered",
                      "Accepted", "Rejected", "Allocated", "Build", "Verify",
                      "Pending Review", "Stabilized", "Post Mortem Complete"].sort)
    end
  end
end unless Squash::Configuration.jira.disabled?
