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

describe Environment do
  context "[triggers]" do
    before(:all) { @env = FactoryGirl.create(:environment) }
    before(:each) { Bug.delete_all }

    it "should increment the cached counter when a new bug is added" do
      FactoryGirl.create :bug, environment: @env
      @env.reload.bugs_count.should eql(1)
    end

    it "should not increment the cached counter when a new closed bug is added" do
      FactoryGirl.create :bug, environment: @env, fixed: true
      @env.reload.bugs_count.should eql(0)

      FactoryGirl.create :bug, environment: @env, irrelevant: true
      @env.reload.bugs_count.should eql(0)
    end

    it "should decrement the cached counter when an open bug is deleted" do
      bug = FactoryGirl.create(:bug, environment: @env)
      bug.destroy
      @env.reload.bugs_count.should eql(0)
    end

    it "should not decrement the cached counter when a closed bug is deleted" do
      FactoryGirl.create_list :bug, 2, environment: @env
      
      bug = FactoryGirl.create(:bug, environment: @env, fixed: true)
      bug.destroy
      @env.reload.bugs_count.should eql(2)
      bug = FactoryGirl.create(:bug, environment: @env, irrelevant: true)
      bug.destroy
      @env.reload.bugs_count.should eql(2)
    end

    it "should increment the cached counter when a bug is opened" do
      bug1 = FactoryGirl.create(:bug, environment: @env, fixed: true)
      bug2 = FactoryGirl.create(:bug, environment: @env, irrelevant: true)
      @env.reload.bugs_count.should eql(0)

      bug1.update_attribute :fixed, false
      @env.reload.bugs_count.should eql(1)
      bug2.update_attribute :irrelevant, false
      @env.reload.bugs_count.should eql(2)
    end

    it "should decrement the cached counter when a bug is closed" do
      bug1 = FactoryGirl.create(:bug, environment: @env)
      bug2 = FactoryGirl.create(:bug, environment: @env)
      @env.reload.bugs_count.should eql(2)

      bug1.update_attribute :fixed, true
      @env.reload.bugs_count.should eql(1)
      bug2.update_attribute :irrelevant, true
      @env.reload.bugs_count.should eql(0)
    end
  end
end
