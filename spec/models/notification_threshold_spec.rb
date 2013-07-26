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

describe NotificationThreshold do
  describe "#tripped?" do
    before :all do
      @threshold = FactoryGirl.create(:notification_threshold, threshold: 10, period: 1.minute, last_tripped_at: 2.minutes.ago)
    end

    it "should return false if the threshold has not yet been exceeded within the period" do
      FactoryGirl.create_list :rails_occurrence, 9, bug: @threshold.bug
      @threshold.should_not be_tripped
    end

    it "should return true if the threshold has been exceeded within the period" do
      FactoryGirl.create_list :rails_occurrence, 10, bug: @threshold.bug
      @threshold.should be_tripped
    end

    it "should return false if the threshold was tripped within the last period" do
      FactoryGirl.create_list :rails_occurrence, 10, bug: @threshold.bug
      @threshold.last_tripped_at = 45.seconds.ago
      @threshold.should_not be_tripped
    end
  end
end
