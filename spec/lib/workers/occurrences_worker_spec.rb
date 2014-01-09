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

THIS_FILE = Pathname.new(__FILE__).relative_path_from(Rails.root).to_s

describe OccurrencesWorker do
  before :all do
    Project.where(repository_url: "git@github.com:RISCfuture/better_caller.git").delete_all
    @project   = FactoryGirl.create(:project, repository_url: "git@github.com:RISCfuture/better_caller.git")
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

    # this is a valid stack trace in the context of the repo, and will produce
    # valid blamed commits.
    @valid_trace = [
        {"file"   => "lib/better_caller/extensions.rb",
         "line"   => 11,
         "symbol" => "set_better_backtrace"},
        {"file"   => "lib/better_caller/extensions.rb",
         "line"   => 4,
         "symbol" => "set_better_backtrace"},
        {"file"   => "lib/better_caller/extensions.rb",
         "line"   => 2,
         "symbol" => nil}
    ]
  end

  before :each do
    Bug.delete_all
    @params = Squash::Ruby.send(:exception_info_hash, @exception, Time.now, {}, nil)
    @params.merge!('api_key'     => @project.api_key,
                   'environment' => 'production',
                   'revision'    => @commit.sha,
                   'user_data'   => {'foo' => 'bar'})
  end

  describe "#initialize" do
    OccurrencesWorker::REQUIRED_KEYS.each do |key|
      it "should require the #{key} key" do
        -> { OccurrencesWorker.new @params.except(key) }.should raise_error(API::InvalidAttributesError)
        -> { OccurrencesWorker.new @params.merge(key => ' ') }.should raise_error(API::InvalidAttributesError)
      end
    end

    it "should raise an error if the API key is invalid" do
      -> { OccurrencesWorker.new @params.merge('api_key' => 'not-found') }.should raise_error(API::UnknownAPIKeyError)
    end

    it "should create a new environment if one doesn't exist with that name" do
      @project.environments.delete_all
      OccurrencesWorker.new(@params).perform
      @project.environments.pluck(:name).should eql(%w( production ))
    end
  end

  describe "#perform" do
    it "attempt to git-fetch if the revision doesn't exist, then skip it if the revision STILL doesn't exist" do
      Project.stub(:find_by_api_key!).and_return(@project)
      @project.repo.should_receive(:fetch).once
      -> { OccurrencesWorker.new(@params.merge('revision' => '10b04c1ed63bec207db6ebdf14d31d2a86006cb4')).perform }.should raise_error(/Unknown revision/)
    end

    context "[finding Deploys and revisions]" do
      it "should associate a Deploy if given a build" do
        env    = FactoryGirl.create(:environment, name: 'production', project: @project)
        deploy = FactoryGirl.create(:deploy, environment: env, build: '12345')
        occ    = OccurrencesWorker.new(@params.merge('build' => '12345')).perform
        occ.bug.deploy.should eql(deploy)
      end

      it "should create a new Deploy if one doesn't exist and a revision is given" do
        Deploy.delete_all
        occ = OccurrencesWorker.new(@params.merge('build' => 'new')).perform
        occ.bug.deploy.revision.should eql(@commit.sha)
        occ.bug.deploy.deployed_at.should be_within(5).of(Time.now)
        occ.bug.deploy.build.should eql('new')
      end

      it "should raise an error if the Deploy doesn't exist and no revision is given" do
        -> { OccurrencesWorker.new(@params.merge('build' => 'not-found', 'revision' => nil)).perform }.
            should raise_error(API::InvalidAttributesError)
      end
    end

    context "[attributes]" do
      it "should create an occurrence with the given attributes" do
        occ = OccurrencesWorker.new(@params).perform
        occ.should be_kind_of(Occurrence)

        occ.client.should eql('rails')
        occ.revision.should eql(@commit.sha)
        occ.message.should eql("Well crap")
        occ.faulted_backtrace.zip(@exception.backtrace).each do |(element), bt_line|
          next if bt_line.include?('.java') # we test the java portions of the backtrace elsewhere
          bt_line.include?("#{element['file']}:#{element['line']}").should be_true
          bt_line.end_with?(":in `#{element['method']}'").should(be_true) if element['method']
        end

        occ.bug.environment.name.should eql('production')
        occ.bug.client.should eql('rails')
        occ.bug.class_name.should eql("ArgumentError")
        occ.bug.file.should eql(THIS_FILE)
        occ.bug.line.should eql(@line)
        occ.bug.blamed_revision.should be_nil
        occ.bug.message_template.should eql("Well crap")
        occ.bug.revision.should eql(@commit.sha)
      end

      context "[PII filtering]" do
        it "should filter emails from the occurrence message" do
          @params['message'] = "Duplicate entry 'foo.2001@example.com' for key 'index_users_on_email'"
          occ                = OccurrencesWorker.new(@params).perform
          occ.message.should eql("Duplicate entry '[EMAIL?]' for key 'index_users_on_email'")
        end

        it "should filter phone numbers from the occurrence message" do
          @params['message'] = "My phone number is (206) 356-2754."
          occ                = OccurrencesWorker.new(@params).perform
          occ.message.should eql("My phone number is (206) [PHONE?].")
        end

        it "should filter credit card numbers from the occurrence message" do
          @params['message'] = "I bought this using my 4426-2480-0548-1000 card."
          occ                = OccurrencesWorker.new(@params).perform
          occ.message.should eql("I bought this using my [CC/BANK?] card.")
        end

        it "should filter bank account numbers from the occurrence message" do
          @params['message'] = "Please remit to 80054810."
          occ                = OccurrencesWorker.new(@params).perform
          occ.message.should eql("Please remit to [CC/BANK?].")
        end

        it "should not perform filtering if filtering is disabled" do
          @project.update_attribute :disable_message_filtering, true

          @params['message'] = "Please remit to 80054810."
          occ                = OccurrencesWorker.new(@params).perform
          occ.message.should eql("Please remit to 80054810.")

          @project.update_attribute :disable_message_filtering, false
        end
      end

      it "should stick any attributes it doesn't recognize into the metadata attribute" do
        occ = OccurrencesWorker.new(@params.merge('testfoo' => 'testbar')).perform
        JSON.parse(occ.metadata)['testfoo'].should eql('testbar')
      end

      it "should set user agent variables when a user agent is specified" do
        occ = OccurrencesWorker.new(@params.merge('headers' => {'HTTP_USER_AGENT' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/534.55.3 (KHTML, like Gecko) Version/5.1.5 Safari/534.55.3'})).perform
        occ.browser_name.should eql("Safari")
        occ.browser_version.should eql("5.1.5")
        occ.browser_engine.should eql("webkit")
        occ.browser_os.should eql("OS X 10.7")
        occ.browser_engine_version.should eql("534.55.3")
      end

      it "should remove the SQL query from a SQL error message" do
        msg = <<-ERR.strip
          Duplicate entry 'foo@bar.com' for key 'index_users_on_email': UPDATE `users` SET `name` = 'Sancho Sample', `crypted_password` = 'sughwgiuwgbajgw', `updated_at` = '2013-09-23 21:18:37', `email` = 'foo@bar.com' WHERE `id` = 26819622 -- app/controllers/api/v1/user_controller.rb:35
        ERR
        occ = OccurrencesWorker.new(@params.merge('class_name' => 'Mysql::Error', 'message' => msg)).perform
        JSON.parse(occ.metadata)['message'].should eql("Duplicate entry '[EMAIL?]' for key 'index_users_on_email'")
      end
    end

    context "[blame]" do
      it "should set the bug's blamed_revision when there's blame to be had" do
        occ = OccurrencesWorker.new(@params.merge('backtraces' => [{'name' => "Thread 0", 'faulted' => true, 'backtrace' => @valid_trace}])).perform
        occ.bug.blamed_revision.should eql('30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44')
      end

      it "should match an existing bug by file, line, and class name if no blame is available" do
        env = @project.environments.where(name: 'production').find_or_create!
        bug = FactoryGirl.create(:bug, environment: env, file: THIS_FILE, line: @line, class_name: 'ArgumentError')
        occ = OccurrencesWorker.new(@params).perform
        occ.bug.should eql(bug)
      end

      it "should match an existing bug by file, line, class name, and commit when there's blame to be had" do
        env = @project.environments.where(name: 'production').find_or_create!
        bug = FactoryGirl.create(:bug, environment: env, file: 'lib/better_caller/extensions.rb', line: 11, class_name: 'ArgumentError', blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44')
        occ = OccurrencesWorker.new(@params.merge('backtraces' => [{'name' => "Thread 0", 'faulted' => true, 'backtrace' => @valid_trace}])).perform
        occ.bug.should eql(bug)
      end

      it "should truncate the error message if it exceeds 1,000 characters" do
        occ = OccurrencesWorker.new(@params.merge('message' => 'a'*1005)).perform
        occ.bug.message_template.should eql('a'*997 + '...')
        occ.message.should eql('a'*997 + '...')
      end

      it "should use the full SHA1 of a revision if an abbreviated revision is specified" do
        occ = OccurrencesWorker.new(@params.merge('revision' => @commit.sha[0, 6])).perform
        occ.revision.should eql(@commit.sha)
      end
    end

    context "[distributed projects]" do
      it "should create a new bug if the occurrence is associated with a different deploy" do
        env = @project.environments.where(name: 'production').find_or_create!
        r1  = @project.repo.object('HEAD^^^').sha
        r2  = @project.repo.object('HEAD^^').sha
        r3  = @project.repo.object('HEAD^').sha
        r4  = @project.repo.object('HEAD').sha
        Bug.destroy_all

        # alright, turn your brains up to maximum people
        # O = occurrence, R = Git revision, D = deploy

        # D1 is deployed with a bug
        d1  = FactoryGirl.create(:deploy, environment: env, revision: r1, build: 'D1')

        # O1 occurs on R1/D1
        o1  = OccurrencesWorker.new(@params.merge('build' => 'D1')).perform
        # Bug should start out open and be associated with d1
        bug = o1.bug
        bug.should_not be_fixed
        bug.should_not be_fix_deployed
        bug.deploy.should eql(d1)

        # R2 is committed and released with D2 (it does not fix the bug)
        d2 = FactoryGirl.create(:deploy, environment: env, revision: r2, build: 'D2')
        # O2 occurs
        o2 = OccurrencesWorker.new(@params.merge('build' => 'D2')).perform
        # Occurrence should be associated with the original bug;
        # Bug should still be open
        o2.bug_id.should eql(bug.id)
        bug.reload.should_not be_fixed
        bug.should_not be_fix_deployed
        # Bug's deploy should be "upgraded"' to D2
        bug.deploy.should eql(d2)

        # R3 is committed (it fixes the bug), but not deployed. Bug is marked as fixed
        bug.update_attributes fixed: true, resolution_revision: r3
        # O3 occurs on a device running R2/D2 (ok nerds, calm down)
        o3 = OccurrencesWorker.new(@params.merge('build' => 'D2')).perform
        # Bug should still be marked as fixed
        o3.bug_id.should eql(bug.id)
        bug.reload.should be_fixed
        bug.should_not be_fix_deployed
        bug.deploy.should eql(d2)

        # R4/D3 (including R3) is released, some devices upgrade.
        d3 = FactoryGirl.create(:deploy, environment: env, revision: r4, build: 'D3')
        # The bug is marked as fix_deployed
        DeployFixMarker.perform(d3.id)
        bug.reload.should be_fix_deployed
        # O4 occurs on a machine still running R2/D2
        o4 = OccurrencesWorker.new(@params.merge('build' => 'D2')).perform
        # Bug should still be marked as fixed
        o4.bug_id.should eql(bug.id)
        bug.reload.should be_fixed
        bug.should be_fix_deployed

        # O5 occurs on a device running R4/D3
        o5 = OccurrencesWorker.new(@params.merge('build' => 'D3')).perform
        # The occurrence should have itself a new bug
        o5.bug_id.should_not eql(bug.id)
        bug.reload.should be_fixed
        bug.should be_fix_deployed
        o5.bug.should_not be_fixed
        o5.bug.should_not be_fix_deployed
      end
    end

    context "[hosted projects]" do
      it "should reopen a bug only at the proper times" do
        env = @project.environments.where(name: 'production').find_or_create!
        r1  = @project.repo.object('HEAD^^^').sha
        r2  = @project.repo.object('HEAD^^').sha
        r3  = @project.repo.object('HEAD^').sha
        r4  = @project.repo.object('HEAD').sha
        Bug.destroy_all

        # here we go again...
        # O = occurrence, R = Git revision

        # O1 occurs on R1
        o1  = OccurrencesWorker.new(@params.merge('revision' => r1)).perform
                                 # Bug should start out open
        bug = o1.bug
        bug.should_not be_fixed
        bug.should_not be_fix_deployed
        bug.deploy.should be_nil # not a distributed project

        # R2 is committed and deployed (it does not fix the bug)
        FactoryGirl.create(:deploy, environment: env, revision: r2)
        # O2 occurs
        o2 = OccurrencesWorker.new(@params.merge('revision' => r2)).perform
        # Bug should still be open
        o2.bug_id.should eql(bug.id)
        bug.reload.should_not be_fixed
        bug.should_not be_fix_deployed

        # R3 is committed (it fixes the bug), but not deployed. Bug is marked as fixed
        bug.update_attributes fixed: true, resolution_revision: r3
        # O3 occurs on a server running R2
        o3 = OccurrencesWorker.new(@params.merge('revision' => r2)).perform
        # Bug should still be marked as fixed
        o3.bug_id.should eql(bug.id)
        bug.reload.should be_fixed
        bug.should_not be_fix_deployed

        # R4 (including R3) is deployed to some machines.
        d = FactoryGirl.create(:deploy, environment: env, revision: r4)
        # The bug is marked as fix_deployed
        DeployFixMarker.perform(d.id)
        bug.reload.should be_fix_deployed
        # O4 occurs on a machine still running R2
        o4 = OccurrencesWorker.new(@params.merge('revision' => r2)).perform
        # Bug should still be marked as fixed
        o4.bug_id.should eql(bug.id)
        bug.reload.should be_fixed
        bug.should be_fix_deployed

        # R4 is now deployed to all machines
        d = FactoryGirl.create(:deploy, environment: env, revision: r4)
        DeployFixMarker.perform(d.id)
        bug.reload.should be_fix_deployed
        # O5 occurs on a machine running R4
        o5 = OccurrencesWorker.new(@params.merge('revision' => r4)).perform
        # The bug should be reopened
        o5.bug_id.should eql(bug.id)
        bug.reload.should_not be_fixed
        bug.should_not be_fix_deployed
      end

      it "should reopen an existing bug that is fixed, not deployed, and stale" do
        env = @project.environments.where(name: 'production').find_or_create!
        bug = FactoryGirl.create(:bug, environment: env, file: THIS_FILE, line: @line, class_name: 'ArgumentError', fixed: true)
        bug.update_attribute :fixed_at, Time.now - 15.days
        OccurrencesWorker.new(@params).perform
        bug.reload.should_not be_fixed
        bug.fix_deployed?.should be_false
      end

      it "should set a cause for a bug being reopened" do
        Deploy.delete_all
        env = @project.environments.where(name: 'production').find_or_create!
        bug = FactoryGirl.create(:bug, environment: env, file: THIS_FILE, line: @line, class_name: 'ArgumentError', fixed: true, fix_deployed: true)
        bug.events.delete_all

        occ = OccurrencesWorker.new(@params).perform

        bug.events(true).count.should eql(1)
        bug.events.first.kind.should eql('reopen')
        bug.events.first.data['occurrence_id'].should eql(occ.id)
      end
    end
  end
end
