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

if Squash::Configuration.authentication.strategy == 'password'
  class FakeController
    def self.helper_method(*) end
    def logger(*) Rails.logger end

    include AuthenticationHelpers
    include PasswordAuthenticationHelpers
  end

  describe PasswordAuthenticationHelpers do
    before(:each) { @controller = FakeController.new }

    describe "#log_in" do
      before(:all) { @user = FactoryGirl.create(:user, password: 'password123') }

      it "should accept a valid username and password" do
        @controller.should_receive(:log_in_user).once.with(@user)
        @controller.log_in(@user.username, 'password123').should be_true
      end

      it "should not accept an unknown username" do
        @controller.should_not_receive :log_in_user
        @controller.log_in('unknown', 'password123').should be_false
      end

      it "should not accept an invalid password" do
        @controller.should_not_receive :log_in_user
        @controller.log_in(@user.username, 'password-wrong').should be_false
      end
    end
  end
end
