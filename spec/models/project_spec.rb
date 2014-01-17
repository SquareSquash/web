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

describe Project do
  describe '#repo' do
    it "should check out the repository and return a Repository object" do
      Project.where(repository_url: "git@github.com:RISCfuture/better_caller.git").delete_all
      repo = FactoryGirl.create(:project, repository_url: "git@github.com:RISCfuture/better_caller.git").repo
      expect(repo).to be_kind_of(Git::Base)
      expect(repo.index).to be_nil # should be bare
      expect(repo.repo.path).to eql(Rails.root.join('tmp', 'repos', 'dcc31d9e2fd24f244590edcd7d73baa89e907785.git').to_s)
    end
  end

  describe "#path_type" do
    before :all do
      @project = FactoryGirl.create(:project, filter_paths: %w( vendor/ ), whitelist_paths: %w( vendor/lib/ ))
    end

    it "should return :project for a file under app/" do
      expect(@project.path_type('app/models/foo.rb')).to eql(:project)
    end

    it "should return :library for an absolute path" do
      expect(@project.path_type('/Users/sancho/.rvm/some/path/lib.rb')).to eql(:library)
    end

    it "should return :library for meta-file-name lines" do
      expect(@project.path_type('(irb)')).to eql(:library)
    end

    it "should return :filtered for a file under vendor/ when vendor/ is in the filter paths" do
      expect(@project.path_type('vendor/lib.rb')).to eql(:filtered)
    end

    it "should return :project for a file under vendor/lib when vendor/lib is in the whitelist paths" do
      expect(@project.path_type('vendor/lib/foobar.rb')).to eql(:project)
    end
  end

  context '[hooks]' do
    it "should create a membership for the owner" do
      project    = FactoryGirl.create(:project)
      membership = project.memberships.where(user_id: project.owner_id).first
      expect(membership).not_to be_nil
      expect(membership).to be_admin
    end

    it "should create a membership for the new owner when the owner is changed" do
      project   = FactoryGirl.create(:project)
      new_owner = FactoryGirl.create(:user)
      project.update_attribute :owner, new_owner
      membership = project.memberships.where(user_id: new_owner.id).first
      expect(membership).not_to be_nil
      expect(membership).to be_admin
    end

    it "should promote an existing owner membership to admin" do
      project   = FactoryGirl.create(:project)
      new_owner = FactoryGirl.create(:membership, project: project).user
      project.update_attribute :owner, new_owner
      membership = project.memberships.where(user_id: new_owner.id).first
      expect(membership).not_to be_nil
      expect(membership).to be_admin
    end

    it "should not remove the membership from the old owner" do
      project   = FactoryGirl.create(:project)
      old_owner = project.owner
      project.update_attribute :owner, FactoryGirl.create(:user)
      membership = project.memberships.where(user_id: old_owner.id).first
      expect(membership).not_to be_nil
      expect(membership).to be_admin
    end

    it "should create a new API key automatically" do
      expect(FactoryGirl.create(:project, api_key: nil).api_key).not_to be_nil
    end

    it "should automatically set commit_url_format if able" do
      expect(FactoryGirl.create(:project, repository_url: 'git@github.com:RISCfuture/better_caller.git').commit_url_format).to eql('https://github.com/RISCfuture/better_caller/commit/%{commit}')
      expect(FactoryGirl.create(:project, repository_url: 'https://RISCfuture@github.com/RISCfuture/better_caller.git').commit_url_format).to eql('https://github.com/RISCfuture/better_caller/commit/%{commit}')
      Project.where(repository_url: 'git@github.com:RISCfuture/better_caller.git').delete_all
      expect(FactoryGirl.create(:project, repository_url: 'git@github.com:RISCfuture/better_caller.git').commit_url_format).to eql('https://github.com/RISCfuture/better_caller/commit/%{commit}')
    end

    it "should not overwrite a custom commit_url_format" do
      Project.where(repository_url: 'git@github.com:RISCfuture/better_caller.git').delete_all
      expect(FactoryGirl.create(:project, repository_url: 'git@github.com:RISCfuture/better_caller.git', commit_url_format: 'http://example.com/%{commit}').commit_url_format).to eql('http://example.com/%{commit}')
    end
  end

  context '[validations]' do
    it "should not allow a default environment outside of the project" do
      project = FactoryGirl.build(:project, default_environment: FactoryGirl.create(:environment))
      expect(project).not_to be_valid
      expect(project.errors[:default_environment_id]).to eql(['is not an environment in this project'])
    end
  end

  describe "#commit_url" do
    it "should return the URL to a commit" do
      expect(FactoryGirl.build(:project, commit_url_format: 'http://example.com/%{commit}').commit_url('abc123')).to eql('http://example.com/abc123')
    end

    it "should return nil if commit_url_format is not set" do
      expect(FactoryGirl.build(:project, commit_url_format: nil).commit_url('abc123')).to be_nil
    end
  end
end
