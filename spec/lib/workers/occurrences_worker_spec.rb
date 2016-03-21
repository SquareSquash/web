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

require 'rails_helper'

THIS_FILE = Pathname.new(__FILE__).relative_path_from(Rails.root).to_s

RSpec.describe OccurrencesWorker do
  before :all do
    Project.where(repository_url: 'https://github.com/RISCfuture/better_caller.git').delete_all
    @project   = FactoryGirl.create(:project, repository_url: 'https://github.com/RISCfuture/better_caller.git')
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
        expect { OccurrencesWorker.new @params.except(key) }.to raise_error(API::InvalidAttributesError)
        expect { OccurrencesWorker.new @params.merge(key => ' ') }.to raise_error(API::InvalidAttributesError)
      end
    end

    it "should raise an error if the API key is invalid" do
      expect { OccurrencesWorker.new @params.merge('api_key' => 'not-found') }.to raise_error(API::UnknownAPIKeyError)
    end

    it "should create a new environment if one doesn't exist with that name" do
      @project.environments.delete_all
      OccurrencesWorker.new(@params).perform
      expect(@project.environments.pluck(:name)).to eql(%w( production ))
    end
  end

  describe "#perform" do
    it "attempt to git-fetch if the revision doesn't exist, then skip it if the revision STILL doesn't exist" do
      allow(Project).to receive(:find_by_api_key!).and_return(@project)
      expect(@project.repo).to receive(:fetch).once
      expect { OccurrencesWorker.new(@params.merge('revision' => '10b04c1ed63bec207db6ebdf14d31d2a86006cb4')).perform }.to raise_error(/Unknown revision/)
    end

    context "[finding Deploys and revisions]" do
      it "should associate a Deploy if given a build" do
        env    = FactoryGirl.create(:environment, name: 'production', project: @project)
        deploy = FactoryGirl.create(:deploy, environment: env, build: '12345')
        occ    = OccurrencesWorker.new(@params.merge('build' => '12345')).perform
        expect(occ.bug.deploy).to eql(deploy)
      end

      it "should create a new Deploy if one doesn't exist and a revision is given" do
        Deploy.delete_all
        occ = OccurrencesWorker.new(@params.merge('build' => 'new')).perform
        expect(occ.bug.deploy.revision).to eql(@commit.sha)
        expect(occ.bug.deploy.deployed_at).to be_within(1.minute).of(Time.now)
        expect(occ.bug.deploy.build).to eql('new')
      end

      it "should raise an error if the Deploy doesn't exist and no revision is given" do
        expect { OccurrencesWorker.new(@params.merge('build' => 'not-found', 'revision' => nil)).perform }.
            to raise_error(API::InvalidAttributesError)
      end
    end

    context "[attributes]" do
      it "works for js:hosted types" do
        js_params = @params.merge({
                                      "client"         => "javascript",
                                      "class_name"     => "ReferenceError",
                                      "message"        => "foo is not defined",
                                      "backtraces"     => [
                                          {
                                              "name"      => "Active Thread",
                                              "faulted"   => true,
                                              "backtrace" => [
                                                  {
                                                      "url"     => "http://localhost:3000/assets/vendor.js",
                                                      "line"    => 11671,
                                                      "symbol"  => "?",
                                                      "context" => nil,
                                                      "type"    => "js:hosted"
                                                  }
                                              ]
                                          }
                                      ],
                                      "capture_method" => "onerror",
                                      "occurred_at"    => "2014-05-26T22:43:31Z",
                                      "schema"         => "http",
                                      "host"           => "localhost",
                                      "port"           => "3000",
                                      "path"           => "/admin",
                                      "query"          => "",
                                      "user_agent"     => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:28.0) Gecko/20100101 Firefox/28.0",
                                      "screen_width"   => 1920,
                                      "screen_height"  => 1200,
                                      "window_width"   => 1870,
                                      "window_height"  => 767,
                                      "color_depth"    => 24
                                  })

        occ = OccurrencesWorker.new(js_params).perform
        expect(occ).to be_kind_of(Occurrence)

        expect(occ.client).to eql('javascript')
        expect(occ.bug.environment.name).to eql('production')
        expect(occ.bug.client).to eql('javascript')
      end

      it "should create an occurrence with the given attributes" do
        occ = OccurrencesWorker.new(@params).perform
        expect(occ).to be_kind_of(Occurrence)

        expect(occ.client).to eql('rails')
        expect(occ.revision).to eql(@commit.sha)
        expect(occ.message).to eql("Well crap")
        occ.faulted_backtrace.zip(@exception.backtrace).each do |(element), bt_line|
          next if bt_line.include?('.java') # we test the java portions of the backtrace elsewhere
          expect(bt_line.include?("#{element['file']}:#{element['line']}")).to eql(true)
          expect(bt_line.end_with?(":in `#{element['method']}'")).to(eql(true)) if element['method']
        end

        expect(occ.bug.environment.name).to eql('production')
        expect(occ.bug.client).to eql('rails')
        expect(occ.bug.class_name).to eql("ArgumentError")
        expect(occ.bug.file).to eql(THIS_FILE)
        expect(occ.bug.line).to eql(@line)
        expect(occ.bug.blamed_revision).to be_nil
        expect(occ.bug.message_template).to eql("Well crap")
        expect(occ.bug.revision).to eql(@commit.sha)
      end

      context "[PII filtering]" do
        it "should filter emails from the occurrence message" do
          @params['message'] = "Duplicate entry 'foo.2001@example.com' for key 'index_users_on_email'"
          occ                = OccurrencesWorker.new(@params).perform
          expect(occ.message).to eql("Duplicate entry '[EMAIL?]' for key 'index_users_on_email'")
        end

        it "should filter phone numbers from the occurrence message" do
          @params['message'] = "My phone number is (206) 356-2754."
          occ                = OccurrencesWorker.new(@params).perform
          expect(occ.message).to eql("My phone number is (206) [PHONE?].")
        end

        it "should filter credit card numbers from the occurrence message" do
          @params['message'] = "I bought this using my 4426-2480-0548-1000 card."
          occ                = OccurrencesWorker.new(@params).perform
          expect(occ.message).to eql("I bought this using my [CC/BANK?] card.")
        end

        it "should filter bank account numbers from the occurrence message" do
          @params['message'] = "Please remit to 80054810."
          occ                = OccurrencesWorker.new(@params).perform
          expect(occ.message).to eql("Please remit to [CC/BANK?].")
        end

        it "should not perform filtering if filtering is disabled" do
          @project.update_attribute :disable_message_filtering, true

          @params['message'] = "Please remit to 80054810."
          occ                = OccurrencesWorker.new(@params).perform
          expect(occ.message).to eql("Please remit to 80054810.")

          @project.update_attribute :disable_message_filtering, false
        end

        it "should filter PII from the query" do
          @params['query'] = 'email=foo@bar.com&name=Tim'
          occ              = OccurrencesWorker.new(@params).perform
          expect(occ.query).to eql('email=[EMAIL?]&name=Tim')
        end

        it "should filter PII from the fragment" do
          @params['fragment'] = 'email=foo@bar.com&name=Tim'
          occ                 = OccurrencesWorker.new(@params).perform
          expect(occ.fragment).to eql('email=[EMAIL?]&name=Tim')
        end

        it "should filter PII from the parent_exceptions' messages and instance variables" do
          @params['parent_exceptions'] = [{"class_name"  => "ActiveRecord::RecordNotUnique",
                                           "message"     =>
                                               "Mysql2::Error: Duplicate entry 'test@foobar.com' for key 'index_guest_visitors_on_email': UPDATE `guest_visitors` SET `email` = 'test@foobar.com' WHERE `guest_visitors`.`id` = 77870 /* engines/guest/app/controllers/guest/groups_controller.rb:155:in `update' */",
                                           "backtraces"  =>
                                               [{"name"      => "Active Thread/Fiber",
                                                 "faulted"   => true,
                                                 "backtrace" =>
                                                     [{"file"   =>
                                                           "/app/go/shared/bundle/ruby/2.2.0/gems/mysql2-0.4.1/lib/mysql2/client.rb",
                                                       "line"   => 85,
                                                       "symbol" => "_query"},
                                                      {"file"   =>
                                                           "/app/go/shared/bundle/ruby/2.2.0/gems/mysql2-0.4.1/lib/mysql2/client.rb",
                                                       "line"   => 85,
                                                       "symbol" => "block in query"}]}],
                                           "association" => "original_exception",
                                           "ivars"       =>
                                               {"original_exception"          =>
                                                    {"language"   => "ruby",
                                                     "class_name" => "Mysql2::Error",
                                                     "inspect"    =>
                                                         "#<Mysql2::Error: Duplicate entry 'test@foobar.com' for key 'index_guest_visitors_on_email'>",
                                                     "yaml"       =>
                                                         "--- !ruby/exception:Mysql2::Error\nmessage: Duplicate entry 'test@foobar.com' for key 'index_guest_visitors_on_email'\nserver_version: 50626\nerror_number: 1062\nsql_state: '23000'\n",
                                                     "json"       =>
                                                         "{\"server_version\":50626,\"error_number\":1062,\"sql_state\":\"test@foobar.com\"}",
                                                     "to_s"       =>
                                                         "Duplicate entry 'test@foobar.com' for key 'index_guest_visitors_on_email'"},
                                                "_squash_controller_notified" => true}}]
          occ                          = OccurrencesWorker.new(@params).perform
          expect(occ.parent_exceptions.first['message']).to eql("Mysql2::Error: Duplicate entry '[EMAIL?]' for key 'index_guest_visitors_on_email': UPDATE `guest_visitors` SET `email` = '[EMAIL?]' WHERE `guest_visitors`.`id` = 77870 /* engines/guest/app/controllers/guest/groups_controller.rb:155:in `update' */")
          expect(occ.parent_exceptions.first['ivars']['original_exception']['inspect']).to eql("#<Mysql2::Error: Duplicate entry '[EMAIL?]' for key 'index_guest_visitors_on_email'>")
          expect(occ.parent_exceptions.first['ivars']['original_exception']['yaml']).to eql("--- !ruby/exception:Mysql2::Error\nmessage: Duplicate entry '[EMAIL?]' for key 'index_guest_visitors_on_email'\nserver_version: 50626\nerror_number: 1062\nsql_state: '23000'\n")
          expect(occ.parent_exceptions.first['ivars']['original_exception']['json']).to eql("{\"server_version\":50626,\"error_number\":1062,\"sql_state\":\"[EMAIL?]\"}")
          expect(occ.parent_exceptions.first['ivars']['original_exception']['to_s']).to eql("Duplicate entry '[EMAIL?]' for key 'index_guest_visitors_on_email'")
        end

        it "should filter PII from the session" do
          @params['session'] = {"email" => "test@foobar.com",
                                "other" => "something"}
          occ                = OccurrencesWorker.new(@params).perform
          expect(occ.session['email']).to eql('[EMAIL?]')
        end

        it "should filter PII from the headers" do
          @params['headers'] = {"email" => "test@foobar.com",
                                "other" => "something"}
          occ                = OccurrencesWorker.new(@params).perform
          expect(occ.headers['email']).to eql('[EMAIL?]')
        end

        it "should filter PII from the flash" do
          @params['flash'] = {"email" => "test@foobar.com",
                              "other" => "something"}
          occ              = OccurrencesWorker.new(@params).perform
          expect(occ.flash['email']).to eql('[EMAIL?]')
        end

        it "should filter PII from the params" do
          @params['params'] = {"email" => "test@foobar.com",
                               "other" => "something"}
          occ               = OccurrencesWorker.new(@params).perform
          expect(occ.params['email']).to eql('[EMAIL?]')
        end

        it "should filter PII from the cookies" do
          @params['cookies'] = {"email" => "test@foobar.com",
                                "other" => "something"}
          occ                = OccurrencesWorker.new(@params).perform
          expect(occ.cookies['email']).to eql('[EMAIL?]')
        end

        it "should filter PII from the ivars" do
          @params['ivars'] = {"email" => "test@foobar.com",
                              "other" => "something"}
          occ              = OccurrencesWorker.new(@params).perform
          expect(occ.ivars['email']).to eql('[EMAIL?]')
        end
      end

      it "should stick any attributes it doesn't recognize into the metadata attribute" do
        occ = OccurrencesWorker.new(@params.merge('testfoo' => 'testbar')).perform
        expect(JSON.parse(occ.metadata)['testfoo']).to eql('testbar')
      end

      it "should set user agent variables when a user agent is specified" do
        occ = OccurrencesWorker.new(@params.merge('headers' => {'HTTP_USER_AGENT' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/534.55.3 (KHTML, like Gecko) Version/5.1.5 Safari/534.55.3'})).perform
        expect(occ.browser_name).to eql("Safari")
        expect(occ.browser_version).to eql("5.1.5")
        expect(occ.browser_engine).to eql("webkit")
        expect(occ.browser_os).to eql("OS X 10.7")
        expect(occ.browser_engine_version).to eql("534.55.3")
      end

      it "should remove the SQL query from a SQL error message" do
        msg = <<-ERR.strip
          Duplicate entry 'foo@bar.com' for key 'index_users_on_email': UPDATE `users` SET `name` = 'Sancho Sample', `crypted_password` = 'sughwgiuwgbajgw', `updated_at` = '2013-09-23 21:18:37', `email` = 'foo@bar.com' WHERE `id` = 26819622 -- app/controllers/api/v1/user_controller.rb:35
        ERR
        occ = OccurrencesWorker.new(@params.merge('class_name' => 'Mysql::Error', 'message' => msg)).perform
        expect(JSON.parse(occ.metadata)['message']).to eql("Duplicate entry '[EMAIL?]' for key 'index_users_on_email'")
      end
    end

    context "[blame]" do
      it "should set the bug's blamed_revision when there's blame to be had" do
        occ = OccurrencesWorker.new(@params.merge('backtraces' => [{'name' => "Thread 0", 'faulted' => true, 'backtrace' => @valid_trace}])).perform
        expect(occ.bug.blamed_revision).to eql('30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44')
      end

      it "should match an existing bug by file, line, and class name if no blame is available" do
        env = @project.environments.where(name: 'production').find_or_create!
        bug = FactoryGirl.create(:bug, environment: env, file: THIS_FILE, line: @line, class_name: 'ArgumentError')
        occ = OccurrencesWorker.new(@params).perform
        expect(occ.bug).to eql(bug)
      end

      it "should match an existing bug by file, line, class name, and commit when there's blame to be had" do
        env = @project.environments.where(name: 'production').find_or_create!
        bug = FactoryGirl.create(:bug, environment: env, file: 'lib/better_caller/extensions.rb', line: 11, class_name: 'ArgumentError', blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44')
        occ = OccurrencesWorker.new(@params.merge('backtraces' => [{'name' => "Thread 0", 'faulted' => true, 'backtrace' => @valid_trace}])).perform
        expect(occ.bug).to eql(bug)
      end

      it "should truncate the error message if it exceeds 1,000 characters" do
        occ = OccurrencesWorker.new(@params.merge('message' => 'a'*1005)).perform
        expect(occ.bug.message_template).to eql('a'*997 + '...')
        expect(occ.message).to eql('a'*997 + '...')
      end

      it "should use the full SHA1 of a revision if an abbreviated revision is specified" do
        occ = OccurrencesWorker.new(@params.merge('revision' => @commit.sha[0, 6])).perform
        expect(occ.revision).to eql(@commit.sha)
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
        expect(bug).not_to be_fixed
        expect(bug).not_to be_fix_deployed
        expect(bug.deploy).to eql(d1)

        # R2 is committed and released with D2 (it does not fix the bug)
        d2 = FactoryGirl.create(:deploy, environment: env, revision: r2, build: 'D2')
        # O2 occurs
        o2 = OccurrencesWorker.new(@params.merge('build' => 'D2')).perform
        # Occurrence should be associated with the original bug;
        # Bug should still be open
        expect(o2.bug_id).to eql(bug.id)
        expect(bug.reload).not_to be_fixed
        expect(bug).not_to be_fix_deployed
        # Bug's deploy should be "upgraded"' to D2
        expect(bug.deploy).to eql(d2)

        # R3 is committed (it fixes the bug), but not deployed. Bug is marked as fixed
        bug.update_attributes fixed: true, resolution_revision: r3
        # O3 occurs on a device running R2/D2 (ok nerds, calm down)
        o3 = OccurrencesWorker.new(@params.merge('build' => 'D2')).perform
        # Bug should still be marked as fixed
        expect(o3.bug_id).to eql(bug.id)
        expect(bug.reload).to be_fixed
        expect(bug).not_to be_fix_deployed
        expect(bug.deploy).to eql(d2)

        # R4/D3 (including R3) is released, some devices upgrade.
        d3 = FactoryGirl.create(:deploy, environment: env, revision: r4, build: 'D3')
        # The bug is marked as fix_deployed
        DeployFixMarker.perform(d3.id)
        expect(bug.reload).to be_fix_deployed
        # O4 occurs on a machine still running R2/D2
        o4 = OccurrencesWorker.new(@params.merge('build' => 'D2')).perform
        # Bug should still be marked as fixed
        expect(o4.bug_id).to eql(bug.id)
        expect(bug.reload).to be_fixed
        expect(bug).to be_fix_deployed

        # O5 occurs on a device running R4/D3
        o5 = OccurrencesWorker.new(@params.merge('build' => 'D3')).perform
        # The occurrence should have itself a new bug
        expect(o5.bug_id).not_to eql(bug.id)
        expect(bug.reload).to be_fixed
        expect(bug).to be_fix_deployed
        expect(o5.bug).not_to be_fixed
        expect(o5.bug).not_to be_fix_deployed
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
        expect(bug).not_to be_fixed
        expect(bug).not_to be_fix_deployed
        expect(bug.deploy).to be_nil # not a distributed project

        # R2 is committed and deployed (it does not fix the bug)
        FactoryGirl.create(:deploy, environment: env, revision: r2)
        # O2 occurs
        o2 = OccurrencesWorker.new(@params.merge('revision' => r2)).perform
        # Bug should still be open
        expect(o2.bug_id).to eql(bug.id)
        expect(bug.reload).not_to be_fixed
        expect(bug).not_to be_fix_deployed

        # R3 is committed (it fixes the bug), but not deployed. Bug is marked as fixed
        bug.update_attributes fixed: true, resolution_revision: r3
        # O3 occurs on a server running R2
        o3 = OccurrencesWorker.new(@params.merge('revision' => r2)).perform
        # Bug should still be marked as fixed
        expect(o3.bug_id).to eql(bug.id)
        expect(bug.reload).to be_fixed
        expect(bug).not_to be_fix_deployed

        # R4 (including R3) is deployed to some machines.
        d = FactoryGirl.create(:deploy, environment: env, revision: r4)
        # The bug is marked as fix_deployed
        DeployFixMarker.perform(d.id)
        expect(bug.reload).to be_fix_deployed
        # O4 occurs on a machine still running R2
        o4 = OccurrencesWorker.new(@params.merge('revision' => r2)).perform
        # Bug should still be marked as fixed
        expect(o4.bug_id).to eql(bug.id)
        expect(bug.reload).to be_fixed
        expect(bug).to be_fix_deployed

        # R4 is now deployed to all machines
        d = FactoryGirl.create(:deploy, environment: env, revision: r4)
        DeployFixMarker.perform(d.id)
        expect(bug.reload).to be_fix_deployed
        # O5 occurs on a machine running R4
        o5 = OccurrencesWorker.new(@params.merge('revision' => r4)).perform
        # The bug should be reopened
        expect(o5.bug_id).to eql(bug.id)
        expect(bug.reload).not_to be_fixed
        expect(bug).not_to be_fix_deployed
      end

      it "should reopen an existing bug that is fixed, not deployed, and stale" do
        env = @project.environments.where(name: 'production').find_or_create!
        bug = FactoryGirl.create(:bug, environment: env, file: THIS_FILE, line: @line, class_name: 'ArgumentError', fixed: true)
        bug.update_attribute :fixed_at, Time.now - 15.days
        OccurrencesWorker.new(@params).perform
        expect(bug.reload).not_to be_fixed
        expect(bug.fix_deployed?).to eql(false)
      end

      it "should set a cause for a bug being reopened" do
        Deploy.delete_all
        env = @project.environments.where(name: 'production').find_or_create!
        bug = FactoryGirl.create(:bug, environment: env, file: THIS_FILE, line: @line, class_name: 'ArgumentError', fixed: true, fix_deployed: true)
        bug.events.delete_all

        occ = OccurrencesWorker.new(@params).perform

        expect(bug.events(true).count).to eql(1)
        expect(bug.events.first.kind).to eql('reopen')
        expect(bug.events.first.data['occurrence_id']).to eql(occ.id)
      end
    end
  end
end
