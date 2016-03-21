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

if Squash::Configuration.authentication.strategy == 'google'
  class FakeController
    attr_accessor :google_auth_data

    def self.helper_method(*) end
    def logger(*) Rails.logger end

    include AuthenticationHelpers
    include GoogleAuthenticationHelpers

    def google_auth_data; end
  end

  RSpec.describe GoogleAuthenticationHelpers, type: :model do
    before(:each) { @controller = FakeController.new }

    describe "#log_in" do
      before :all do
        @auth_data = { "email" => "email.test@example.com", "sub" => "uid-123" }
        @user = FactoryGirl.create(:user, google_auth_data: @auth_data)
      end
      before(:each) { @controller.google_auth_data = @auth_data }

      it "should find a user from Google Auth data" do
        expect(@controller).to receive(:google_auth_data).twice.and_return(@auth_data)
        expect(@controller).to receive(:log_in_user).once.with(@user).and_return("USER")
        expect(@controller.log_in).to be_truthy
      end

      it "should fail to find or create a user" do
        expect(@controller).to receive(:google_auth_data).exactly(3).times.and_return(@auth_data)
        expect(User).to receive(:find_or_create_by_google_auth_data).once.with(@auth_data).and_return(nil)
        expect(@controller).not_to receive(:log_in_user)
        expect(@controller.log_in).to be false
      end
    end

    describe "#third_party_login?" do
      it "should return false for being a 3rd-party login service" do
        expect(@controller.send(:third_party_login?)).to be true
      end
    end
  end
end
