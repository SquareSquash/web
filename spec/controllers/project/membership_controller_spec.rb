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

RSpec.describe Project::MembershipController, type: :controller do
  describe "#join" do
    before :each do
      @project = FactoryGirl.create(:project)
      @user    = FactoryGirl.create(:user)
    end

    include_context "setup for required logged-in user"
    it "should require a logged-in user" do
      post :join, project_id: @project.to_param
      expect(response).to redirect_to(login_required_redirection_url(next: request.fullpath))
      expect(@project.memberships.count).to eql(1)
    end

    context "[authenticated]" do
      before(:each) { login_as @user }

      it "should redirect given an existing membership" do
        FactoryGirl.create :membership, project: @project, user: @user
        post :join, project_id: @project.to_param

        expect(response).to redirect_to(project_url(@project))
        expect(@project.memberships.count).to eql(2)
      end

      it "should create a new membership" do
        post :join, project_id: @project.to_param

        expect(response).to redirect_to(project_url(@project))
        expect(@project.memberships.count).to eql(2)
        expect(@user.role(@project)).to eql(:member)
      end
    end
  end

  describe "#update" do
    before(:each) { @membership = FactoryGirl.create(:membership) }

    include_context "setup for required logged-in user"
    it "should require a logged-in user" do
      patch :update, project_id: @membership.project.to_param, membership: {send_comment_emails: '1'}
      expect(response).to redirect_to(login_required_redirection_url(next: request.fullpath))
      expect(@membership.reload.send_comment_emails).to eql(false)
    end

    context "[authenticated]" do
      before(:each) { login_as @membership.user }

      it "should modify the membership" do
        patch :update, project_id: @membership.project.to_param, membership: {send_comment_emails: '1'}
        expect(response.status).to redirect_to(edit_project_my_membership_url(@membership.project))
        expect(@membership.reload.send_comment_emails).to eql(true)
      end

      it "should not allow protected attributes to be updated" do
        patch :update, project_id: @membership.project.to_param, membership: {project_id: 123}
        expect { @membership.reload }.not_to change(@membership, :project_id)
      end
    end
  end

  describe "#destroy" do
    before(:each) { @membership = FactoryGirl.create(:membership) }

    include_context "setup for required logged-in user"
    it "should require a logged-in user" do
      delete :destroy, project_id: @membership.project.to_param
      expect(response).to redirect_to(login_required_redirection_url(next: request.fullpath))
    end

    it "should not allow the owner to delete his/her project" do
      login_as @membership.project.owner
      delete :destroy, project_id: @membership.project.to_param
      expect(response).to redirect_to(account_url)
    end

    context "[authenticated]" do
      before(:each) { login_as @membership.user }

      it "should delete the membership" do
        delete :destroy, project_id: @membership.project.to_param
        expect(response).to redirect_to(account_url)
        expect { @membership.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
