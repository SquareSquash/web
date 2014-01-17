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

describe Blamer::Recency do
  before :each do
    Project.delete_all
    @project   = FactoryGirl.create(:project)
    @env       = FactoryGirl.create(:environment, project: @project)
    @bug       = FactoryGirl.create(:bug,
                                    file:            'lib/better_caller/extensions.rb',
                                    line:            2,
                                    environment:     @env,
                                    blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44')
    @shell_bug = FactoryGirl.build(:bug, environment: @env)
  end

  it "should raise an error if it can't find a commit" do
    @occurrence = FactoryGirl.build(:rails_occurrence,
                                    bug:        @shell_bug,
                                    backtraces: [{"name"      => "Thread 0",
                                                  "faulted"   => true,
                                                  "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                   "line"   => 2,
                                                                   "symbol" => "foo"}]}],
                                    revision:   'abcdef')
    expect { Blamer::Recency.new(@occurrence).find_or_create_bug! }.to raise_error('Need a resolvable commit')
  end

  it "should resolve duplicate bugs" do
    original = FactoryGirl.create(:bug, environment: @env)
    @bug.update_attribute :duplicate_of, original
    @occurrence = FactoryGirl.build(:rails_occurrence,
                                    bug:        @shell_bug,
                                    backtraces: [{"name"      => "Thread 0",
                                                  "faulted"   => true,
                                                  "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                   "line"   => 2,
                                                                   "symbol" => "foo"}]}],
                                    revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
    bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
    expect(bug).to eql(original)
  end

  context "[hosted projects]" do
    it "should match an existing bug in the same environment" do
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                     "line"   => 2,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug).to eql(@bug)
    end

    it "should match an existing closed bug in the same environment" do
      @bug.update_attribute :fixed, true
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                     "line"   => 2,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug).to eql(@bug)
    end

    it "should create a new bug if no existing bug could be found" do
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                     "line"   => 3,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug).not_to eql(@bug)
      expect(bug.file).to eql('lib/better_caller/extensions.rb')
      expect(bug.line).to eql(3)
    end

    it "should not match an existing bug in a different environment" do
      @shell_bug.environment = FactoryGirl.create(:environment, project: @project)
      @occurrence            = FactoryGirl.build(:rails_occurrence,
                                                 bug:        @shell_bug,
                                                 backtraces: [{"name"      => "Thread 0",
                                                               "faulted"   => true,
                                                               "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                                "line"   => 2,
                                                                                "symbol" => "foo"}]}],
                                                 revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug                    = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug).not_to eql(@bug)
      expect(bug.environment).to eql(@shell_bug.environment)
    end

    it "should not match an existing bug of a different class name" do
      @shell_bug.class_name = 'SomeOtherError'
      @occurrence           = FactoryGirl.build(:rails_occurrence,
                                                bug:        @shell_bug,
                                                backtraces: [{"name"      => "Thread 0",
                                                              "faulted"   => true,
                                                              "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                               "line"   => 2,
                                                                               "symbol" => "foo"}]}],
                                                revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug                   = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug).not_to eql(@bug)
      expect(bug.class_name).to eql('SomeOtherError')
    end
  end

  context "[distributed projects]" do
    before :each do
      @deploy = FactoryGirl.create(:deploy, environment: @env, revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44')
      @deploy = FactoryGirl.create(:deploy, environment: @env, revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44')
      @bug.update_attribute :deploy, @deploy
    end

    it "should match an existing bug in the same deploy" do
      @shell_bug.deploy = @bug.deploy
      @occurrence       = FactoryGirl.build(:rails_occurrence,
                                            bug:        @shell_bug,
                                            backtraces: [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                           "line"   => 2,
                                                                           "symbol" => "foo"}]}],
                                            revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug               = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug).to eql(@bug)
      expect(bug.deploy).to eql(@shell_bug.deploy)
    end

    it "should match an existing closed bug in the same deploy" do
      @bug.update_attribute :fixed, true
      @shell_bug.deploy = @bug.deploy
      @occurrence       = FactoryGirl.build(:rails_occurrence,
                                            bug:        @shell_bug,
                                            backtraces: [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                           "line"   => 2,
                                                                           "symbol" => "foo"}]}],
                                            revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug               = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug).to eql(@bug)
    end

    it "should otherwise match an existing open bug in another deploy, and advance the deploy ID" do
      @shell_bug.deploy = FactoryGirl.create(:deploy, environment: @env, revision: '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      @occurrence       = FactoryGirl.build(:rails_occurrence,
                                            bug:        @shell_bug,
                                            backtraces: [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                           "line"   => 2,
                                                                           "symbol" => "foo"}]}],
                                            revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug               = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug).to eql(@bug)
      expect(bug.deploy).to eql(@shell_bug.deploy)
    end

    it "should not otherwise match an existing closed bug" do
      @shell_bug.deploy = FactoryGirl.create(:deploy, environment: @env, revision: '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      @bug.update_attribute :fixed, true
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                     "line"   => 2,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug).not_to eql(@bug)
      expect(bug.deploy).to eql(@shell_bug.deploy)
    end
  end

  context "[blame]" do
    it "should set the bug's file and line using git-blame" do
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "/library/file",
                                                                     "line"   => 10,
                                                                     "symbol" => "foo"},
                                                                    {"file"   => "ext/better_caller.c",
                                                                     "line"   => 50,
                                                                     "symbol" => "foo"},
                                                                    {"file"   => "ext/better_caller.c",
                                                                     "line"   => 46,
                                                                     "symbol" => "foo"},
                                                                    {"file"   => "ext/better_caller.c",
                                                                     "line"   => 31,
                                                                     "symbol" => "foo"},
                                                                    {"file"   => "ext/better_caller.c",
                                                                     "line"   => 27,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug.file).to eql('ext/better_caller.c')
      expect(bug.line).to eql(50)
      expect(bug.blamed_revision).to eql('7f9ef6977510b3487483cf834ea02d3e6d7f6f13')
    end

    it "should use the topmost file if the backtrace is all library files" do
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "/library/file",
                                                                     "line"   => 27,
                                                                     "symbol" => "foo"},
                                                                    {"file"   => "/library/file2",
                                                                     "line"   => 11,
                                                                     "symbol" => "foo"},
                                                                    {"file"   => "/library/file3",
                                                                     "line"   => 5,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug.file).to eql('/library/file')
      expect(bug.line).to eql(27)
      expect(bug.special_file?).to be_false
      expect(bug.blamed_revision).to be_nil
    end

    it "should use the topmost project file if none of the project files have associated commits" do
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "/library/file",
                                                                     "line"   => 27,
                                                                     "symbol" => "foo"},
                                                                    {"file"   => "fake/project/file",
                                                                     "line"   => 11,
                                                                     "symbol" => "foo"},
                                                                    {"file"   => "/library/file2",
                                                                     "line"   => 5,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug.file).to eql('fake/project/file')
      expect(bug.line).to eql(11)
      expect(bug.special_file?).to be_false
      expect(bug.blamed_revision).to be_nil
    end

    it "should set special_file for unsymbolicated bugs" do
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"type"    => "address",
                                                                     "address" => 27},
                                                                    {"type"    => "address",
                                                                     "address" => 11},
                                                                    {"type"    => "address",
                                                                     "address" => 5}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug.file).to eql('0x0000001B')
      expect(bug.line).to eql(1)
      expect(bug.special_file?).to be_true
    end

    it "should set special_file but use the backtrace elements for an obfuscated Java bug" do
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"type"       => "obfuscated",
                                                                     "file"       => "A.java",
                                                                     "line"       => 15,
                                                                     "symbol"     => "b",
                                                                     "class_name" => "A"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug.file).to eql('A.java')
      expect(bug.line).to eql(15)
      expect(bug.special_file?).to be_true
    end

    it "should abs Java line numbers, which can apparently be negative" do
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"type"       => "obfuscated",
                                                                     "file"       => "A.java",
                                                                     "line"       => -15,
                                                                     "symbol"     => "b",
                                                                     "class_name" => "A"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug.file).to eql('A.java')
      expect(bug.line).to eql(15)
    end
  end

  context "[message filtering]" do
    it "should filter the message" do
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      message:    "Undefined 123 for #<Object:0x007fedfa0aa920>",
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                     "line"   => 3,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug         = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug.message_template).to eql('Undefined [NUMBER] for #<Object:[ADDRESS]>')
    end

    it "should use the DB error filters" do
      @shell_bug.class_name = "Mysql::Error"
      @occurrence           = FactoryGirl.build(:rails_occurrence,
                                                bug:        @shell_bug,
                                                message:    "Cannot drop index 'foo_index': needed in a foreign key",
                                                backtraces: [{"name"      => "Thread 0",
                                                              "faulted"   => true,
                                                              "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                               "line"   => 3,
                                                                               "symbol" => "foo"}]}],
                                                revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      bug                   = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug.message_template).to eql("Cannot drop index '[STRING]': needed in a foreign key")
    end

    it "should not filter the message if filtering is disabled" do
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      message:    "Undefined 123 for #<Object:0x007fedfa0aa920>",
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                     "line"   => 3,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
      @shell_bug.environment.project.update_attribute :disable_message_filtering, true
      bug = Blamer::Recency.new(@occurrence).find_or_create_bug!
      expect(bug.message_template).to eql('Undefined 123 for #<Object:0x007fedfa0aa920>')
    end
  end

  context "[reopening]" do
    it "should not reopen a fixed but not deployed bug" do
      @bug.update_attribute :fixed, true
      @bug.update_attribute :fixed_at, Time.now
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                     "line"   => 2,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')

      blamer = Blamer::Recency.new(@occurrence)
      bug    = blamer.find_or_create_bug!
      blamer.reopen_bug_if_necessary! bug


      expect(@bug.reload).to be_fixed
    end

    it "should reopen a fixed and deployed bug" do
      @bug.update_attributes fixed: true, fix_deployed: true
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                     "line"   => 2,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')

      blamer = Blamer::Recency.new(@occurrence)
      bug    = blamer.find_or_create_bug!
      blamer.reopen_bug_if_necessary! bug

      expect(@bug.reload).not_to be_fixed
    end

    it "should reopen a fixed and stale bug" do
      @bug.update_attribute :fixed, true
      @bug.update_attribute :fixed_at, 40.days.ago
      @occurrence = FactoryGirl.build(:rails_occurrence,
                                      bug:        @shell_bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                     "line"   => 2,
                                                                     "symbol" => "foo"}]}],
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')

      blamer = Blamer::Recency.new(@occurrence)
      bug    = blamer.find_or_create_bug!
      blamer.reopen_bug_if_necessary! bug

      expect(@bug.reload).not_to be_fixed
    end

    it "should not reopen a distributed project's bug" do
      deploy = FactoryGirl.create(:deploy, environment: @env)
      @bug.update_attributes fixed: true, fix_deployed: true
      @bug.update_attribute :deploy, deploy
      @shell_bug.deploy = deploy
      @occurrence       = FactoryGirl.build(:rails_occurrence,
                                            bug:        @shell_bug,
                                            backtraces: [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                           "line"   => 2,
                                                                           "symbol" => "foo"}]}],
                                            revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')

      blamer = Blamer::Recency.new(@occurrence)
      bug    = blamer.find_or_create_bug!
      blamer.reopen_bug_if_necessary! bug

      expect(@bug.reload).to be_fixed
    end
  end
end

