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

describe EmailsController do
  describe "#index" do
    before :all do
      @user   = FactoryGirl.create(:user)
      @emails = FactoryGirl.create_list(:email, 11, user: @user)
    end

    it "should require a logged in user" do
      get :index, format: 'json'
      response.status.should eql(401)
      response.body.should be_blank
    end

    context "[authenticated]" do
      before(:each) { login_as @user }

      it "should load the first 10 emails" do
        get :index, format: 'json'
        response.status.should eql(200)
        response.body.should eql(@emails.sort_by(&:email)[0, 10].map { |e| e.as_json.merge(url: account_email_url(e)) }.to_json)
      end

      it "should filter emails given a query" do
        filter1 = FactoryGirl.create(:email, user: @user, email: 'filter1@example.com')
        filter2 = FactoryGirl.create(:email, user: @user, email: 'filter2@example.com')

        get :index, format: 'json', query: 'filter'
        response.status.should eql(200)
        response.body.should eql([filter1, filter2].map { |e| e.as_json.merge(url: account_email_url(e)) }.to_json)
      end

      it "should not include primary emails" do
        @user.emails.redirected.delete_all
        get :index, format: 'json'
        response.status.should eql(200)
        response.body.should eql('[]')
      end

      it "should not include project-specific emails if project_id is not set" do
        email = FactoryGirl.create(:email, user: @user, project: FactoryGirl.create(:membership, user: @user).project)
        get :index, format: 'json'
        JSON.parse(response.body).map { |e| e['email'] }.should_not include(email.email)
      end

      it "should only include project-specific emails if project_id is set" do
        project = FactoryGirl.create(:membership, user: @user).project
        email1  = FactoryGirl.create(:email, user: @user, project: project)
        FactoryGirl.create :email, user: @user, project: FactoryGirl.create(:membership, user: @user).project
        get :index, project_id: project.to_param, format: 'json'
        JSON.parse(response.body).map { |e| e['email'] }.should eql([email1.email])
      end
    end
  end

  describe "#create" do
    before(:all) { @user = FactoryGirl.create(:user) }
    before(:each) { @user.emails.redirected.delete_all }

    it "should require a logged in user" do
      -> { post :create, format: 'json', email: {email: 'foo@bar.com'} }.should_not change(Email, :count)
      response.status.should eql(401)
      response.body.should be_blank
    end

    context "[authenticated]" do
      before(:each) { login_as @user }

      it "should create a new redirected email" do
        post :create, format: 'json', email: {email: 'new@example.com'}
        response.status.should eql(201)
        @user.emails.redirected.count.should eql(1)
        @user.emails.redirected.first.email.should eql('new@example.com')
        response.body.should eql(@user.emails.redirected.first.to_json)
      end

      it "should not allow a primary email to be created" do
        post :create, format: 'json', email: {email: 'new@example.com', primary: '1'}
        response.status.should eql(400)
        @user.emails.count.should eql(1)
      end

      it "should handle validation errors" do
        post :create, format: 'json', email: {email: 'not an email'}
        response.status.should eql(422)
        response.body.should eql({email: {email: ['not a valid email address']}}.to_json)
        @user.emails.redirected.count.should be_zero
      end

      it "should set project_id if given" do
        @user.emails.redirected.delete_all
        project = FactoryGirl.create(:membership, user: @user).project
        post :create, project_id: project.to_param, format: 'json', email: {email: 'new2@example.com'}
        response.status.should eql(201)
        @user.emails.redirected.first.project_id.should eql(project.id)
      end
    end
  end

  describe "#destroy" do
    before(:all) { @user = FactoryGirl.create(:user) }

    before :each do
      @user.emails.redirected.delete_all
      @email = FactoryGirl.create(:email, user: @user)
    end

    it "should require a logged in user" do
      -> { delete :destroy, id: @email.to_param, format: 'json' }.should_not change(Email, :count)
      response.status.should eql(401)
      response.body.should be_blank
    end

    context "[authenticated]" do
      before(:each) { login_as @user }

      it "should 404 given an unknown email" do
        delete :destroy, id: 'unknown@email.com', format: 'json'
        response.status.should eql(404)
      end

      it "should not allow a primary email to be deleted" do
        delete :destroy, id: @user.email, format: 'json'
        response.status.should eql(404)
        @user.emails.count.should eql(2)
      end

      it "should delete a redirected email" do
        delete :destroy, id: @email.to_param, format: 'json'
        response.status.should eql(204)
        @user.emails.redirected.count.should be_zero
      end
    end
  end
end
