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

RSpec.describe Occurrence, type: :model do
  context "[database rules]" do
    it "should set number sequentially for a given bug" do
      bug1 = FactoryGirl.create(:bug)
      bug2 = FactoryGirl.create(:bug)

      occurrence1_1 = FactoryGirl.create(:rails_occurrence, bug: bug1)
      occurrence1_2 = FactoryGirl.create(:rails_occurrence, bug: bug1)
      occurrence2_1 = FactoryGirl.create(:rails_occurrence, bug: bug2)
      occurrence2_2 = FactoryGirl.create(:rails_occurrence, bug: bug2)

      expect(occurrence1_1.number).to eql(1)
      expect(occurrence1_2.number).to eql(2)
      expect(occurrence2_1.number).to eql(1)
      expect(occurrence2_2.number).to eql(2)
    end

    it "should not reuse deleted numbers" do
      #bug = FactoryGirl.create(:bug)
      #FactoryGirl.create :rails_occurrence, bug: bug
      #FactoryGirl.create(:rails_occurrence, bug: bug).destroy
      #FactoryGirl.create(:rails_occurrence, bug: bug).number.should eql(3)
      #TODO get this part of the spec to work (for URL-resource identity integrity)

      bug = FactoryGirl.create(:bug)
      FactoryGirl.create :rails_occurrence, bug: bug
      c = FactoryGirl.create(:rails_occurrence, bug: bug)
      FactoryGirl.create :rails_occurrence, bug: bug
      c.destroy
      expect(FactoryGirl.create(:rails_occurrence, bug: bug).number).to eql(4)
    end

    it "should set the parent's first occurrence if necessary" do
      o = FactoryGirl.create(:rails_occurrence)
      expect(o.bug.first_occurrence).to eql(o.occurred_at)
    end
  end

  context "[hooks]" do
    it "should symbolicate after being created" do
      symbols = Squash::Symbolicator::Symbols.new
      symbols.add 1, 10, 'foo.rb', 5, 'bar'
      symb = FactoryGirl.create(:symbolication, symbols: symbols)
      expect(FactoryGirl.create(:rails_occurrence,
                                symbolication: symb,
                                backtraces:    [{"name"      => "1",
                                                 "faulted"   => true,
                                                 "backtrace" => [{"type"    => "address",
                                                                  "address" => 5}]}])).
          to be_symbolicated
    end

    it "should send an email if the notification threshold has been tripped" do
      if RSpec.configuration.use_transactional_fixtures
        skip "This is done in an after_commit hook, and it can't be tested with transactional fixtures (which are always rolled back)"
      end

      occurrence = FactoryGirl.create(:rails_occurrence)
      nt         = FactoryGirl.create(:notification_threshold, bug: occurrence.bug, period: 1.minute, threshold: 3)
      ActionMailer::Base.deliveries.clear

      FactoryGirl.create :rails_occurrence, bug: occurrence.bug
      expect(ActionMailer::Base.deliveries).to be_empty

      FactoryGirl.create :rails_occurrence, bug: occurrence.bug
      expect(ActionMailer::Base.deliveries.size).to eql(1)
      expect(ActionMailer::Base.deliveries.first.to).to eql([nt.user.email])
    end

    it "should update last_tripped_at" do
      if RSpec.configuration.use_transactional_fixtures
        skip "This is done in an after_commit hook, and it can't be tested with transactional fixtures (which are always rolled back)"
      end

      occurrence = FactoryGirl.create(:rails_occurrence)
      nt         = FactoryGirl.create(:notification_threshold, bug: occurrence.bug, period: 1.minute, threshold: 3)

      FactoryGirl.create :rails_occurrence, bug: occurrence.bug
      expect(nt.reload.last_tripped_at).to be_nil

      FactoryGirl.create :rails_occurrence, bug: occurrence.bug
      expect(nt.reload.last_tripped_at).to be_within(1).of(Time.now)
    end

    context "[PagerDuty integration]" do
      before :each do
        FakeWeb.register_uri :post,
                             Squash::Configuration.pagerduty.api_url,
                             response: File.read(Rails.root.join('spec', 'fixtures', 'pagerduty_response.json'))

        @project     = FactoryGirl.create(:project, pagerduty_service_key: 'abc123', critical_threshold: 2, pagerduty_enabled: true)
        @environment = FactoryGirl.create(:environment, project: @project, notifies_pagerduty: true)
        @bug         = FactoryGirl.create(:bug, environment: @environment)
      end

      context "[critical threshold notification]" do
        it "should not send an incident to PagerDuty until the critical threshold is breached" do
          expect_any_instance_of(Service::PagerDuty).not_to receive :trigger
          FactoryGirl.create_list :rails_occurrence, 2, bug: @bug
        end

        it "should send an incident if always_notify_pagerduty is set" do
          @project.update_attribute :always_notify_pagerduty, true
          expect_any_instance_of(Service::PagerDuty).to receive(:trigger).once.with(
              /#{Regexp.escape @bug.class_name} in #{Regexp.escape File.basename(@bug.file)}:#{@bug.line}/,
              @bug.pagerduty_incident_key,
              an_instance_of(Hash)
          )
          FactoryGirl.create :rails_occurrence, bug: @bug
        end

        it "should send an incident to PagerDuty once the critical threshold is breached" do
          FactoryGirl.create_list :rails_occurrence, 2, bug: @bug
          expect_any_instance_of(Service::PagerDuty).to receive(:trigger).once.with(
              /#{Regexp.escape @bug.class_name} in #{Regexp.escape File.basename(@bug.file)}:#{@bug.line}/,
              @bug.pagerduty_incident_key,
              an_instance_of(Hash)
          )
          FactoryGirl.create :rails_occurrence, bug: @bug
        end

        it "should not send an incident if the project does not have a session key configured" do
          @project.update_attribute :pagerduty_service_key, nil

          expect_any_instance_of(Service::PagerDuty).not_to receive :trigger
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end

        it "should not send an incident if incident reporting is disabled" do
          @project.update_attribute :pagerduty_enabled, false

          expect_any_instance_of(Service::PagerDuty).not_to receive :trigger
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end

        it "should not send an incident if the environment has incident reporting disabled" do
          @environment.update_attribute :notifies_pagerduty, nil

          expect_any_instance_of(Service::PagerDuty).not_to receive :trigger
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end

        it "should not send an incident if the bug is assigned" do
          @bug.update_attribute :assigned_user, FactoryGirl.create(:membership, project: @project).user

          expect_any_instance_of(Service::PagerDuty).not_to receive :trigger
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end

        it "should not send an incident if the bug is irrelevant" do
          @bug.update_attribute :irrelevant, true

          expect_any_instance_of(Service::PagerDuty).not_to receive :trigger
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end
      end

      context "[paging threshold notification]" do
        before :each do
          @project.update_attribute :critical_threshold, 200
          @bug.update_attributes page_threshold: 2, page_period: 1.minute
        end

        it "should send an incident to PagerDuty once if the page threshold is breached" do
          expect_any_instance_of(Service::PagerDuty).to receive(:trigger).once.with(
              /#{Regexp.escape @bug.class_name} in #{Regexp.escape File.basename(@bug.file)}:#{@bug.line}/,
              @bug.pagerduty_incident_key,
              an_instance_of(Hash)
          )
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end

        it "should not send an incident to PagerDuty if the page threshold is breached again inside the page period" do
          @bug.update_attributes page_last_tripped_at: 30.seconds.ago
          expect_any_instance_of(Service::PagerDuty).not_to receive(:trigger)
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end

        it "should send an incident to PagerDuty if the page threshold is breached again outside the page period" do
          @bug.update_attributes page_last_tripped_at: 2.minutes.ago
          expect_any_instance_of(Service::PagerDuty).to receive(:trigger).once
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end

        it "should not send an incident if the project does not have a session key configured" do
          @project.update_attribute :pagerduty_service_key, nil

          expect_any_instance_of(Service::PagerDuty).not_to receive :trigger
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end

        it "should not send an incident if incident reporting is disabled" do
          @project.update_attribute :pagerduty_enabled, false

          expect_any_instance_of(Service::PagerDuty).not_to receive :trigger
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end

        it "should not send an incident if the environment has incident reporting disabled" do
          @environment.update_attribute :notifies_pagerduty, nil

          expect_any_instance_of(Service::PagerDuty).not_to receive :trigger
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end

        it "should not an incident if the bug is assigned" do
          @bug.update_attribute :assigned_user, FactoryGirl.create(:membership, project: @project).user

          expect_any_instance_of(Service::PagerDuty).to receive(:trigger).once
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end

        it "should not an incident if the bug is irrelevant" do
          @bug.update_attribute :irrelevant, true

          expect_any_instance_of(Service::PagerDuty).to receive(:trigger).once
          FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        end
      end
    end unless Squash::Configuration.pagerduty.disabled?

    context "[setting any_occurrence_crashed]" do
      it "should set any_occurrence_crashed to true if crashed is true" do
        bug = FactoryGirl.create(:bug)
        expect {
          FactoryGirl.create(:rails_occurrence, bug: bug, crashed: true)
        }.to change { bug.reload.any_occurrence_crashed }.from(false).to(true)
      end

      it "should not change any_occurrence_crashed if crashed is false" do
        bug = FactoryGirl.create(:bug)
        expect {
          FactoryGirl.create(:rails_occurrence, bug: bug, crashed: false)
        }.to_not change { bug.reload.any_occurrence_crashed }
      end
    end

    context "[device bugs]" do
      it "should create a device bug if the occurrence has a device" do
        bug = FactoryGirl.create(:bug)

        occurrence = FactoryGirl.create(:rails_occurrence, bug: bug, device_id: 'hello')
        expect(occurrence.bug.device_bugs.where(device_id: 'hello')).to exist
        expect {
          FactoryGirl.create(:rails_occurrence, bug: bug, device_id: 'hello')
        }.to_not change { bug.device_bugs.where(device_id: 'hello').count }

        occurrence = FactoryGirl.create(:rails_occurrence, bug: bug, device_id: 'goodbye')
        expect(occurrence.bug.device_bugs.where(device_id: 'goodbye')).to exist
      end
    end
  end

  describe "#faulted_backtrace" do
    it "should return the at-fault backtrace" do
      bt1 = [{'file' => 'foo.rb', 'line' => 123, 'symbol' => 'bar'}]
      bt2 = [{'file' => 'bar.rb', 'line' => 321, 'symbol' => 'foo'}]
      expect(FactoryGirl.build(:occurrence, backtraces: [{'name' => "1", 'faulted' => false, 'backtrace' => bt1},
                                                         {'name' => '2', 'faulted' => true, 'backtrace' => bt2}]).
          faulted_backtrace).to eql(bt2)
    end

    it "should return an empty array if there is no at-fault backtrace" do
      bt1 = [{'file' => 'foo.rb', 'line' => 123, 'symbol' => 'bar'}]
      bt2 = [{'file' => 'bar.rb', 'line' => 321, 'symbol' => 'foo'}]
      expect(FactoryGirl.build(:occurrence, backtraces: [{'name' => "1", 'faulted' => false, 'backtrace' => bt1},
                                                         {'name' => '2', 'faulted' => false, 'backtrace' => bt2}]).
          faulted_backtrace).to eql([])
    end
  end

  describe "#truncate!" do
    it "should remove metadata" do
      o   = FactoryGirl.create(:rails_occurrence)
      old = o.attributes

      o.truncate!
      expect(o).to be_truncated

      expect(o.metadata).to be_nil
      expect(o.client).to eql(old['client'])
      expect(o.occurred_at).to eql(old['occurred_at'])
      expect(o.bug_id).to eql(old['bug_id'])
      expect(o.number).to eql(old['number'])
    end
  end

  describe ".truncate!" do
    it "should truncate a group of exceptions" do
      os      = FactoryGirl.create_list :rails_occurrence, 4
      another = FactoryGirl.create :rails_occurrence
      Occurrence.truncate! Occurrence.where(id: os.map(&:id))
      expect(os.map(&:reload).all?(&:truncated?)).to eql(true)
      expect(another.reload).not_to be_truncated
    end
  end

  describe "#redirect_to!" do
    it "should truncate the occurrence and set the redirect target" do
      o1 = FactoryGirl.create(:rails_occurrence)
      o2 = FactoryGirl.create(:rails_occurrence, bug: o1.bug)
      o1.redirect_to! o2
      expect(o1.redirect_target).to eql(o2)
      expect(o1).to be_truncated
      expect(o1.bug).not_to be_irrelevant
    end

    it "should mark the bug as irrelevant if it's the last occurrence to be redirected" do
      b1 = FactoryGirl.create(:bug)
      b2 = FactoryGirl.create(:bug, environment: b1.environment)
      o1 = FactoryGirl.create(:rails_occurrence, bug: b1)
      o2 = FactoryGirl.create(:rails_occurrence, bug: b2)

      o1.redirect_to! o2
      expect(o1.redirect_target).to eql(o2)
      expect(b1.reload).to be_irrelevant
    end
  end

  describe "#symbolicate!" do
    before(:each) do
      @occurrence = FactoryGirl.create(:rails_occurrence)
      # there's a uniqueness constraint on repo URLs, but we need a real repo with real commits
      @occurrence.bug.environment.project.instance_variable_set :@repo, Project.new { |pp| pp.repository_url = 'https://github.com/RISCfuture/better_caller.git' }.repo
      @occurrence.bug.update_attribute :deploy, FactoryGirl.create(:deploy, environment: @occurrence.bug.environment)
    end

    it "should do nothing if there is no symbolication" do
      @occurrence.symbolication_id = nil
      expect { @occurrence.symbolicate! }.not_to change(@occurrence, :backtraces)
    end

    it "should do nothing if the occurrence is truncated" do
      @occurrence.truncate!
      expect { @occurrence.symbolicate! }.not_to change(@occurrence, :metadata)
    end

    it "should do nothing if the occurrence is already symbolicated" do
      @occurrence.backtraces = [{"name"      => "Thread 0",
                                 "faulted"   => true,
                                 "backtrace" => [{"file"   => "/usr/bin/gist",
                                                  "line"   => 313,
                                                  "symbol" => "<main>"},
                                                 {"file"   => "/usr/bin/gist",
                                                  "line"   => 171,
                                                  "symbol" => "execute"},
                                                 {"file"   => "/usr/bin/gist",
                                                  "line"   => 197,
                                                  "symbol" => "write"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 626,
                                                  "symbol" => "start"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 637,
                                                  "symbol" => "do_start"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 644,
                                                  "symbol" => "connect"},
                                                 {"file"   => "_RETURN_ADDRESS_",
                                                  "line"   => 87,
                                                  "symbol" => "timeout"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                                  "line"   => 44,
                                                  "symbol" => "timeout"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 644,
                                                  "symbol" => "block in connect"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 644,
                                                  "symbol" => "open"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 644,
                                                  "symbol" => "initialize"}]}]
      expect { @occurrence.symbolicate! }.not_to change(@occurrence, :backtraces)
    end

    it "should symbolicate the occurrence" do
      symbols = Squash::Symbolicator::Symbols.new
      symbols.add 1, 10, 'foo.rb', 15, 'bar'
      symbols.add 11, 20, 'foo2.rb', 5, 'bar2'
      symb = FactoryGirl.create(:symbolication, symbols: symbols)

      @occurrence.symbolication = symb
      @occurrence.backtraces    = [{"name"      => "Thread 0",
                                    "faulted"   => true,
                                    "backtrace" => [{"type"    => "address",
                                                     "address" => 1},
                                                    {"type"    => "address",
                                                     "address" => 2},
                                                    {"type"    => "address",
                                                     "address" => 12},
                                                    {"file"   => "_RETURN_ADDRESS_",
                                                     "line"   => 10,
                                                     "symbol" => "timeout"}]}]
      @occurrence.symbolicate!

      expect(@occurrence.changes).to be_empty
      expect(@occurrence.backtraces).to eql([{"name"      => "Thread 0",
                                              "faulted"   => true,
                                              "backtrace" => [{"file"   => "foo.rb",
                                                               "line"   => 15,
                                                               "symbol" => "bar"},
                                                              {"file"   => "foo.rb",
                                                               "line"   => 15,
                                                               "symbol" => "bar"},
                                                              {"file"   => "foo2.rb",
                                                               "line"   => 5,
                                                               "symbol" => "bar2"},
                                                              {"file"   => "_RETURN_ADDRESS_",
                                                               "line"   => 10,
                                                               "symbol" => "timeout"}]}])
    end


    it "should use a custom symbolication" do
      symbols1 = Squash::Symbolicator::Symbols.new
      symbols1.add 1, 10, 'foo.rb', 15, 'bar'
      symbols1.add 11, 20, 'foo2.rb', 5, 'bar2'
      symbols2 = Squash::Symbolicator::Symbols.new
      symbols2.add 1, 10, 'foo3.rb', 15, 'bar3'
      symbols2.add 11, 20, 'foo4.rb', 5, 'bar4'

      symb1 = FactoryGirl.create(:symbolication, symbols: symbols1)
      symb2 = FactoryGirl.create(:symbolication, symbols: symbols2)

      @occurrence.symbolication = symb1
      @occurrence.backtraces    = [{"name"      => "Thread 0",
                                    "faulted"   => true,
                                    "backtrace" => [{"type"    => "address",
                                                     "address" => 1},
                                                    {"type"    => "address",
                                                     "address" => 2},
                                                    {"type"    => "address",
                                                     "address" => 12},
                                                    {"file"   => "_RETURN_ADDRESS_",
                                                     "line"   => 10,
                                                     "symbol" => "timeout"}]}]
      @occurrence.symbolicate! symb2

      expect(@occurrence.changes).to be_empty
      expect(@occurrence.backtraces).to eql([{"name"      => "Thread 0",
                                              "faulted"   => true,
                                              "backtrace" => [{"file"   => "foo3.rb",
                                                               "line"   => 15,
                                                               "symbol" => "bar3"},
                                                              {"file"   => "foo3.rb",
                                                               "line"   => 15,
                                                               "symbol" => "bar3"},
                                                              {"file"   => "foo4.rb",
                                                               "line"   => 5,
                                                               "symbol" => "bar4"},
                                                              {"file"   => "_RETURN_ADDRESS_",
                                                               "line"   => 10,
                                                               "symbol" => "timeout"}]}])
    end
  end

  describe "#symbolicated?" do
    it "should return true if all lines are symbolicated" do
      expect(FactoryGirl.build(:occurrence, backtraces: [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" => [{"file"   => "/usr/bin/gist",
                                                                           "line"   => 313,
                                                                           "symbol" => "<main>"},
                                                                          {"file"   => "/usr/bin/gist",
                                                                           "line"   => 171,
                                                                           "symbol" => "execute"},
                                                                          {"file"   => "/usr/bin/gist",
                                                                           "line"   => 197,
                                                                           "symbol" => "write"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 626,
                                                                           "symbol" => "start"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 637,
                                                                           "symbol" => "do_start"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "connect"},
                                                                          {"file"   => "_RETURN_ADDRESS_",
                                                                           "line"   => 87,
                                                                           "symbol" => "timeout"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                                                           "line"   => 44,
                                                                           "symbol" => "timeout"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "block in connect"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "open"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "initialize"}]}])).to be_symbolicated
    end

    it "should return false if any line is unsymbolicated" do
      expect(FactoryGirl.build(:occurrence, backtraces: [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" => [{"file"   => "/usr/bin/gist",
                                                                           "line"   => 313,
                                                                           "symbol" => "<main>"},
                                                                          {"file"   => "/usr/bin/gist",
                                                                           "line"   => 171,
                                                                           "symbol" => "execute"},
                                                                          {"file"   => "/usr/bin/gist",
                                                                           "line"   => 197,
                                                                           "symbol" => "write"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 626,
                                                                           "symbol" => "start"},
                                                                          {"type"    => "address",
                                                                           "address" => 4632},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "connect"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                                                           "line"   => 87,
                                                                           "symbol" => "timeout"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                                                           "line"   => 44,
                                                                           "symbol" => "timeout"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "block in connect"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "open"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "initialize"}]}])).not_to be_symbolicated
    end
  end

  describe "#sourcemap!" do
    before(:each) do
      @occurrence = FactoryGirl.create(:rails_occurrence)
      # there's a uniqueness constraint on repo URLs, but we need a real repo with real commits
      @occurrence.bug.environment.project.instance_variable_set :@repo, Project.new { |pp| pp.repository_url = 'https://github.com/RISCfuture/better_caller.git' }.repo
      @occurrence.bug.update_attribute :deploy, FactoryGirl.create(:deploy, environment: @occurrence.bug.environment)
    end

    it "should do nothing if there is no source map" do
      expect { @occurrence.sourcemap! }.not_to change(@occurrence, :backtraces)
    end

    it "should do nothing if the occurrence is truncated" do
      @occurrence.truncate!
      expect { @occurrence.sourcemap! }.not_to change(@occurrence, :metadata)
    end

    it "should do nothing if the occurrence is already sourcemapped" do
      @occurrence.backtraces = [{"name"      => "Thread 0",
                                 "faulted"   => true,
                                 "backtrace" => [{"file"   => "/usr/bin/gist",
                                                  "line"   => 313,
                                                  "symbol" => "<main>"},
                                                 {"file"   => "/usr/bin/gist",
                                                  "line"   => 171,
                                                  "symbol" => "execute"},
                                                 {"file"   => "/usr/bin/gist",
                                                  "line"   => 197,
                                                  "symbol" => "write"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 626,
                                                  "symbol" => "start"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 637,
                                                  "symbol" => "do_start"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 644,
                                                  "symbol" => "connect"},
                                                 {"file"   => "_JAVA_",
                                                  "line"   => 87,
                                                  "symbol" => "timeout"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                                  "line"   => 44,
                                                  "symbol" => "timeout"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 644,
                                                  "symbol" => "block in connect"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 644,
                                                  "symbol" => "open"},
                                                 {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                  "line"   => 644,
                                                  "symbol" => "initialize"}]}]
      expect { @occurrence.sourcemap! }.not_to change(@occurrence, :backtraces)
    end

    it "should sourcemap the occurrence" do
      map = GemSourceMap::Map.new([
                                      GemSourceMap::Mapping.new('app/assets/javascripts/source.js', GemSourceMap::Offset.new(3, 140), GemSourceMap::Offset.new(25, 1)),
                                  ], 'http://test.host/example/asset.js')
      FactoryGirl.create :source_map, environment: @occurrence.bug.environment, revision: @occurrence.revision, map: map

      @occurrence.backtraces = [{"name"      => "Thread 0",
                                 "faulted"   => true,
                                 "backtrace" => [{"type"    => "js:hosted",
                                                  "url"     => "http://test.host/example/asset.js",
                                                  "line"    => 3,
                                                  "column"  => 140,
                                                  "symbol"  => "foo",
                                                  "context" => nil}]}]
      @occurrence.sourcemap!

      expect(@occurrence.changes).to be_empty
      expect(@occurrence.backtraces).to eql([{"name"      => "Thread 0",
                                              "faulted"   => true,
                                              "backtrace" => [{"file"   => "app/assets/javascripts/source.js",
                                                               "line"   => 25,
                                                               "column" => 1}]}])
    end

    it "should apply multiple source maps" do
      map1 = GemSourceMap::Map.new([
                                       GemSourceMap::Mapping.new('app/assets/javascripts/source.js', GemSourceMap::Offset.new(3, 140), GemSourceMap::Offset.new(25, 1)),
                                   ], 'http://test.host/example/asset.js')
      map2 = GemSourceMap::Map.new([
                                       GemSourceMap::Mapping.new('app/assets/javascripts/source.js.coffee', GemSourceMap::Offset.new(25, 1), GemSourceMap::Offset.new(11, 1)),
                                   ], 'app/assets/javascripts/source.js')

      FactoryGirl.create :source_map, environment: @occurrence.bug.environment, revision: @occurrence.revision, map: map1, from: 'hosted', to: 'compiled'
      FactoryGirl.create :source_map, environment: @occurrence.bug.environment, revision: @occurrence.revision, map: map2, from: 'compiled', to: 'coffee'

      @occurrence.backtraces = [{"name"      => "Thread 0",
                                 "faulted"   => true,
                                 "backtrace" => [{"type"    => "js:hosted",
                                                  "url"     => "http://test.host/example/asset.js",
                                                  "line"    => 3,
                                                  "column"  => 140,
                                                  "symbol"  => "foo",
                                                  "context" => nil}]}]
      @occurrence.sourcemap!

      expect(@occurrence.changes).to be_empty
      expect(@occurrence.backtraces).to eql([{"name"      => "Thread 0",
                                              "faulted"   => true,
                                              "backtrace" => [{"file"   => "app/assets/javascripts/source.js.coffee",
                                                               "line"   => 11,
                                                               "column" => 1}]}])
    end

    it "should search for sourcemaps in previous revisions if digest_in_asset_names is true" do
      @occurrence.bug.environment.project.update_attribute :digest_in_asset_names, true

      map1 = GemSourceMap::Map.new([
                                       GemSourceMap::Mapping.new('app/assets/javascripts/source.js', GemSourceMap::Offset.new(3, 140), GemSourceMap::Offset.new(25, 1)),
                                   ], 'http://test.host/example/asset.js')
      map2 = GemSourceMap::Map.new([
                                       GemSourceMap::Mapping.new('app/assets/javascripts/source.js.coffee', GemSourceMap::Offset.new(25, 1), GemSourceMap::Offset.new(11, 1)),
                                   ], 'app/assets/javascripts/source.js')

      FactoryGirl.create :source_map, environment: @occurrence.bug.environment, revision: 'e80f7f4a578a869f54b8ff675220e9d3071ea513', map: map1, from: 'hosted', to: 'compiled'
      FactoryGirl.create :source_map, environment: @occurrence.bug.environment, revision: @occurrence.revision, map: map2, from: 'compiled', to: 'coffee'

      @occurrence.backtraces = [{"name"      => "Thread 0",
                                 "faulted"   => true,
                                 "backtrace" => [{"type"    => "js:hosted",
                                                  "url"     => "http://test.host/example/asset.js",
                                                  "line"    => 3,
                                                  "column"  => 140,
                                                  "symbol"  => "foo",
                                                  "context" => nil}]}]
      @occurrence.sourcemap!

      expect(@occurrence.changes).to be_empty
      expect(@occurrence.backtraces).to eql([{"name"      => "Thread 0",
                                              "faulted"   => true,
                                              "backtrace" => [{"file"   => "app/assets/javascripts/source.js.coffee",
                                                               "line"   => 11,
                                                               "column" => 1}]}])
    end

    it "should not search for sourcemaps in previous revisions if digest_in_asset_names is false" do
      @occurrence.bug.environment.project.update_attribute :digest_in_asset_names, false

      map1 = GemSourceMap::Map.new([
                                       GemSourceMap::Mapping.new('app/assets/javascripts/source.js', GemSourceMap::Offset.new(3, 140), GemSourceMap::Offset.new(25, 1)),
                                   ], 'http://test.host/example/asset.js')
      map2 = GemSourceMap::Map.new([
                                       GemSourceMap::Mapping.new('app/assets/javascripts/source.js.coffee', GemSourceMap::Offset.new(25, 1), GemSourceMap::Offset.new(11, 1)),
                                   ], 'app/assets/javascripts/source.js')

      FactoryGirl.create :source_map, environment: @occurrence.bug.environment, revision: 'e80f7f4a578a869f54b8ff675220e9d3071ea513', map: map1, from: 'hosted', to: 'compiled'
      FactoryGirl.create :source_map, environment: @occurrence.bug.environment, revision: @occurrence.revision, map: map2, from: 'compiled', to: 'coffee'

      @occurrence.backtraces = [{"name"      => "Thread 0",
                                 "faulted"   => true,
                                 "backtrace" => [{"type"    => "js:hosted",
                                                  "url"     => "http://test.host/example/asset.js",
                                                  "line"    => 3,
                                                  "column"  => 140,
                                                  "symbol"  => "foo",
                                                  "context" => nil}]}]
      @occurrence.sourcemap!

      expect(@occurrence.changes).to be_empty
      expect(@occurrence.backtraces).to eql([{"name"      => "Thread 0",
                                              "faulted"   => true,
                                              "backtrace" => [{"type"    => "js:hosted",
                                                               "url"     => "http://test.host/example/asset.js",
                                                               "line"    => 3,
                                                               "column"  => 140,
                                                               "symbol"  => "foo",
                                                               "context" => nil}]}])
    end

    it "should use a custom sourcemap" do
      map1 = GemSourceMap::Map.new([
                                       GemSourceMap::Mapping.new('app/assets/javascripts/source1.js', GemSourceMap::Offset.new(3, 140), GemSourceMap::Offset.new(1, 1)),
                                   ], 'http://test.host/example/asset.js')
      map2 = GemSourceMap::Map.new([
                                       GemSourceMap::Mapping.new('app/assets/javascripts/source2.js', GemSourceMap::Offset.new(3, 140), GemSourceMap::Offset.new(2, 2)),
                                   ], 'http://test.host/example/asset.js')

      sm1 = FactoryGirl.create :source_map, environment: @occurrence.bug.environment, revision: @occurrence.revision, map: map1
      sm2 = FactoryGirl.create :source_map, map: map2

      @occurrence.backtraces = [{"name"      => "Thread 0",
                                 "faulted"   => true,
                                 "backtrace" => [{"type"    => "js:hosted",
                                                  "url"     => "http://test.host/example/asset.js",
                                                  "line"    => 3,
                                                  "column"  => 140,
                                                  "symbol"  => "foo",
                                                  "context" => nil}]}]
      @occurrence.sourcemap! sm2

      expect(@occurrence.changes).to be_empty
      expect(@occurrence.backtraces).to eql([{"name"      => "Thread 0",
                                              "faulted"   => true,
                                              "backtrace" => [{"file"   => "app/assets/javascripts/source2.js",
                                                               "line"   => 2,
                                                               "column" => 2}]}])
    end
  end

  describe "#sourcemapped?" do
    it "should return true if all lines are source-mapped" do
      expect(FactoryGirl.build(:occurrence, backtraces: [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" => [{"file"   => "/usr/bin/gist",
                                                                           "line"   => 313,
                                                                           "symbol" => "<main>"},
                                                                          {"file"   => "/usr/bin/gist",
                                                                           "line"   => 171,
                                                                           "symbol" => "execute"},
                                                                          {"file"   => "/usr/bin/gist",
                                                                           "line"   => 197,
                                                                           "symbol" => "write"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 626,
                                                                           "symbol" => "start"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 637,
                                                                           "symbol" => "do_start"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "connect"},
                                                                          {"file"   => "_RETURN_ADDRESS_",
                                                                           "line"   => 87,
                                                                           "symbol" => "timeout"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                                                           "line"   => 44,
                                                                           "symbol" => "timeout"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "block in connect"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "open"},
                                                                          {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                           "line"   => 644,
                                                                           "symbol" => "initialize"}]}])).to be_sourcemapped
    end

    it "should return false if any line is not source-mapped" do
      expect(FactoryGirl.build(:occurrence, backtraces: [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" =>
                                                              [{"file" => "/usr/bin/gist", "line" => 313, "symbol" => "<main>"},
                                                               {"file" => "/usr/bin/gist", "line" => 171, "symbol" => "execute"},
                                                               {"file" => "/usr/bin/gist", "line" => 197, "symbol" => "write"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 626,
                                                                "symbol" => "start"},
                                                               {"type"    => "js:hosted",
                                                                "url"     => "http://test.host/my.js",
                                                                "line"    => 20,
                                                                "column"  => 5,
                                                                "symbol"  => "myfunction",
                                                                "context" => nil},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 644,
                                                                "symbol" => "connect"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                                                "line"   => 87,
                                                                "symbol" => "timeout"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                                                "line"   => 44,
                                                                "symbol" => "timeout"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 644,
                                                                "symbol" => "block in connect"},
                                                               {"file" => "/usr/lib/ruby/1.9.1/net/http.rb", "line" => 644, "symbol" => "open"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 644,
                                                                "symbol" => "initialize"}]}])).not_to be_sourcemapped
    end
  end

  describe "#deobfuscate!" do
    before(:each) do
      @occurrence = FactoryGirl.create(:rails_occurrence)
      # there's a uniqueness constraint on repo URLs, but we need a real repo with real commits
      @occurrence.bug.environment.project.instance_variable_set :@repo, Project.new { |pp| pp.repository_url = 'https://github.com/RISCfuture/better_caller.git' }.repo
      @occurrence.bug.update_attribute :deploy, FactoryGirl.create(:deploy, environment: @occurrence.bug.environment)
    end

    it "should do nothing if there is no obfuscation map" do
      expect { @occurrence.deobfuscate! }.not_to change(@occurrence, :backtraces)
    end

    it "should do nothing if the occurrence is truncated" do
      @occurrence.truncate!
      expect { @occurrence.deobfuscate! }.not_to change(@occurrence, :metadata)
    end

    it "should do nothing if the occurrence is already de-obfuscated" do
      @occurrence.backtraces = [{"name"      => "Thread 0",
                                 "faulted"   => true,
                                 "backtrace" =>
                                     [{"file" => "/usr/bin/gist", "line" => 313, "symbol" => "<main>"},
                                      {"file" => "/usr/bin/gist", "line" => 171, "symbol" => "execute"},
                                      {"file" => "/usr/bin/gist", "line" => 197, "symbol" => "write"},
                                      {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                       "line"   => 626,
                                       "symbol" => "start"},
                                      {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                       "line"   => 637,
                                       "symbol" => "do_start"},
                                      {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                       "line"   => 644,
                                       "symbol" => "connect"},
                                      {"file" => "_JAVA_", "line" => 87, "symbol" => "timeout"},
                                      {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                       "line"   => 44,
                                       "symbol" => "timeout"},
                                      {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                       "line"   => 644,
                                       "symbol" => "block in connect"},
                                      {"file" => "/usr/lib/ruby/1.9.1/net/http.rb", "line" => 644, "symbol" => "open"},
                                      {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                       "line"   => 644,
                                       "symbol" => "initialize"}]}]
      expect { @occurrence.deobfuscate! }.not_to change(@occurrence, :backtraces)
    end

    it "should deobfuscate the occurrence" do
      namespace = Squash::Java::Namespace.new
      namespace.add_package_alias 'com.foo', 'A'
      namespace.add_class_alias('com.foo.Bar', 'B').path = 'src/foo/Bar.java'
      namespace.add_method_alias 'com.foo.Bar', 'int baz(java.lang.String)', 'a'
      FactoryGirl.create :obfuscation_map, namespace: namespace, deploy: @occurrence.bug.deploy

      @occurrence.backtraces = [{"name"      => "Thread 0",
                                 "faulted"   => true,
                                 "backtrace" =>
                                     [{"type"       => "obfuscated",
                                       "file"       => "B.java",
                                       "line"       => 15,
                                       "symbol"     => "int a(java.lang.String)",
                                       "class_name" => "com.A.B"}]}]
      @occurrence.deobfuscate!

      expect(@occurrence.changes).to be_empty
      expect(@occurrence.backtraces).to eql([{"name"      => "Thread 0",
                                              "faulted"   => true,
                                              "backtrace" =>
                                                  [{"file"   => "src/foo/Bar.java",
                                                    "line"   => 15,
                                                    "symbol" => "int baz(java.lang.String)"}]}])
    end

    it "should leave un-obfuscated names intact" do
      namespace = Squash::Java::Namespace.new
      namespace.add_package_alias 'com.foo', 'A'
      namespace.add_class_alias('com.foo.Bar', 'B').path = 'src/foo/Bar.java'
      namespace.add_method_alias 'com.foo.Bar', 'int baz(java.lang.String)', 'a'
      FactoryGirl.create :obfuscation_map, namespace: namespace, deploy: @occurrence.bug.deploy

      @occurrence.backtraces = [{"name"      => "Thread 0",
                                 "faulted"   => true,
                                 "backtrace" =>
                                     [{"type"       => "obfuscated",
                                       "file"       => "B.java",
                                       "line"       => 15,
                                       "symbol"     => "int b(java.lang.String)",
                                       "class_name" => "com.A.B"},
                                      {"type"       => "obfuscated",
                                       "file"       => "ActivityThread.java",
                                       "line"       => 15,
                                       "symbol"     => "int a(java.lang.String)",
                                       "class_name" => "com.squareup.ActivityThread"}]}]
      @occurrence.deobfuscate!

      expect(@occurrence.changes).to be_empty
      expect(@occurrence.backtraces).to eql([{"name"      => "Thread 0",
                                              "faulted"   => true,
                                              "backtrace" =>
                                                  [{"file"   => "src/foo/Bar.java",
                                                    "line"   => 15,
                                                    "symbol" => "int b(java.lang.String)"},
                                                   {"type"       => "obfuscated",
                                                    "file"       => "ActivityThread.java",
                                                    "line"       => 15,
                                                    "symbol"     => "int a(java.lang.String)",
                                                    "class_name" => "com.squareup.ActivityThread"}]}])
    end

    it "should use a custom obfuscation map" do
      namespace1 = Squash::Java::Namespace.new
      namespace1.add_package_alias 'com.foo', 'A'
      namespace1.add_class_alias('com.foo.BarOne', 'B').path = 'src/foo/BarOne.java'
      namespace1.add_method_alias 'com.foo.BarOne', 'int baz1(java.lang.String)', 'a'

      namespace2 = Squash::Java::Namespace.new
      namespace2.add_package_alias 'com.foo', 'A'
      namespace2.add_class_alias('com.foo.BarTwo', 'B').path = 'src/foo/BarTwo.java'
      namespace2.add_method_alias 'com.foo.BarTwo', 'int baz2(java.lang.String)', 'a'

      om1 = FactoryGirl.create(:obfuscation_map, namespace: namespace1, deploy: @occurrence.bug.deploy)
      om2 = FactoryGirl.create(:obfuscation_map, namespace: namespace2, deploy: @occurrence.bug.deploy)

      @occurrence.backtraces = [{"name"      => "Thread 0",
                                 "faulted"   => true,
                                 "backtrace" =>
                                     [{"type"       => "obfuscated",
                                       "file"       => "B.java",
                                       "line"       => 15,
                                       "symbol"     => "int a(java.lang.String)",
                                       "class_name" => "com.A.B"}]}]
      @occurrence.deobfuscate! om2

      expect(@occurrence.changes).to be_empty
      expect(@occurrence.backtraces).to eql([{"name"      => "Thread 0",
                                              "faulted"   => true,
                                              "backtrace" =>
                                                  [{"file"   => "src/foo/BarTwo.java",
                                                    "line"   => 15,
                                                    "symbol" => "int baz2(java.lang.String)"}]}])
    end
  end

  describe "#deobfuscated?" do
    it "should return true if all lines are deobfuscated" do
      expect(FactoryGirl.build(:occurrence, backtraces: [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" =>
                                                              [{"file" => "/usr/bin/gist", "line" => 313, "symbol" => "<main>"},
                                                               {"file" => "/usr/bin/gist", "line" => 171, "symbol" => "execute"},
                                                               {"file" => "/usr/bin/gist", "line" => 197, "symbol" => "write"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 626,
                                                                "symbol" => "start"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 637,
                                                                "symbol" => "do_start"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 644,
                                                                "symbol" => "connect"},
                                                               {"file" => "_JAVA_", "line" => 87, "symbol" => "timeout"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                                                "line"   => 44,
                                                                "symbol" => "timeout"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 644,
                                                                "symbol" => "block in connect"},
                                                               {"file" => "/usr/lib/ruby/1.9.1/net/http.rb", "line" => 644, "symbol" => "open"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 644,
                                                                "symbol" => "initialize"}]}])).
          to be_deobfuscated
    end

    it "should return false if any line is deobfuscated" do
      expect(FactoryGirl.build(:occurrence, backtraces: [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" =>
                                                              [{"file" => "/usr/bin/gist", "line" => 313, "symbol" => "<main>"},
                                                               {"file" => "/usr/bin/gist", "line" => 171, "symbol" => "execute"},
                                                               {"file" => "/usr/bin/gist", "line" => 197, "symbol" => "write"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 626,
                                                                "symbol" => "start"},
                                                               {"type"       => "obfuscated",
                                                                "file"       => "A.java",
                                                                "line"       => 15,
                                                                "symbol"     => "b",
                                                                "class_name" => "A"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 644,
                                                                "symbol" => "connect"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                                                "line"   => 87,
                                                                "symbol" => "timeout"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/timeout.rb",
                                                                "line"   => 44,
                                                                "symbol" => "timeout"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 644,
                                                                "symbol" => "block in connect"},
                                                               {"file" => "/usr/lib/ruby/1.9.1/net/http.rb", "line" => 644, "symbol" => "open"},
                                                               {"file"   => "/usr/lib/ruby/1.9.1/net/http.rb",
                                                                "line"   => 644,
                                                                "symbol" => "initialize"}]}])).
          not_to be_deobfuscated
    end
  end

  describe "#recategorize!" do
    it "should re-assign the Occurrence to a different bug if necessary" do
      bug1 = FactoryGirl.create(:bug)
      bug2 = FactoryGirl.create(:bug, environment: bug1.environment)
      occ  = FactoryGirl.create(:rails_occurrence, bug: bug1)

      blamer = bug1.environment.project.blamer.new(occ)
      allow(blamer.class).to receive(:new).and_return(blamer)
      expect(blamer).to receive(:find_or_create_bug!).once.and_return(bug2)

      message     = occ.message
      revision    = occ.revision
      occurred_at = occ.occurred_at
      client      = occ.client
      occ.recategorize!

      expect(bug2.occurrences.count).to eql(1)
      occ2 = bug2.occurrences.first
      expect(occ.redirect_target).to eql(occ2)

      expect(occ2.message).to eql(message)
      expect(occ2.revision).to eql(revision)
      expect(occ2.occurred_at).to eql(occurred_at)
      expect(occ2.client).to eql(client)
    end

    it "should reopen the new bug if necessary" do
      bug1 = FactoryGirl.create(:bug)
      bug2 = FactoryGirl.create(:bug, environment: bug1.environment, fixed: true, fix_deployed: true)
      occ  = FactoryGirl.create(:rails_occurrence, bug: bug1)

      blamer = bug1.environment.project.blamer.new(occ)
      allow(blamer.class).to receive(:new).and_return(blamer)
      expect(blamer).to receive(:find_or_create_bug!).once.and_return(bug2)

      message     = occ.message
      revision    = occ.revision
      occurred_at = occ.occurred_at
      client      = occ.client
      occ.recategorize!

      expect(bug2.occurrences.count).to eql(1)
      occ2 = bug2.occurrences.first
      expect(occ.redirect_target).to eql(occ2)

      expect(occ2.message).to eql(message)
      expect(occ2.revision).to eql(revision)
      expect(occ2.occurred_at).to eql(occurred_at)
      expect(occ2.client).to eql(client)
    end
  end
end
