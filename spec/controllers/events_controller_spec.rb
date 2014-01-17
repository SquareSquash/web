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

require 'spec_helper'

describe EventsController do
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
      @events    = 100.times.map { |i| FactoryGirl.create :event, bug: @bug, user: (i.even? ? @bug.environment.project.owner : membership.user), kind: kinds.sample, data: data }
      @user      = membership.user
    end

    it "should require a logged-in user" do
      get :index, polymorphic_params(@bug, true)
      expect(response).to redirect_to(login_url(next: request.fullpath))
    end

    context '[authenticated]' do
      before(:each) { login_as @user }

      it_should_behave_like "action that 404s at appropriate times", :get, :index, 'polymorphic_params(@bug, true)'

      it "should load the 50 most recent events" do
        get :index, polymorphic_params(@bug, true, format: 'json')
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body).map { |e| e['kind'] }).to eql(@events.sort_by(&:created_at).reverse.map(&:kind)[0, 50])
      end

      it "should return the next 50 events when given a last parameter" do
        @events.sort_by! &:created_at
        @events.reverse!

        get :index, polymorphic_params(@bug, true, last: @events[49].id, format: 'json')
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body).map { |e| e['kind'] }).to eql(@events.map(&:kind)[50, 50])
      end

      it "should decorate the response" do
        get :index, polymorphic_params(@bug, true, format: 'json')
        JSON.parse(response.body).zip(@events.sort_by(&:created_at).reverse).each do |(hsh, event)|
          expect(hsh['icon']).to include(icon_for_event(event))
          expect(hsh['user_url']).to eql(user_url(event.user))
          expect(hsh['assignee_url']).to eql(user_url(event.assignee))
          expect(hsh['occurrence_url']).to eql(project_environment_bug_occurrence_url(@env.project, @env, @bug, event.occurrence))
          expect(hsh['comment_body']).to eql(ApplicationController.new.send(:markdown).(event.comment.body))
          expect(hsh['resolution_url']).to eql(@bug.resolution_revision)
          expect(hsh['assignee_you']).to eql(event.assignee == @user)
          expect(hsh['user_you']).to eql(@user == event.user)
        end
      end

      it "should add the original bug and URL to the JSON for dupe events" do
        original = FactoryGirl.create :bug
        dupe     = FactoryGirl.create :bug, environment: original.environment
        dupe.mark_as_duplicate! original

        get :index, polymorphic_params(dupe, true, format: 'json')

        json = JSON.parse(response.body)
        expect(json.first['kind']).to eql('dupe')
        expect(json.first['original_url']).to eql(project_environment_bug_url(original.environment.project, original.environment, original))
        expect(json.first['original']['number']).to eql(original.number)
      end
    end
  end
end
