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

describe Watch do
  context "[observers]" do
    before :all do
      @user = FactoryGirl.create(:user)
      @unwatched_event = FactoryGirl.create(:event)
      @watched_event = FactoryGirl.create(:event)
      @unwatched_bug = @unwatched_event.bug
      watched_bug = @watched_event.bug
      @watch = FactoryGirl.create(:watch, user: @user, bug: watched_bug)
    end

    it "should fill a user's feed with events when a bug is watched" do
      FactoryGirl.create :watch, user: @user, bug: @unwatched_bug
      @user.user_events.pluck(:event_id).should include(@unwatched_event.id)
    end

    it "should remove events from a user's feed when a bug is unwatched" do
      @watch.destroy
      @user.user_events.pluck(:event_id).should_not include(@watched_event.id)
    end
  end
end
