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

describe Event do
  describe "#as_json" do
    before :all do
      m           = FactoryGirl.create(:membership)
      @user       = m.user
      @bug        = FactoryGirl.create(:bug, environment: FactoryGirl.create(:environment, project: m.project))
      @occurrence = FactoryGirl.create(:rails_occurrence, bug: @bug)
    end

    it "should return the correct fields for an open event" do
      FactoryGirl.build(:event, bug: @bug, kind: 'open').as_json.should eql(kind: 'open', created_at: nil)
    end

    it "should return the correct fields for a comment event" do
      comment = FactoryGirl.create(:comment, bug: @bug, user: FactoryGirl.create(:membership, project: @bug.environment.project).user)

      FactoryGirl.build(:event, bug: @bug, kind: 'comment', data: {'comment_id' => comment.id}, user: @user).as_json.
          should eql(kind: 'comment', comment: comment.as_json, user: @user.as_json, created_at: nil)
    end

    it "should return the correct fields for an assign event" do
      assignee = FactoryGirl.create(:user)

      FactoryGirl.build(:event, bug: @bug, kind: 'assign', data: {'assignee_id' => assignee.id}, user: @user).as_json.
          should eql(kind: 'assign', assigner: @user.as_json, assignee: assignee.as_json, created_at: nil)
    end

    it "should return the correct fields for a close event" do
      FactoryGirl.build(:event, bug: @bug, kind: 'close', user: @user, data: {'status' => 'irrelevant', 'revision' => 'abc123', 'issue' => 'FOO-123'}).as_json.
          should eql(kind: 'close', user: @user.as_json, status: 'irrelevant', revision: 'abc123', created_at: nil, issue: 'FOO-123')
    end

    it "should return the correct fields for a reopen event" do
      FactoryGirl.build(:event, bug: @bug, kind: 'reopen', user: @user, data: {'occurrence_id' => @occurrence.id, 'from' => 'irrelevant'}).as_json.
          should eql(kind: 'reopen', user: @user.as_json, occurrence: @occurrence.as_json, from: 'irrelevant', created_at: nil)
    end

    it "should return the correct fields for a deploy event" do
      FactoryGirl.build(:event, bug: @bug, kind: 'deploy', data: {'build' => '10010', 'revision' => 'c6293262d8d706bd8b4344b4c6deae3cde6e6434'}).as_json.
          should eql(kind: 'deploy', revision: 'c6293262d8d706bd8b4344b4c6deae3cde6e6434', build: '10010', created_at: nil)
    end

    it "should return the correct fields for an email event" do
      FactoryGirl.build(:event, bug: @bug, kind: 'email', data: {'recipients' => %w(foo@bar.com)}).as_json.
          should eql(kind: 'email', recipients: %w(foo@bar.com), created_at: nil)
    end

    it "should return the correct fields for a dupe event" do
      original = FactoryGirl.create(:bug)
      dupe     = FactoryGirl.create(:bug, duplicate_of: original, environment: original.environment)
      FactoryGirl.build(:event, bug: dupe, kind: 'dupe', user: @user).as_json.
          should eql(kind: 'dupe', user: @user.as_json, original: original.as_json, created_at: nil)
    end
  end

  context "[observer]" do
    it "should copy itself into the user_events table for each user watching the event's bug" do
      event  = FactoryGirl.build(:event)
      watch1 = FactoryGirl.create(:watch, bug: event.bug)
      watch2 = FactoryGirl.create(:watch, bug: event.bug)

      event.save!
      ues = event.user_events.pluck(:user_id)
      ues.size.should eql(2)
      ues.should include(watch1.user_id)
      ues.should include(watch2.user_id)
    end
  end
end
