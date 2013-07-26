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

describe Account::EventsController do
  include EventDecoration

  describe "#index" do
    before :all do
      membership = FactoryGirl.create(:membership)
      @env       = FactoryGirl.create(:environment, project: membership.project)
      @bug       = FactoryGirl.create(:bug, environment: @env)
      kinds      = ['open', 'comment', 'assign', 'close', 'reopen']
      data       = {'status'        => 'fixed',
                    'from'          => 'closed',
                    'revision'      => '8f29160c367cc3e73c112e34de0ee48c4c323ff7',
                    'build'         => '10010',
                    'assignee_id'   => FactoryGirl.create(:membership, project: @env.project).user_id,
                    'occurrence_id' => FactoryGirl.create(:rails_occurrence, bug: @bug).id,
                    'comment_id'    => FactoryGirl.create(:comment, bug: @bug, user: membership.user).id}
      @events    = 10.times.map { |i| FactoryGirl.create :event, bug: @bug, user: (i.even? ? @bug.environment.project.owner : membership.user), kind: kinds.sample, data: data }
      @user      = membership.user

      @user.user_events.delete_all # creating the comment created a watch which copied events over
      @events.each { |event| FactoryGirl.create :user_event, event: event, user: @user, created_at: event.created_at }
    end

    before(:each) { stub_const 'Account::EventsController::PER_PAGE', 5 } # speed it up

    it "should require a logged-in user" do
      get :index, format: 'json'
      response.status.should eql(401)
    end

    context '[authenticated]' do
      before(:each) { login_as @user }

      it "should load the 50 most recent events" do
        get :index, format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).map { |e| e['kind'] }.should eql(@events.sort_by(&:created_at).reverse.map(&:kind)[0, 5])
      end

      it "should return the next 50 events when given a last parameter" do
        @events.sort_by! &:created_at
        @events.reverse!

        get :index, last: @events[4].id, format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).map { |e| e['kind'] }.should eql(@events.map(&:kind)[5, 5])
      end

      it "should decorate the response" do
        get :index, format: 'json'
        JSON.parse(response.body).zip(@events.sort_by(&:created_at).reverse).each do |(hsh, event)|
          hsh['icon'].should include(icon_for_event(event))
          hsh['user_url'].should eql(user_url(event.user))
          hsh['assignee_url'].should eql(user_url(event.assignee))
          hsh['occurrence_url'].should eql(project_environment_bug_occurrence_url(@env.project, @env, @bug, event.occurrence))
          hsh['comment_body'].should eql(ApplicationController.new.send(:markdown).(event.comment.body))
          hsh['resolution_url'].should eql(@bug.resolution_revision)
          hsh['assignee_you'].should eql(event.assignee == @user)
          hsh['user_you'].should eql(@user == event.user)
        end
      end

      it "should add the original bug and URL to the JSON for dupe events" do
        original = FactoryGirl.create :bug
        dupe     = FactoryGirl.create :bug, environment: original.environment
        FactoryGirl.create :watch, user: @user, bug: dupe
        dupe.mark_as_duplicate! original

        get :index, format: 'json'

        json = JSON.parse(response.body)
        json.first['kind'].should eql('dupe')
        json.first['original_url'].should eql(project_environment_bug_url(original.environment.project, original.environment, original))
        json.first['original']['number'].should eql(original.number)
      end
    end
  end
end
