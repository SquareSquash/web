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

describe ActiveRecord::Base do
  describe "#touch" do
    it "should update a single-key record" do
      user = FactoryGirl.create(:user, created_at: 1.day.ago, updated_at: 1.day.ago)
      -> { user.touch.should be_true }.should change(user, :updated_at)
    end

    it "should update a multi-key record" do
      nt = FactoryGirl.create(:notification_threshold, last_tripped_at: 1.day.ago)
      -> { nt.touch(:last_tripped_at).should be_true }.should change(nt, :last_tripped_at)
    end
  end
end
