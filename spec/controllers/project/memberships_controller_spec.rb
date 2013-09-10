# encoding: utf-8

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

describe Project::MembershipsController do
  describe "#index" do
    before :all do
      @project            = FactoryGirl.create(:project)
      User.where("username LIKE 'filter-%'").delete_all
      @filter_memberships = 11.times.map { |i| FactoryGirl.create(:membership, project: @project, created_at: Time.now - 1.month, user: FactoryGirl.create(:user, username: "filter-#{i}")) }
      FactoryGirl.create_list :membership, 11, project: @project
      @memberships = @project.memberships.to_a # get the owner's membership too
    end

    it "should require a logged-in user" do
      get :index, polymorphic_params(@project, true)
      response.should redirect_to login_url(next: request.fullpath)
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should only allow projects that exist" do
        get :index, project_id: 'not-found'
        response.status.should eql(404)
      end

      context '[JSON]' do
        it "should load the first 10 memberships" do
          get :index, polymorphic_params(@project, true, format: 'json')
          response.status.should eql(200)
          JSON.parse(response.body).map { |r| r['user']['username'] }.should eql(@memberships.sort_by(&:created_at).reverse.map(&:user).map(&:username)[0, 10])
        end

        it "should filter memberships by name when a query is given" do
          get :index, polymorphic_params(@project, true, format: 'json', query: 'filter')
          response.status.should eql(200)
          JSON.parse(response.body).map { |r| r['user']['username'] }.should eql(@filter_memberships.sort_by(&:created_at).reverse.map(&:user).map(&:username)[0, 10])
        end
      end
    end
  end

  describe "#create" do
    before :all do
      @project = FactoryGirl.create(:project)
      FactoryGirl.create_list :membership, 100, project: @project
      @memberships = @project.memberships.to_a # get the owner's membership too
    end

    before(:each) { @user = FactoryGirl.create(:user) }

    it "should require a logged-in user" do
      post :create, polymorphic_params(@project, true, membership: {user_id: @user.id}, format: 'json')
      response.status.should eql(401)
      @project.memberships.map(&:user_id).should_not include(@user.id)
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should only allow projects that exist and the user has a membership for" do
        post :create, project_id: 'not-found', membership: {user_id: @user.id}, format: 'json'
        response.status.should eql(404)

        post :create, project_id: FactoryGirl.create(:project).to_param, membership: {user_id: @user.id}, format: 'json'
        response.status.should eql(403)
      end

      it "should create the membership (created by owner)" do
        login_as @project.owner
        post :create, polymorphic_params(@project, true, membership: {user_id: @user.id}, format: 'json')
        response.status.should eql(201)
        (membership = @project.memberships.where(user_id: @user.id).first).should_not be_nil
        response.body.should eql(membership.to_json)
      end

      it "should allow admins to add members" do
        login_as FactoryGirl.create(:membership, project: @project, admin: true).user
        post :create, polymorphic_params(@project, true, membership: {user_id: @user.id}, format: 'json')
        response.status.should eql(201)
        @project.memberships.where(user_id: @user.id).first.should_not be_nil
      end

      it "should not allow members to add other members" do
        login_as FactoryGirl.create(:membership, project: @project, admin: false).user
        post :create, polymorphic_params(@project, true, membership: {user_id: @user.id}, format: 'json')
        response.status.should eql(403)
        @project.memberships.where(user_id: @user.id).first.should be_nil
      end

      it "should allow owners to create admins" do
        login_as @project.owner
        post :create, polymorphic_params(@project, true, membership: {user_id: @user.id, admin: 'true'}, format: 'json')
        response.status.should eql(201)
        membership = @project.memberships.where(user_id: @user.id).first
        membership.should_not be_nil
        membership.should be_admin
      end

      it "should not allow admins to create admins" do
        login_as FactoryGirl.create(:membership, project: @project, admin: true).user
        post :create, polymorphic_params(@project, true, membership: {user_id: @user.id, admin: 'true'}, format: 'json')
        response.status.should eql(400)
        @project.memberships.where(user_id: @user.id).first.should be_nil
      end

      it "should render the errors with status 422 if invalid" do
        post :create, polymorphic_params(@project, true, membership: {user_id: 'halp', admin: 'true'}, format: 'json')
        response.status.should eql(422)
        response.body.should eql("{\"membership\":{\"user\":[\"can’t be blank\"]}}")
      end
    end
  end

  describe "#update" do
    before(:all) { @project = FactoryGirl.create(:project) }
    before(:each) { @membership = FactoryGirl.create(:membership, project: @project) }

    it "should require a logged-in administrator or owner" do
      patch :update, polymorphic_params(@membership, false, membership: {admin: true}, format: 'json')
      response.status.should eql(401)
      @membership.reload.should_not be_admin

      login_as FactoryGirl.create(:membership, project: @project).user
      patch :update, polymorphic_params(@membership, false, membership: {admin: true}, format: 'json')
      response.status.should eql(403)
      @membership.reload.should_not be_admin
    end

    context('[authenticated]') do
      before(:each) { login_as @project.owner }

      it "should only allow projects that exist and the user has a membership for" do
        patch :update, project_id: 'not-found', id: @membership.user.to_param, membership: {admin: true}, format: 'json'
        response.status.should eql(404)

        post :create, project_id: FactoryGirl.create(:project).to_param, id: @membership.user.to_param, membership: {admin: true}, format: 'json'
        response.status.should eql(403)
      end

      it "should allow owners to promote or demote admins" do
        patch :update, polymorphic_params(@membership, false, membership: {admin: true}, format: 'json')
        response.status.should eql(200)
        @membership.reload.should be_admin
        response.body.should eql(@membership.to_json)

        patch :update, polymorphic_params(@membership, false, membership: {admin: false}, format: 'json')
        response.status.should eql(200)
        @membership.reload.should_not be_admin
        response.body.should eql(@membership.to_json)
      end

      it "should not allow admins to promote or demote admins" do
        login_as FactoryGirl.create(:membership, project: @project, admin: true).user
        patch :update, polymorphic_params(@membership, false, membership: {admin: true}, format: 'json')
        response.status.should eql(400)
        @membership.reload.should_not be_admin
      end

      it "should render the errors with status 422 if invalid" do
        pending "No way to generate errors"
      end
    end
  end

  describe "#destroy" do
    before(:all) { @project = FactoryGirl.create(:project) }
    before(:each) { @membership = FactoryGirl.create(:membership, project: @project) }

    it "should require a logged-in administrator or owner" do
      delete :destroy, polymorphic_params(@membership, false, format: 'json')
      response.status.should eql(401)
      -> { @membership.reload }.should_not raise_error

      login_as FactoryGirl.create(:membership, project: @project).user
      delete :destroy, polymorphic_params(@membership, false, format: 'json')
      response.status.should eql(403)
      -> { @membership.reload }.should_not raise_error
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should only allow projects that exist and the user has a membership for" do
        delete :destroy, project_id: 'not-found', id: @membership.user.to_param, format: 'json'
        response.status.should eql(404)

        delete :destroy, project_id: FactoryGirl.create(:project).to_param, id: @membership.user.to_param, format: 'json'
        response.status.should eql(404)
      end

      it "should destroy the membership" do
        delete :destroy, polymorphic_params(@membership, false, format: 'json')
        response.status.should eql(204)
        -> { @membership.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end

      it "should not allow admins to delete other admins" do
        login_as FactoryGirl.create(:membership, project: @project, admin: true).user
        @membership.update_attribute :admin, true
        delete :destroy, polymorphic_params(@membership, false, format: 'json')
        response.status.should eql(403)
        -> { @membership.reload }.should_not raise_error
      end

      it "should allow the owner to delete other admins" do
        @membership.update_attribute :admin, true
        delete :destroy, polymorphic_params(@membership, false, format: 'json')
        response.status.should eql(204)
        -> { @membership.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
