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

describe UsersController do
  describe "#index" do
    before :all do
      [Project, User].each &:destroy_all
      @users = 20.times.map { |i| FactoryGirl.create :user, username: "filter-#{i}" }
    end

    it "should require a logged-in user" do
      get :index, format: 'json'
      response.status.should eql(401)
      response.body.should be_blank
    end

    context '[authenticated]' do
      before(:each) { login_as @users.first } # log in as any user

      it "should return an empty array given no query" do
        get :index, format: 'json'
        response.status.should eql(200)
        response.body.should eql('[]')
      end

      it "should load the first 10 filtered users sorted by username" do
        get :index, query: 'filter', format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).map { |r| r['username'] }.should eql(@users.map(&:username).sort[0, 10])
      end

      it "should include membership information when given a project ID" do
        project = FactoryGirl.create(:project)
        @users.sort_by(&:username).each_with_index { |user, i| FactoryGirl.create(:membership, project: project, user: user) if i < 5 }

        get :index, query: 'filter', format: 'json', project_id: project.to_param
        response.status.should eql(200)
        JSON.parse(response.body).map { |r| r['is_member'] }.should eql([true]*5 + [false]*5)
      end

      it "should load the next 10 filtered users when given a last parameter" do
        @users.sort_by! &:username

        get :index, query: 'filter', last: @users[9].username, format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).map { |r| r['username'] }.should eql(@users.map(&:username).sort[10, 10])
      end
    end
  end

  describe "#create" do
    before :each do
      User.where(username: 'newguy').delete_all
      @attrs = {
          'username'              => 'newguy',
          'password'              => 'newguy123',
          'password_confirmation' => 'newguy123',
          'first_name'            => 'New',
          'last_name'             => 'Guy',
          'email_address'         => 'new@guy.example.com'
      }
    end

    if Squash::Configuration.authentication.registration_enabled?
      it "should create the new user" do
        post :create, user: @attrs
        User.where(username: 'newguy').exists?.should be_true
        response.should redirect_to(root_url)
      end

      it "should log the new user in" do
        post :create, user: @attrs
        user = User.find_by_username!('newguy')
        session[:user_id].should eql(user.id)
      end

      it "should redirect to the :next parameter" do
        post :create, user: @attrs, next: account_url
        response.should redirect_to(account_url)
      end

      it "should render the login page for invalid attributes" do
        post :create, user: @attrs.merge('password_confirmation' => 'whoops'), next: account_url
        response.should render_template('sessions/new')
        assigns(:user).errors[:password_confirmation].should eql(['doesn’t match'])
      end
    else
      it "should not be possible to create a new user" do
        post :create, user: @attrs
        User.where(username: 'newguy').exists?.should be_false
        response.should redirect_to(login_url)
      end
    end
  end if Squash::Configuration.authentication.strategy == 'password'
end
