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

RSpec.describe AccountsController, type: :controller do
  describe "#update" do
    before :each do
      @user  = FactoryGirl.create(:user)
      @attrs = {password: 'newpass', password_confirmation: 'newpass', first_name: 'NewFN', last_name: 'NewLN'}
    end

    include_context "setup for required logged-in user"
    it "should require a logged-in user" do
      patch :update, user: @attrs
      expect(response).to redirect_to(login_required_redirection_url(next: request.fullpath))
      expect { @user.reload }.not_to change(@user, :first_name)
    end

    context '[authenticated]' do
      before(:each) { login_as @user }

      it "should update the user and redirect to the account page" do
        patch :update, user: @attrs
        expect(response).to redirect_to(account_url)

        expect(@user.reload.first_name).to eql('NewFN')
        expect(@user.last_name).to eql('NewLN')
        expect(@user.authentic?('newpass')).to eql(true)
      end

      it "should render the account page on failure" do
        patch :update, user: @attrs.merge(password_confirmation: 'oops')
        expect(response).to render_template('show')
      end

      it "should not update the password if it's not provided" do
        @user.reload
        patch :update, user: @attrs.merge('password' => '')
        expect { @user.reload }.not_to change(@user, :crypted_password)
      end
    end
  end if Squash::Configuration.authentication.strategy == 'password'
end
