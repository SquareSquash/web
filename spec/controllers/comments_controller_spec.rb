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

describe CommentsController do
  describe "#index" do
    before :all do
      membership = FactoryGirl.create(:membership)
      @env       = FactoryGirl.create(:environment, project: membership.project)
      @bug       = FactoryGirl.create(:bug, environment: @env)
      @comments  = FactoryGirl.create_list(:comment, 100, bug: @bug, user: @bug.environment.project.owner)
      @user      = membership.user
    end

    it "should require a logged-in user" do
      get :index, polymorphic_params(@bug, true)
      response.should redirect_to(login_url(next: request.fullpath))
    end

    context '[authenticated]' do
      before(:each) { login_as @user }

      it_should_behave_like "action that 404s at appropriate times", :get, :index, 'polymorphic_params(@bug, true)'

      it "should load the 50 most recent comments" do
        get :index, polymorphic_params(@bug, true, format: 'json')
        response.status.should eql(200)
        JSON.parse(response.body).map { |r| r['number'] }.should eql(@comments.sort_by(&:created_at).reverse.map(&:number)[0, 50])
      end

      it "should return the next 50 comments when given a last parameter" do
        @comments.sort_by! &:created_at
        @comments.reverse!

        get :index, polymorphic_params(@bug, true, last: @comments[49].number, format: 'json')
        response.status.should eql(200)
        JSON.parse(response.body).map { |r| r['number'] }.should eql(@comments.map(&:number)[50, 50])
      end

      it "should decorate the response" do
        get :index, polymorphic_params(@bug, true, format: 'json')
        JSON.parse(response.body).zip(@comments.sort_by(&:created_at).reverse).each do |(hsh, comment)|
          hsh['user']['username'].should eql(comment.user.username)
          hsh['body_html'].should eql(ApplicationController.new.send(:markdown).(comment.body))
          hsh['user_url'].should eql(user_url(comment.user))
          hsh['url'].should eql(project_environment_bug_comment_url(@env.project, @env, @bug, comment, format: 'json'))
        end
      end
    end
  end

  describe "#create" do
    before :all do
      membership = FactoryGirl.create(:membership)
      @env       = FactoryGirl.create(:environment, project: membership.project)
      @bug       = FactoryGirl.create(:bug, environment: @env)
      @user      = membership.user
    end

    it "should require a logged-in user" do
      post :create, polymorphic_params(@bug, true, comment: {body: 'Hello, world!'})
      response.should redirect_to(login_url(next: request.fullpath))
      @bug.comments(true).should be_empty
    end

    context '[authenticated]' do
      before(:each) { login_as @bug.environment.project.owner }

      it_should_behave_like "action that 404s at appropriate times", :get, :index, 'polymorphic_params(@bug, true)'

      it "should create the comment" do
        post :create, polymorphic_params(@bug, true, comment: {body: 'Hello, world!'}, format: 'json')
        response.status.should eql(201)
        (comment = @bug.comments(true).first).should_not be_nil
        response.body.should eql(comment.to_json)
      end

      it "should discard fields not accessible to creators" do
        @bug.comments.delete_all
        post :create, polymorphic_params(@bug, true, comment: {user_id: FactoryGirl.create(:membership, project: @env.project).user_id, body: 'Hello, world!'}, format: 'json')
        @bug.comments(true).should be_empty
      end

      it "should render the errors with status 422 if invalid" do
        post :create, polymorphic_params(@bug, true, comment: {body: ''}, format: 'json')
        response.status.should eql(422)
        response.body.should eql("{\"comment\":{\"body\":[\"can’t be blank\"]}}")
      end
    end
  end

  describe "#update" do
    before(:each) { @comment = FactoryGirl.create(:comment) }

    it "should require a logged-in user" do
      patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!'}, format: 'json')
      response.status.should eql(401)
      @comment.reload.body.should_not eql('Hello, world!')
    end

    context '[authenticated]' do
      before(:each) { login_as @comment.user }

      it_should_behave_like "action that 404s at appropriate times", :get, :index, 'polymorphic_params(@comment, false)'
      it_should_behave_like "singleton action that 404s at appropriate times", :patch, :update, 'polymorphic_params(@comment, false, bug: { fixed: true })'

      it "should update the comment" do
        patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!'}, format: 'json')
        response.status.should eql(200)
        @comment.reload.body.should eql('Hello, world!')
        response.body.should eql(@comment.to_json)
      end

      it "should allow admins to update any comment" do
        login_as FactoryGirl.create(:membership, project: @comment.bug.environment.project, admin: true).user
        patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!'}, format: 'json')
        response.status.should eql(200)
        @comment.reload.body.should eql('Hello, world!')
      end

      it "should allow owners to update any comment" do
        login_as @comment.bug.environment.project.owner
        patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!'}, format: 'json')
        response.status.should eql(200)
        @comment.reload.body.should eql('Hello, world!')
      end

      it "should not allow other members to update any comment" do
        login_as FactoryGirl.create(:membership, project: @comment.bug.environment.project, admin: false).user
        patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!'}, format: 'json')
        response.status.should eql(403)
        @comment.reload.body.should_not eql('Hello, world!')
      end

      it "should not allow inaccessible fields to be updated" do
        patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!', number: 123}, format: 'json')
        @comment.reload.number.should_not eql(123)
      end
    end
  end

  describe "#destroy" do
    before(:each) { @comment = FactoryGirl.create(:comment) }

    it "should require a logged-in user" do
      delete :destroy, polymorphic_params(@comment, false, format: 'json')
      response.status.should eql(401)
      -> { @comment.reload }.should_not raise_error
    end

    context '[authenticated]' do
      before(:each) { login_as @comment.user }

      it_should_behave_like "action that 404s at appropriate times", :delete, :destroy, 'polymorphic_params(@comment, false, format: "json")'
      it_should_behave_like "singleton action that 404s at appropriate times", :delete, :destroy, 'polymorphic_params(@comment, false, bug: { fixed: true }, format: "json")'

      it "should destroy the comment" do
        delete :destroy, polymorphic_params(@comment, false)
        response.status.should eql(204)
        -> { @comment.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
