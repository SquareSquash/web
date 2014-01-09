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

describe Blamer::Simple do
  it "should set the bug's file and line using git-blame" do
    @project   = FactoryGirl.create(:project)
    @env       = FactoryGirl.create(:environment, project: @project)
    @shell_bug = FactoryGirl.build(:bug, environment: @env)


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
    bug         = Blamer::Simple.new(@occurrence).find_or_create_bug!
    bug.file.should eql('[S] 10e95a0abb419d791a30d5dd0fe163b6f1c2bbf1e10ef0a303f3315cd149bcc5')
    bug.special_file?.should be_true
    bug.line.should eql(1)
    bug.blamed_revision.should be_nil
  end

  it "should not touch the Git repo at all when processing an occurrence" do
    Project.where(repository_url: 'git@github.com:RISCfuture/better_caller.git').delete_all
    @project   = FactoryGirl.create(:project, repository_url: 'git@github.com:RISCfuture/better_caller.git')
    @commit    = @project.repo.object('HEAD^')

    # this will be a valid exception but with a stack trace that doesn't make
    # sense in the context of the project (the files don't actually exist in the
    # repo). this will test the scenarios where no blamed commits can be found.
    @exception = nil
    begin
      raise ArgumentError, "Well crap"
    rescue
      @exception = $!
    end
    @line        = @exception.backtrace.first.split(':')[1].to_i # get the line number of the first line of the backtrace

    Bug.delete_all
    @params = Squash::Ruby.send(:exception_info_hash, @exception, Time.now, {}, nil)
    @params.merge!('api_key'     => @project.api_key,
                   'environment' => 'production',
                   'revision'    => @commit.sha,
                   'user_data'   => {'foo' => 'bar'})

    @project.should_not_receive :repo
    OccurrencesWorker.new(@params).perform
  end
end
