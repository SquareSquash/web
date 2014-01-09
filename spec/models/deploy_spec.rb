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

describe Deploy do
  context "[hooks]" do
    it "should queue up a DeployFixMarker job" do
      if RSpec.configuration.use_transactional_fixtures
        pending "This is done in an after_commit hook, and it can't be tested with transactional fixtures (which are always rolled back)"
      end

      Project.where(repository_url: "git@github.com:RISCfuture/better_caller.git").delete_all
      project     = FactoryGirl.create(:project, repository_url: "git@github.com:RISCfuture/better_caller.git")
      environment = FactoryGirl.create(:environment, project: project)
      deploy      = FactoryGirl.build(:deploy, environment: environment)

      dfm = double('DeployFixMarker')
      DeployFixMarker.should_receive(:new).once.with(deploy).and_return(dfm)
      dfm.should_receive(:perform).once

      deploy.save!
    end

    context "[uses_releases]" do
      before(:all) { @env = FactoryGirl.create(:environment) }

      it "should set it to true if a release is created" do
        @env.project.update_attribute :uses_releases, false
        FactoryGirl.create :release, environment: @env
        @env.project(true).uses_releases?.should be_true
      end

      it "should not set it to false if there is a subsequent deploy" do
        @env.project(true).update_attribute :uses_releases, true
        FactoryGirl.create :deploy, environment: @env
        @env.project.uses_releases?.should be_true
      end

      it "should not set it to true if the override is set" do
        @env.project.uses_releases = false
        @env.project.uses_releases_override = true
        FactoryGirl.create :release, environment: @env
        @env.project(true).uses_releases?.should be_false
      end
    end
  end

  describe "#release?" do
    before(:all) { @env = FactoryGirl.create(:environment) }

    it "should return true for a release" do
      FactoryGirl.create(:release, environment: @env).should be_release
    end

    it "should return false for a deploy" do
      FactoryGirl.create(:deploy, environment: @env).should_not be_release
    end
  end

  describe "#devices_affected" do
    it "should return the number of unique devices affected by bugs for a deploy" do
      deploy = FactoryGirl.create :deploy
      bug1 = FactoryGirl.create :bug, deploy: deploy
      bug2 = FactoryGirl.create :bug, deploy: deploy

      deploy.devices_affected.should == 0

      FactoryGirl.create :rails_occurrence, bug: bug1, device_id: 'hello'
      FactoryGirl.create :rails_occurrence, bug: bug1, device_id: 'hello'

      deploy.devices_affected.should == 1

      FactoryGirl.create :rails_occurrence, bug: bug2, device_id: 'goodbye'

      deploy.devices_affected.should == 2

      FactoryGirl.create :rails_occurrence, bug: bug1, device_id: 'goodbye'

      deploy.devices_affected.should == 2

      FactoryGirl.create :rails_occurrence, bug: bug1, device_id: 'one more'

      deploy.devices_affected.should == 3
    end
  end
end
