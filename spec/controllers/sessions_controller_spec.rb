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

describe SessionsController do
  before(:all) do
    attrs = Squash::Configuration.authentication.strategy == 'password' ? {password: 'password123'} : {}
    @user = FactoryGirl.create(:user, attrs)
  end

  describe "#create" do
    before :each do
      if defined?(Net::LDAP)
        @ldap = double('Net::LDAP', :host= => nil, :port= => nil, :auth => nil)
        Net::LDAP.stub(:new).and_return(@ldap)
      end
    end

    context '[valid credentials]' do
      before :each do
        @ldap.stub(:bind).and_return(true)
        @ldap.stub :encryption

        entry = {:givenname => %w(Sancho), :sn => %w(Sample)}
        entry.stub(:dn).and_return('some dn')
        @ldap.stub(:search).and_yield(entry)
      end if defined?(Net::LDAP)

      it "should log in a valid username and password" do
        post :create, username: @user.username, password: 'password123'
        response.should redirect_to(root_url)
        session[:user_id].should eql(@user.id)
      end

      it "should create users that don't exist" do
        post :create, username: 'new-user', password: 'password123'
        response.should redirect_to(root_url)
        User.find(session[:user_id]).username.should eql('new-user')
      end if Squash::Configuration.authentication.strategy == 'ldap'

      it "should redirect a user to :next if in the params" do
        url = project_url(FactoryGirl.create(:project))
        post :create, username: @user.username, password: 'password123', next: url
        response.should redirect_to(url)
      end

      it "should use LDAP when creating a user" do
        post :create, username: 'sancho', password: 'password123'
        user = User.find(session[:user_id])
        user.first_name.should eql('Sancho')
        user.last_name.should eql('Sample')
      end if Squash::Configuration.authentication.strategy == 'ldap'
    end

    it "should not log in an invalid username and password" do
      @ldap.stub(:bind).and_return(false) if defined?(Net::LDAP)
      post :create, username: 'username', password: 'wrong'
      response.should render_template('new')
      session[:user_id].should be_nil
    end

    # these two are really applicable to LDAP moreso than password auth
    it "should not allow a blank password" do
      post :create, username: 'username'
      response.should render_template('new')
      session[:user_id].should be_nil
    end

    it "should not allow a blank username" do
      post :create, password: 'password123'
      response.should render_template('new')
      session[:user_id].should be_nil
    end
  end

  describe "#destroy" do
    before(:each) { login_as FactoryGirl.create(:user) }
    it "should log out a user" do
      delete :destroy
      session[:user_id].should be_nil
      response.should redirect_to(login_url)
      flash[:notice].should include('logged out')
    end
  end
end
