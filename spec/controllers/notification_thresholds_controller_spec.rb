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

describe NotificationThresholdsController do
  {create: :post, update: :patch}.each do |action, method|
    before :all do
      @env    = FactoryGirl.create(:environment)
      @params = {notification_threshold: {period: 3600, threshold: 500}}
    end
    before(:each) { @bug = FactoryGirl.create(:bug, environment: @env) }

    describe "##{action}" do
      it "should require a logged-in user" do
        send method, action, polymorphic_params(@bug, true, @params.merge(format: 'json'))
        response.status.should eql(401)
        @bug.notification_thresholds.count.should eql(0)
      end

      context '[authenticated]' do
        before(:each) { login_as @bug.environment.project.owner }

        it_should_behave_like "action that 404s at appropriate times", method, action, 'polymorphic_params(@bug, true, @params.merge(format: "json"))'

        it "should create a new notification" do
          @bug.notification_thresholds.delete_all
          send method, action, polymorphic_params(@bug, true, @params.merge(format: 'json'))

          @bug.notification_thresholds.count.should eql(1)
          @bug.notification_thresholds(true).first.period.should eql(3600)
          @bug.notification_thresholds.first.threshold.should eql(500)
          @bug.notification_thresholds.first.user_id.should eql(@bug.environment.project.owner_id)
        end

        it "should update an existing notification" do
          @bug.notification_thresholds.delete_all
          FactoryGirl.create :notification_threshold, user: @bug.environment.project.owner, bug: @bug, period: 36, threshold: 5
          send method, action, polymorphic_params(@bug, true, @params.merge(format: 'json'))

          @bug.notification_thresholds.count.should eql(1)
          @bug.notification_thresholds(true).first.period.should eql(3600)
          @bug.notification_thresholds.first.threshold.should eql(500)
          @bug.notification_thresholds.first.user_id.should eql(@bug.environment.project.owner_id)
        end

        it "should not allow user or bug ID to be changed" do
          @bug.notification_thresholds.delete_all
          send method, action, polymorphic_params(@bug, true, notification_threshold: {user_id: 1, bug_id: 1, period: 1, threshold: 2}, format: 'json')
          response.status.should eql(400)
          @bug.notification_thresholds.count.should eql(0)
        end
      end
    end
  end

  describe "#destroy" do
    before(:all) { @env = FactoryGirl.create(:environment) }
    before(:each) { @bug = FactoryGirl.create(:bug, environment: @env) }

    it "should require a logged-in user" do
      delete :destroy, polymorphic_params(@bug, true)
      response.should redirect_to(login_url(next: request.fullpath))
      @bug.reload.should_not be_fixed
    end

    context '[authenticated]' do
      before(:each) { login_as @bug.environment.project.owner }

      it "should delete a notification threshold" do
        FactoryGirl.create :notification_threshold, user: @bug.environment.project.owner, bug: @bug, period: 36, threshold: 5
        delete :destroy, polymorphic_params(@bug, true)
        response.should redirect_to(project_environment_bug_url(@bug.environment.project, @bug.environment, @bug, anchor: 'notifications'))
        @bug.notification_thresholds.count.should eql(0)
      end

      it "should do nothing if no notification threshold exists" do
        delete :destroy, polymorphic_params(@bug, true)
        response.should redirect_to(project_environment_bug_url(@bug.environment.project, @bug.environment, @bug, anchor: 'notifications'))
        @bug.notification_thresholds.count.should eql(0)
      end
    end
  end
end
