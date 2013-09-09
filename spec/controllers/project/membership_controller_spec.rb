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

describe Project::MembershipController do
  describe "#join" do
    before :each do
      @project = FactoryGirl.create(:project)
      @user    = FactoryGirl.create(:user)
    end

    it "should require a logged-in user" do
      post :join, project_id: @project.to_param
      response.should redirect_to(login_url(next: request.fullpath))
      @project.memberships.count.should eql(1)
    end

    context "[authenticated]" do
      before(:each) { login_as @user }

      it "should redirect given an existing membership" do
        FactoryGirl.create :membership, project: @project, user: @user
        post :join, project_id: @project.to_param

        response.should redirect_to(project_url(@project))
        @project.memberships.count.should eql(2)
      end

      it "should create a new membership" do
        post :join, project_id: @project.to_param

        response.should redirect_to(project_url(@project))
        @project.memberships.count.should eql(2)
        @user.role(@project).should eql(:member)
      end
    end
  end

  describe "#update" do
    before(:each) { @membership = FactoryGirl.create(:membership) }

    it "should require a logged-in user" do
      patch :update, project_id: @membership.project.to_param, membership: {send_comment_emails: '1'}
      response.should redirect_to(login_url(next: request.fullpath))
      @membership.reload.send_comment_emails.should be_false
    end

    context "[authenticated]" do
      before(:each) { login_as @membership.user }

      it "should modify the membership" do
        patch :update, project_id: @membership.project.to_param, membership: {send_comment_emails: '1'}
        response.status.should redirect_to(edit_project_my_membership_url(@membership.project))
        @membership.reload.send_comment_emails.should be_true
      end

      it "should not allow protected attributes to be updated" do
        patch :update, project_id: @membership.project.to_param, membership: {project_id: 123}
        response.status.should eql(400)
        -> { @membership.reload }.should_not change(@membership, :project_id)
      end
    end
  end

  describe "#destroy" do
    before(:each) { @membership = FactoryGirl.create(:membership) }

    it "should require a logged-in user" do
      delete :destroy, project_id: @membership.project.to_param
      response.should redirect_to(login_url(next: request.fullpath))
    end

    it "should not allow the owner to delete his/her project" do
      login_as @membership.project.owner
      delete :destroy, project_id: @membership.project.to_param
      response.should redirect_to(account_url)
    end

    context "[authenticated]" do
      before(:each) { login_as @membership.user }

      it "should delete the membership" do
        delete :destroy, project_id: @membership.project.to_param
        response.should redirect_to(account_url)
        -> { @membership.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
