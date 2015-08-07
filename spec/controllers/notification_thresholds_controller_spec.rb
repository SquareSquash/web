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

RSpec.describe NotificationThresholdsController, type: :controller do
  {create: :post, update: :patch}.each do |action, method|
    before :all do
      @env    = FactoryGirl.create(:environment)
      @params = {notification_threshold: {period: 3600, threshold: 500}}
    end
    before(:each) { @bug = FactoryGirl.create(:bug, environment: @env) }

    describe "##{action}" do
      it "should require a logged-in user" do
        send method, action, polymorphic_params(@bug, true, @params.merge(format: 'json'))
        expect(response.status).to eql(401)
        expect(@bug.notification_thresholds.count).to eql(0)
      end

      context '[authenticated]' do
        before(:each) { login_as @bug.environment.project.owner }

        it_should_behave_like "action that 404s at appropriate times", method, action, 'polymorphic_params(@bug, true, @params.merge(format: "json"))'

        it "should create a new notification" do
          @bug.notification_thresholds.delete_all
          send method, action, polymorphic_params(@bug, true, @params.merge(format: 'json'))

          expect(@bug.notification_thresholds.count).to eql(1)
          expect(@bug.notification_thresholds(true).first.period).to eql(3600)
          expect(@bug.notification_thresholds.first.threshold).to eql(500)
          expect(@bug.notification_thresholds.first.user_id).to eql(@bug.environment.project.owner_id)
        end

        it "should update an existing notification" do
          @bug.notification_thresholds.delete_all
          FactoryGirl.create :notification_threshold, user: @bug.environment.project.owner, bug: @bug, period: 36, threshold: 5
          send method, action, polymorphic_params(@bug, true, @params.merge(format: 'json'))

          expect(@bug.notification_thresholds.count).to eql(1)
          expect(@bug.notification_thresholds(true).first.period).to eql(3600)
          expect(@bug.notification_thresholds.first.threshold).to eql(500)
          expect(@bug.notification_thresholds.first.user_id).to eql(@bug.environment.project.owner_id)
        end

        it "should not allow user or bug ID to be changed" do
          @bug.notification_thresholds.delete_all
          send method, action, polymorphic_params(@bug, true, notification_threshold: {user_id: 1, bug_id: 1, period: 1, threshold: 2}, format: 'json')
          expect(@bug.notification_thresholds.count).to eql(1)
          expect(@bug.notification_thresholds(true).first.user_id).to eql(@bug.environment.project.owner_id)
        end
      end
    end
  end

  describe "#destroy" do
    before(:all) { @env = FactoryGirl.create(:environment) }
    before(:each) { @bug = FactoryGirl.create(:bug, environment: @env) }

    include_context "setup for required logged-in user"
    it "should require a logged-in user" do
      delete :destroy, polymorphic_params(@bug, true)
      expect(response).to redirect_to(login_required_redirection_url(next: request.fullpath))
      expect(@bug.reload).not_to be_fixed
    end

    context '[authenticated]' do
      before(:each) { login_as @bug.environment.project.owner }

      it "should delete a notification threshold" do
        FactoryGirl.create :notification_threshold, user: @bug.environment.project.owner, bug: @bug, period: 36, threshold: 5
        delete :destroy, polymorphic_params(@bug, true)
        expect(response).to redirect_to(project_environment_bug_url(@bug.environment.project, @bug.environment, @bug, anchor: 'notifications'))
        expect(@bug.notification_thresholds.count).to eql(0)
      end

      it "should do nothing if no notification threshold exists" do
        delete :destroy, polymorphic_params(@bug, true)
        expect(response).to redirect_to(project_environment_bug_url(@bug.environment.project, @bug.environment, @bug, anchor: 'notifications'))
        expect(@bug.notification_thresholds.count).to eql(0)
      end
    end
  end
end
