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

describe Project do
  describe '#repo' do
    it "should check out the repository and return a Repository object" do
      Project.where(repository_url: "git://github.com/RISCfuture/better_caller.git").delete_all
      repo = FactoryGirl.create(:project, repository_url: "git://github.com/RISCfuture/better_caller.git").repo
      repo.should be_kind_of(Git::Base)
      repo.index.should be_nil # should be bare
      repo.repo.path.should eql(Rails.root.join('tmp', 'repos', '55bc7a5f8df17ec2adbf954a4624ea152c3992d9.git').to_s)
    end
  end

  describe "#path_type" do
    before :all do
      @project = FactoryGirl.create(:project, filter_paths: %w( vendor/ ), whitelist_paths: %w( vendor/lib/ ))
    end

    it "should return :project for a file under app/" do
      @project.path_type('app/models/foo.rb').should eql(:project)
    end

    it "should return :library for an absolute path" do
      @project.path_type('/Users/sancho/.rvm/some/path/lib.rb').should eql(:library)
    end

    it "should return :library for meta-file-name lines" do
      @project.path_type('(irb)').should eql(:library)
    end

    it "should return :filtered for a file under vendor/ when vendor/ is in the filter paths" do
      @project.path_type('vendor/lib.rb').should eql(:filtered)
    end

    it "should return :project for a file under vendor/lib when vendor/lib is in the whitelist paths" do
      @project.path_type('vendor/lib/foobar.rb').should eql(:project)
    end
  end

  context '[hooks]' do
    it "should create a membership for the owner" do
      project    = FactoryGirl.create(:project)
      membership = project.memberships.where(user_id: project.owner_id).first
      membership.should_not be_nil
      membership.should be_admin
    end

    it "should create a membership for the new owner when the owner is changed" do
      project   = FactoryGirl.create(:project)
      new_owner = FactoryGirl.create(:user)
      project.update_attribute :owner, new_owner
      membership = project.memberships.where(user_id: new_owner.id).first
      membership.should_not be_nil
      membership.should be_admin
    end

    it "should promote an existing owner membership to admin" do
      project   = FactoryGirl.create(:project)
      new_owner = FactoryGirl.create(:membership, project: project).user
      project.update_attribute :owner, new_owner
      membership = project.memberships.where(user_id: new_owner.id).first
      membership.should_not be_nil
      membership.should be_admin
    end

    it "should not remove the membership from the old owner" do
      project   = FactoryGirl.create(:project)
      old_owner = project.owner
      project.update_attribute :owner, FactoryGirl.create(:user)
      membership = project.memberships.where(user_id: old_owner.id).first
      membership.should_not be_nil
      membership.should be_admin
    end

    it "should create a new API key automatically" do
      FactoryGirl.create(:project, api_key: nil).api_key.should_not be_nil
    end

    it "should automatically set commit_url_format if able" do
      FactoryGirl.create(:project, repository_url: 'git@github.com:RISCfuture/better_caller.git').commit_url_format.should eql("https://github.com/RISCfuture/better_caller/commit/%{commit}")
      FactoryGirl.create(:project, repository_url: 'https://RISCfuture@github.com/RISCfuture/better_caller.git').commit_url_format.should eql("https://github.com/RISCfuture/better_caller/commit/%{commit}")
      Project.where(repository_url: "git://github.com/RISCfuture/better_caller.git").delete_all
      FactoryGirl.create(:project, repository_url: 'git://github.com/RISCfuture/better_caller.git').commit_url_format.should eql("https://github.com/RISCfuture/better_caller/commit/%{commit}")
    end

    it "should not overwrite a custom commit_url_format" do
      Project.where(repository_url: "git@github.com:RISCfuture/better_caller.git").delete_all
      FactoryGirl.create(:project, repository_url: 'git@github.com:RISCfuture/better_caller.git', commit_url_format: 'http://example.com/%{commit}').commit_url_format.should eql("http://example.com/%{commit}")
    end
  end

  context '[validations]' do
    it "should not allow a default environment outside of the project" do
      project = FactoryGirl.build(:project, default_environment: FactoryGirl.create(:environment))
      project.should_not be_valid
      project.errors[:default_environment_id].should eql(['is not an environment in this project'])
    end
  end

  describe "#commit_url" do
    it "should return the URL to a commit" do
      FactoryGirl.build(:project, commit_url_format: 'http://example.com/%{commit}').commit_url('abc123').should eql('http://example.com/abc123')
    end

    it "should return nil if commit_url_format is not set" do
      FactoryGirl.build(:project, commit_url_format: nil).commit_url('abc123').should be_nil
    end
  end
end
