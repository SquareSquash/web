# encoding: utf-8

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
      expect(response).to redirect_to(login_url(next: request.fullpath))
    end

    context '[authenticated]' do
      before(:each) { login_as @user }

      it_should_behave_like "action that 404s at appropriate times", :get, :index, 'polymorphic_params(@bug, true)'

      it "should load the 50 most recent comments" do
        get :index, polymorphic_params(@bug, true, format: 'json')
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(@comments.sort_by(&:created_at).reverse.map(&:number)[0, 50])
      end

      it "should return the next 50 comments when given a last parameter" do
        @comments.sort_by! &:created_at
        @comments.reverse!

        get :index, polymorphic_params(@bug, true, last: @comments[49].number, format: 'json')
        expect(response.status).to eql(200)
        expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(@comments.map(&:number)[50, 50])
      end

      it "should decorate the response" do
        get :index, polymorphic_params(@bug, true, format: 'json')
        JSON.parse(response.body).zip(@comments.sort_by(&:created_at).reverse).each do |(hsh, comment)|
          expect(hsh['user']['username']).to eql(comment.user.username)
          expect(hsh['body_html']).to eql(ApplicationController.new.send(:markdown).(comment.body))
          expect(hsh['user_url']).to eql(user_url(comment.user))
          expect(hsh['url']).to eql(project_environment_bug_comment_url(@env.project, @env, @bug, comment, format: 'json'))
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
      expect(response).to redirect_to(login_url(next: request.fullpath))
      expect(@bug.comments(true)).to be_empty
    end

    context '[authenticated]' do
      before(:each) { login_as @bug.environment.project.owner }

      it_should_behave_like "action that 404s at appropriate times", :get, :index, 'polymorphic_params(@bug, true)'

      it "should create the comment" do
        post :create, polymorphic_params(@bug, true, comment: {body: 'Hello, world!'}, format: 'json')
        expect(response.status).to eql(201)
        expect(comment = @bug.comments(true).first).not_to be_nil
        expect(response.body).to eql(comment.to_json)
      end

      it "should discard fields not accessible to creators" do
        @bug.comments.delete_all
        post :create, polymorphic_params(@bug, true, comment: {user_id: FactoryGirl.create(:membership, project: @env.project).user_id, body: 'Hello, world!'}, format: 'json')
        expect(@bug.comments(true)).to be_empty
      end

      it "should render the errors with status 422 if invalid" do
        post :create, polymorphic_params(@bug, true, comment: {body: ''}, format: 'json')
        expect(response.status).to eql(422)
        expect(response.body).to eql("{\"comment\":{\"body\":[\"can’t be blank\"]}}")
      end
    end
  end

  describe "#update" do
    before(:each) { @comment = FactoryGirl.create(:comment) }

    it "should require a logged-in user" do
      patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!'}, format: 'json')
      expect(response.status).to eql(401)
      expect(@comment.reload.body).not_to eql('Hello, world!')
    end

    context '[authenticated]' do
      before(:each) { login_as @comment.user }

      it_should_behave_like "action that 404s at appropriate times", :get, :index, 'polymorphic_params(@comment, false)'
      it_should_behave_like "singleton action that 404s at appropriate times", :patch, :update, 'polymorphic_params(@comment, false, bug: { fixed: true })'

      it "should update the comment" do
        patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!'}, format: 'json')
        expect(response.status).to eql(200)
        expect(@comment.reload.body).to eql('Hello, world!')
        expect(response.body).to eql(@comment.to_json)
      end

      it "should allow admins to update any comment" do
        login_as FactoryGirl.create(:membership, project: @comment.bug.environment.project, admin: true).user
        patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!'}, format: 'json')
        expect(response.status).to eql(200)
        expect(@comment.reload.body).to eql('Hello, world!')
      end

      it "should allow owners to update any comment" do
        login_as @comment.bug.environment.project.owner
        patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!'}, format: 'json')
        expect(response.status).to eql(200)
        expect(@comment.reload.body).to eql('Hello, world!')
      end

      it "should not allow other members to update any comment" do
        login_as FactoryGirl.create(:membership, project: @comment.bug.environment.project, admin: false).user
        patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!'}, format: 'json')
        expect(response.status).to eql(403)
        expect(@comment.reload.body).not_to eql('Hello, world!')
      end

      it "should not allow inaccessible fields to be updated" do
        patch :update, polymorphic_params(@comment, false, comment: {body: 'Hello, world!', number: 123}, format: 'json')
        expect(@comment.reload.number).not_to eql(123)
      end
    end
  end

  describe "#destroy" do
    before(:each) { @comment = FactoryGirl.create(:comment) }

    it "should require a logged-in user" do
      delete :destroy, polymorphic_params(@comment, false, format: 'json')
      expect(response.status).to eql(401)
      expect { @comment.reload }.not_to raise_error
    end

    context '[authenticated]' do
      before(:each) { login_as @comment.user }

      it_should_behave_like "action that 404s at appropriate times", :delete, :destroy, 'polymorphic_params(@comment, false, format: "json")'
      it_should_behave_like "singleton action that 404s at appropriate times", :delete, :destroy, 'polymorphic_params(@comment, false, bug: { fixed: true }, format: "json")'

      it "should destroy the comment" do
        delete :destroy, polymorphic_params(@comment, false)
        expect(response.status).to eql(204)
        expect { @comment.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
