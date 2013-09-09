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

describe AccountsController do
  describe "#update" do
    before :all do
      @user  = FactoryGirl.create(:user)
      @attrs = {password: 'newpass', password_confirmation: 'newpass', first_name: 'NewFN', last_name: 'NewLN'}
    end

    it "should require a logged-in user" do
      patch :update, user: @attrs
      response.should redirect_to(login_url(next: request.fullpath))
      -> { @user.reload }.should_not change(@user, :first_name)
    end

    context '[authenticated]' do
      before(:each) { login_as @user }

      it "should update the user and redirect to the account page" do
        patch :update, user: @attrs
        response.should redirect_to(account_url)

        @user.reload.first_name.should eql('NewFN')
        @user.last_name.should eql('NewLN')
        @user.authentic?('newpass').should be_true
      end

      it "should render the account page on failure" do
        patch :update, user: @attrs.merge(password_confirmation: 'oops')
        response.should render_template('show')
      end

      it "should not update the password if it's not provided" do
        @user.reload
        patch :update, user: @attrs.merge('password' => '')
        response.should redirect_to(account_url)

        -> { @user.reload }.should_not change(@user, :crypted_password)
      end
    end
  end if Squash::Configuration.authentication.strategy == 'password'
end
