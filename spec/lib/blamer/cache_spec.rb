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

describe Blamer::Cache do
  describe "#blame" do
    before(:all) { @project = FactoryGirl.create(:project) }
    before(:each) { Blame.delete_all }

    it "should return a cached blame result if available" do
      blame = FactoryGirl.create(:blame, repository_hash: @project.repository_hash, file: 'myfile.rb', line: 100)
      @project.repo.should_not_receive(:blame)
      commit = double('Git::Object::Commit')
      @project.repo.should_receive(:object).once.with(blame.blamed_revision).and_return(commit)
      Blamer::Cache.instance.blame(@project, blame.revision, 'myfile.rb', 100).should eql(commit)
    end

    it "should fall back to a Git blame operation otherwise" do
      @project.repo.should_receive(:blame).once.with(
          'file.rb',
          hash_including(
              revision: 'f19641fd13d396fa1b11c595912323cc1c30571d',
              start:    3,
              end:      3
          )
      ).and_return([nil, 'bad', 'bad', 'd1500ebf6cd84775f4cd56b73e81aaa1b3fd9c47'])
      commit = double('Git::Object::Commit', sha: 'd1500ebf6cd84775f4cd56b73e81aaa1b3fd9c47')
      @project.repo.should_receive(:object).once.with('d1500ebf6cd84775f4cd56b73e81aaa1b3fd9c47').and_return(commit)

      Blamer::Cache.instance.blame(@project, 'f19641fd13d396fa1b11c595912323cc1c30571d', 'file.rb', 3).
          should eql(commit)
    end

    it "should write the result of the operation for a cache miss" do
      Blame.delete_all
      @project.repo.should_receive(:blame).once.with(
          'file.rb',
          hash_including(
              revision: 'f19641fd13d396fa1b11c595912323cc1c30571d',
              start:    3,
              end:      3
          )
      ).and_return([nil, 'bad', 'bad', 'd1500ebf6cd84775f4cd56b73e81aaa1b3fd9c47'])
      commit = double('Git::Object::Commit', sha: 'd1500ebf6cd84775f4cd56b73e81aaa1b3fd9c47')
      @project.repo.should_receive(:object).once.with('d1500ebf6cd84775f4cd56b73e81aaa1b3fd9c47').and_return(commit)

      Blamer::Cache.instance.blame @project, 'f19641fd13d396fa1b11c595912323cc1c30571d', 'file.rb', 3

      Blame.for_project(@project).where(
          revision: 'f19641fd13d396fa1b11c595912323cc1c30571d',
          file:     'file.rb',
          line:     3
      ).first.blamed_revision.should eql('d1500ebf6cd84775f4cd56b73e81aaa1b3fd9c47')
    end

    it "should update a Blame's updated_at for a cache hit" do
      blame  = FactoryGirl.create(:blame, repository_hash: @project.repository_hash, file: 'myfile.rb', line: 100, updated_at: Time.now - 1.day)
      commit = double('Git::Object::Commit')
      @project.repo.should_receive(:object).once.with(blame.blamed_revision).and_return(commit)
      Blamer::Cache.instance.blame @project, blame.revision, 'myfile.rb', 100
      -> { blame.reload }.should change(blame, :updated_at)
    end

    it "should drop the least recently used Blame when the cache is full" do
      stub_const 'Blamer::Cache::MAX_ENTRIES', 3

      FactoryGirl.create_list :blame, 4
      doomed = FactoryGirl.create :blame, updated_at: Time.now - 1.day

      @project.repo.should_receive(:blame).once.with(
          'file.rb',
          hash_including(
              revision: 'f19641fd13d396fa1b11c595912323cc1c30571d',
              start:    3,
              end:      3
          )
      ).and_return([nil, 'bad', 'bad', 'd1500ebf6cd84775f4cd56b73e81aaa1b3fd9c47'])
      commit = double('Git::Object::Commit', sha: 'd1500ebf6cd84775f4cd56b73e81aaa1b3fd9c47')
      @project.repo.should_receive(:object).once.with('d1500ebf6cd84775f4cd56b73e81aaa1b3fd9c47').and_return(commit)
      Blamer::Cache.instance.blame(@project, 'f19641fd13d396fa1b11c595912323cc1c30571d', 'file.rb', 3)

      -> { doomed.reload }.should raise_error(ActiveRecord::RecordNotFound)
      Blame.count.should eql(3)
    end
  end
end
