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

describe DeployFixMarker do
  it "should raise an error if the deploy cannot be found" do
    -> { DeployFixMarker.perform 0 }.should raise_error(ActiveRecord::RecordNotFound)
  end

  it "should mark the appropriate bugs as fix_deployed" do
    Project.where(repository_url: "git@github.com:RISCfuture/better_caller.git").delete_all
    project = FactoryGirl.create(:project, repository_url: "git@github.com:RISCfuture/better_caller.git")
    env     = FactoryGirl.create(:environment, project: project)
    deploy  = FactoryGirl.build(:deploy, environment: env, revision: env.project.repo.object('HEAD^').sha)

    bug_in_range_not_fixed              = FactoryGirl.create(:bug, environment: env, resolution_revision: env.project.repo.object('HEAD^^').sha, fixed: true) # will set fixed to false later
    bug_in_range_fixed_not_deployed     = FactoryGirl.create(:bug, environment: env, resolution_revision: env.project.repo.object('HEAD^^').sha, fixed: true)
    bug_not_in_range_fixed_not_deployed = FactoryGirl.create(:bug, environment: env, resolution_revision: env.project.repo.object('HEAD').sha, fixed: true)
    Bug.where(id: bug_in_range_not_fixed.id).update_all fixed: false

    deploy.save!
    DeployFixMarker.perform deploy.id

    bug_in_range_not_fixed.reload.fix_deployed?.should be_false
    bug_in_range_fixed_not_deployed.reload.fix_deployed?.should be_true
    bug_not_in_range_fixed_not_deployed.reload.fix_deployed?.should be_false
  end

  it "should create events for the fixed bugs" do
    Project.where(repository_url: "git@github.com:RISCfuture/better_caller.git").delete_all
    project = FactoryGirl.create(:project, repository_url: "git@github.com:RISCfuture/better_caller.git")
    env    = FactoryGirl.create(:environment, project: project)
    deploy = FactoryGirl.build(:deploy, environment: env, revision: project.repo.object('HEAD^').sha)
    bug    = FactoryGirl.create(:bug, environment: env, resolution_revision: project.repo.object('HEAD^^').sha, fixed: true)

    bug.events.delete_all
    deploy.save!
    DeployFixMarker.perform deploy.id

    bug.events(true).count.should eql(1)
    bug.events.first.kind.should eql('deploy')
    bug.events.first.data['revision'].should eql(deploy.revision)
  end
end
