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

require "spec_helper"

describe NotificationMailer do
  before(:all) { @env = FactoryGirl.create(:environment) }

  before :each do
    @bug   = FactoryGirl.create(:bug, environment: @env)
    @count = @bug.events.count
  end

  describe "#blame" do
    it "should create an email event" do
      allow(@bug).to receive(:blamed_email).and_return('foo@bar.com')
      NotificationMailer.blame(@bug).deliver
      expect(@bug.events.count).to eql(@count + 1)
      expect(@bug.events.order('id DESC').first.kind).to eql('email')
      expect(@bug.events.order('id DESC').first.data['recipients']).to eql(['foo@bar.com'])
    end

    it "... unless no email was sent" do
      NotificationMailer.blame(@bug).deliver
      expect(@bug.events.count).to eql(@count)
    end
  end

  describe "#critical" do
    it "should create an email event" do
      @bug.environment.project.critical_mailing_list = 'foo@bar.com'
      NotificationMailer.critical(@bug).deliver
      expect(@bug.events.count).to eql(@count + 1)
      expect(@bug.events.order('id DESC').first.kind).to eql('email')
      expect(@bug.events.order('id DESC').first.data['recipients']).to eql(['foo@bar.com'])
    end

    it "... unless no email was sent" do
      NotificationMailer.critical(@bug).deliver
      expect(@bug.events.count).to eql(@count)
    end
  end
end
