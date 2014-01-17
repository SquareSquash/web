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

describe SessionsController do
  before(:all) do
    attrs = Squash::Configuration.authentication.strategy == 'password' ? {password: 'password123'} : {}
    @user = FactoryGirl.create(:user, attrs)
  end

  describe "#create" do
    before :each do
      if defined?(Net::LDAP)
        @ldap = double('Net::LDAP', :host= => nil, :port= => nil, :auth => nil)
        allow(Net::LDAP).to receive(:new).and_return(@ldap)
      end
    end

    context '[valid credentials]' do
      before :each do
        allow(@ldap).to receive(:bind).and_return(true)
        allow(@ldap).to receive :encryption

        entry = {:givenname => %w(Sancho), :sn => %w(Sample)}
        allow(entry).to receive(:dn).and_return('some dn')
        allow(@ldap).to receive(:search).and_yield(entry)
      end if defined?(Net::LDAP)

      it "should log in a valid username and password" do
        post :create, username: @user.username, password: 'password123'
        expect(response).to redirect_to(root_url)
        expect(session[:user_id]).to eql(@user.id)
      end

      it "should create users that don't exist" do
        post :create, username: 'new-user', password: 'password123'
        expect(response).to redirect_to(root_url)
        expect(User.find(session[:user_id]).username).to eql('new-user')
      end if Squash::Configuration.authentication.strategy == 'ldap'

      it "should redirect a user to :next if in the params" do
        url = project_url(FactoryGirl.create(:project))
        post :create, username: @user.username, password: 'password123', next: url
        expect(response).to redirect_to(url)
      end

      it "should use LDAP when creating a user" do
        post :create, username: 'sancho', password: 'password123'
        user = User.find(session[:user_id])
        expect(user.first_name).to eql('Sancho')
        expect(user.last_name).to eql('Sample')
      end if Squash::Configuration.authentication.strategy == 'ldap'
    end

    it "should not log in an invalid username and password" do
      allow(@ldap).to receive(:bind).and_return(false) if defined?(Net::LDAP)
      post :create, username: 'username', password: 'wrong'
      expect(response).to render_template('new')
      expect(session[:user_id]).to be_nil
    end

    # these two are really applicable to LDAP moreso than password auth
    it "should not allow a blank password" do
      post :create, username: 'username'
      expect(response).to render_template('new')
      expect(session[:user_id]).to be_nil
    end

    it "should not allow a blank username" do
      post :create, password: 'password123'
      expect(response).to render_template('new')
      expect(session[:user_id]).to be_nil
    end
  end

  describe "#destroy" do
    before(:each) { login_as FactoryGirl.create(:user) }
    it "should log out a user" do
      delete :destroy
      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to(login_url)
      expect(flash[:notice]).to include('logged out')
    end
  end
end
