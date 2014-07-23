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

if Squash::Configuration.authentication.strategy == 'remote_user'
  class FakeController
    def self.helper_method(*) end
    def logger(*) Rails.logger end
    def self.before_filter(*) end

    include AuthenticationHelpers
    include RemoteUserAuthenticationHelpers
  end

  describe RemoteUserAuthenticationHelpers do
    before(:each) { @controller = FakeController.new }

    describe "#log_in" do
    #  before(:all) { @user = FactoryGirl.create(:user) }
    before(:all) { @user = User.last }
      before(:each) { ENV.delete 'REMOTE_USER' }

      it "should accept a REMOTE_USER header" do
        ENV['REMOTE_USER'] = @user.username
        expect(@controller).to receive(:log_in_user).once.with(@user)
        expect(@controller.log_in).to be_true
      end

      it "should not accept a missing header" do
        expect(@controller).not_to receive :log_in_user
        expect(@controller.log_in)
      end
    end
  end
end
