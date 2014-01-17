# encoding: utf-8

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

describe Bug do
  context "[database rules]" do
    it "should automatically increment/decrement occurrences_count" do
      bug = FactoryGirl.create(:bug)
      expect(bug.occurrences_count).to be_zero

      occurrence = FactoryGirl.create(:rails_occurrence, bug: bug)
      expect(bug.reload.occurrences_count).to eql(1)

      occurrence.destroy
      expect(bug.reload.occurrences_count).to be_zero
    end

    it "should automatically increment/decrement comments_count" do
      bug   = FactoryGirl.create(:bug)
      owner = bug.environment.project.owner
      expect(bug.comments_count).to be_zero

      comment = FactoryGirl.create(:comment, bug: bug, user: owner)
      expect(bug.reload.comments_count).to eql(1)

      comment.destroy
      expect(bug.reload.comments_count).to be_zero
    end

    it "should automatically set latest_occurrence" do
      bug = FactoryGirl.create(:bug)
      expect(bug.latest_occurrence).to be_nil

      occurrence = FactoryGirl.create(:rails_occurrence, bug: bug)
      expect(bug.reload.latest_occurrence).to eql(occurrence.occurred_at)

      occurrence = FactoryGirl.create(:rails_occurrence, bug: bug, occurred_at: occurrence.occurred_at + 1.day)
      expect(bug.reload.latest_occurrence).to eql(occurrence.occurred_at)

      FactoryGirl.create :rails_occurrence, bug: bug, occurred_at: occurrence.occurred_at - 5.hours
      expect(bug.reload.latest_occurrence).to eql(occurrence.occurred_at)
    end

    it "should set number sequentially for a given bug" do
      env1 = FactoryGirl.create(:environment)
      env2 = FactoryGirl.create(:environment)

      bug1_1 = FactoryGirl.create(:bug, environment: env1)
      bug1_2 = FactoryGirl.create(:bug, environment: env1)
      bug2_1 = FactoryGirl.create(:bug, environment: env2)
      bug2_2 = FactoryGirl.create(:bug, environment: env2)

      expect(bug1_1.number).to eql(1)
      expect(bug1_2.number).to eql(2)
      expect(bug2_1.number).to eql(1)
      expect(bug2_2.number).to eql(2)
    end

    it "should not reuse deleted numbers" do
      #bug = FactoryGirl.create(:bug)
      #FactoryGirl.create :occurrence, bug: bug
      #FactoryGirl.create(:occurrence, bug: bug).destroy
      #FactoryGirl.create(:occurrence, bug: bug).number.should eql(3)
      #TODO get this part of the spec to work (for URL-resource identity integrity)

      bug = FactoryGirl.create(:bug)
      FactoryGirl.create :rails_occurrence, bug: bug
      c = FactoryGirl.create(:rails_occurrence, bug: bug)
      FactoryGirl.create :rails_occurrence, bug: bug
      c.destroy
      expect(FactoryGirl.create(:rails_occurrence, bug: bug).number).to eql(4)
    end
  end

  context "[hooks]" do
    it "should downcase the revision" do
      expect(FactoryGirl.create(:bug, revision: '2DC20C984283BEDE1F45863B8F3B4DD9B5B554CC').revision).to eql('2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
    end

    it "should set fixed_at when a bug is fixed" do
      bug = FactoryGirl.create(:bug)
      expect(bug.fixed_at).to be_nil
      bug.fixed = true
      bug.save!
      expect(bug.fixed_at.to_i).to be_within(2).of(Time.now.to_i)
    end

    context "[PagerDuty integration]" do
      before :each do
        @project     = FactoryGirl.create(:project, pagerduty_service_key: 'abc123', pagerduty_enabled: true)
        @environment = FactoryGirl.create(:environment, project: @project, notifies_pagerduty: true)
        @user        = FactoryGirl.create(:membership, project: @project).user
        @bug         = FactoryGirl.create(:bug, environment: @environment)
      end

      it "should not send any PagerDuty events when the bug is modified other than described below" do
        expect_any_instance_of(Service::PagerDuty).not_to receive(:acknowledge)
        expect_any_instance_of(Service::PagerDuty).not_to receive(:resolve)
        @bug.update_attribute :jira_issue, 'ONCALL-1367'
      end

      it "should send a PagerDuty acknowledge event when the bug is assigned" do
        expect_any_instance_of(Service::PagerDuty).to receive(:acknowledge).once.with(
            @bug.pagerduty_incident_key,
            /was assigned to #{Regexp.escape @user.name}/,
            an_instance_of(Hash)
        )
        @bug.update_attribute :assigned_user, @user
      end

      it "should send a PagerDuty acknowledge event when the bug is marked irrelevant" do
        expect_any_instance_of(Service::PagerDuty).to receive(:acknowledge).once.with(
            @bug.pagerduty_incident_key,
            /was marked as irrelevant/,
            an_instance_of(Hash)
        )
        @bug.update_attribute :irrelevant, true
      end

      it "should send a PagerDuty acknowledge event when the bug is resolved" do
        expect_any_instance_of(Service::PagerDuty).to receive(:acknowledge).once.with(
            @bug.pagerduty_incident_key,
            /was marked as resolved/,
            an_instance_of(Hash)
        )
        @bug.update_attribute :fixed, true
      end

      it "should send a PagerDuty resolve event when the bug is deployed" do
        expect_any_instance_of(Service::PagerDuty).to receive(:acknowledge).once
        @bug.update_attribute :fixed, true

        expect_any_instance_of(Service::PagerDuty).to receive(:resolve).once.with(
            @bug.pagerduty_incident_key,
            /was deployed/
        )
        @bug.update_attribute :fix_deployed, true
      end

      it "should not send any events when the environment has PagerDuty disabled" do
        @environment.update_attribute :notifies_pagerduty, false
        @bug.reload
        expect_any_instance_of(Service::PagerDuty).not_to receive(:resolve)
        @bug.update_attribute :fixed, true
      end

      it "should not send any events when the project has no PagerDuty configuration" do
        @project.update_attribute :pagerduty_service_key, nil
        @bug.reload
        expect_any_instance_of(Service::PagerDuty).not_to receive(:resolve)
        @bug.update_attribute :fixed, true
      end

      it "should send events when the project has PagerDuty incident reporting disabled" do
        @project.update_attribute :pagerduty_enabled, false
        @bug.reload
        expect_any_instance_of(Service::PagerDuty).to receive(:acknowledge).once
        @bug.update_attribute :fixed, true
      end
    end unless Squash::Configuration.pagerduty.disabled?
  end

  context "[validations]" do
    it "should not allow an unfixed bug to be marked as fix_deployed" do
      bug = FactoryGirl.build(:bug, fixed: false, fix_deployed: true)
      expect(bug).not_to be_valid
      expect(bug.errors[:fix_deployed]).not_to be_empty
    end

    it "should only let project members be assigned to bugs" do
      bug               = FactoryGirl.create(:bug)
      bug.assigned_user = FactoryGirl.create(:user)
      expect(bug).not_to be_valid
      expect(bug.errors[:assigned_user_id]).to eql(['is not a project member'])
    end
  end

  context "[events]" do
    before :all do
      @environment = FactoryGirl.create(:environment)
      @modifier    = FactoryGirl.create(:membership, project: @environment.project).user
    end

    context "[open]" do
      it "should create an open event when first created" do
        bug = FactoryGirl.create(:bug, environment: @environment)
        expect(bug.events.count).to eql(1)
        expect(bug.events.first.kind).to eql('open')
      end
    end

    context "[assign]" do
      before :all do
        @bug      = FactoryGirl.create(:bug, environment: @environment)
        @assignee = FactoryGirl.create(:membership, project: @environment.project).user
      end

      it "should create an assign event when assigned by a user to a user" do
        @bug.update_attribute :assigned_user, nil
        @bug.modifier = @modifier

        @bug.update_attribute :assigned_user, @assignee
        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('assign')
        expect(event.user_id).to eql(@modifier.id)
        expect(event.data['assignee_id']).to eql(@assignee.id)
      end

      it "should create an assign event when assigned by a user to to no one" do
        @bug.update_attribute :assigned_user, @assignee
        @bug.modifier = @modifier

        @bug.update_attribute :assigned_user, nil
        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('assign')
        expect(event.user_id).to eql(@modifier.id)
        expect(event.data['assignee_id']).to be_nil
      end

      it "should create an assign event when assigned by no one to a user" do
        @bug.update_attribute :assigned_user, nil
        @bug.modifier = nil

        @bug.update_attribute :assigned_user, @assignee
        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('assign')
        expect(event.user_id).to be_nil
        expect(event.data['assignee_id']).to eql(@assignee.id)
      end

      it "should create an assign event when assigned by no one to to no one" do
        @bug.update_attribute :assigned_user, @assignee
        @bug.modifier = nil

        @bug.update_attribute :assigned_user, nil
        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('assign')
        expect(event.user_id).to be_nil
        expect(event.data['assignee_id']).to be_nil
      end
    end

    context "[dupe]" do
      before(:each) { @bug = FactoryGirl.create(:bug, environment: @environment) }

      it "should create a dupe event when marked as a duplicate by someone" do
        original = FactoryGirl.create(:bug, environment: @bug.environment)
        @bug.modifier = @modifier
        @bug.update_attribute :duplicate_of, original

        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('dupe')
        expect(event.user_id).to eql(@modifier.id)
      end

      it "should create a dupe event when marked as a duplicate" do
        original = FactoryGirl.create(:bug, environment: @bug.environment)
        @bug.update_attribute :duplicate_of, original

        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('dupe')
        expect(event.user_id).to be_nil
      end
    end

    context "[close]" do
      before(:all) { @bug = FactoryGirl.create(:bug, environment: @environment) }
      before(:each) { @revision = '8f29160c367cc3e73c112e34de0ee48c4c323ff7' }

      it "should create a 'fixed' close event when fixed" do
        @bug.modifier = nil
        @bug.update_attribute :fixed, false
        @bug.update_attribute :irrelevant, false

        @bug.update_attributes fixed: true, resolution_revision: @revision
        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('close')
        expect(event.user_id).to be_nil
        expect(event.data['status']).to eql('fixed')
        expect(event.data['revision']).to eql(@revision)
      end

      it "should create a 'fixed' close event when fixed by a user" do
        @bug.modifier = @modifier
        @bug.update_attribute :fixed, false
        @bug.update_attribute :irrelevant, false

        @bug.update_attributes fixed: true, resolution_revision: @revision
        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('close')
        expect(event.user).to eql(@modifier)
        expect(event.data['status']).to eql('fixed')
        expect(event.data['revision']).to eql(@revision)
      end

      it "should create an 'irrelevant' close event when marked irrelevant" do
        @bug.modifier = nil
        @bug.update_attribute :fixed, false
        @bug.update_attribute :irrelevant, false

        @bug.update_attribute :irrelevant, true
        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('close')
        expect(event.user_id).to be_nil
        expect(event.data['status']).to eql('irrelevant')
      end

      it "should create an 'irrelevant' close event when marked irrelevant by a user" do
        @bug.modifier = @modifier
        @bug.update_attribute :fixed, false
        @bug.update_attribute :irrelevant, false

        @bug.update_attribute :irrelevant, true
        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('close')
        expect(event.user).to eql(@modifier)
        expect(event.data['status']).to eql('irrelevant')
      end

      it "should create a 'fixed' close event when fixed and marked irrelevant" do
        @bug.update_attribute :fixed, false
        @bug.update_attribute :irrelevant, false

        @bug.fixed               = true
        @bug.irrelevant          = true
        @bug.resolution_revision = @revision
        @bug.save!
        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('close')
        expect(event.data['status']).to eql('fixed')
        expect(event.data['revision']).to eql(@revision)
      end
    end

    context "[deploy]" do
      before(:all) { @bug = FactoryGirl.create(:bug, environment: @environment, fixed: true) }

      it "should create a deploy event when marked fix_deployed" do
        @bug.update_attribute :fix_deployed, true
        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('deploy')
        expect(event.data['revision']).to be_nil
      end

      it "should create a deploy event with revision when marked fix_deployed by a deploy" do
        @bug.update_attribute :fix_deployed, false
        deploy             = FactoryGirl.create(:deploy, environment: @environment)
        @bug.fixing_deploy = deploy

        @bug.update_attribute :fix_deployed, true
        event = @bug.events(true).order('id ASC').last
        expect(event.kind).to eql('deploy')
        expect(event.data['revision']).to eql(deploy.revision)
      end
    end

    context "[reopen]" do
      before :each do
        @bug        = FactoryGirl.create(:bug, environment: @environment, fixed: true)
        @occurrence = FactoryGirl.create(:rails_occurrence, bug: @bug)
      end

      it "should send an email if the bug was reopened from a fixed state by the system" do
        ActionMailer::Base.deliveries.clear
        @bug.reopen @occurrence
        allow(@bug).to receive(:blamed_email).and_return('blamed@example.com')
        @bug.assigned_user = @modifier
        @bug.save!
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include('Reopened')
        expect(ActionMailer::Base.deliveries.first.to).to eql([@modifier.email])
      end

      it "should email the blamed user if no one is assigned" do
        ActionMailer::Base.deliveries.clear
        @bug.reopen @occurrence
        allow(@bug).to receive(:blamed_email).and_return('blamed@example.com')
        @bug.save!
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include('Reopened')
        expect(ActionMailer::Base.deliveries.first.to).to eql(%w(blamed@example.com))
      end

      it "should not send an email if the bug was reopened from an irrelevant state" do
        @bug.update_attribute :irrelevant, true
        ActionMailer::Base.deliveries.clear
        @bug.reopen @occurrence
        allow(@bug).to receive(:blamed_email).and_return('blamed@example.com')
        @bug.save!
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the bug was reopened by a user" do
        ActionMailer::Base.deliveries.clear
        @bug.reopen @modifier
        allow(@bug).to receive(:blamed_email).and_return('blamed@example.com')
        @bug.save!
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      {'user' => '@modifier', 'occurrence' => '@occurrence'}.each do |modifier_type, modifier|
        context "[modifier is #{modifier_type}]" do
          before(:each) { @bug.modifier = eval(modifier) }

          it "should create an 'unfixed' reopen event when a relevant fixed bug is marked unfixed" do
            @bug.update_attribute :fixed, false
            event = @bug.events(true).order('id ASC').last
            expect(event.kind).to eql('reopen')
            expect(event.data['from']).to eql('fixed')
            if @bug.modifier.kind_of?(User)
              expect(event.user).to eql(@bug.modifier)
            else
              expect(event.data['occurrence_id']).to eql(@bug.modifier.id)
            end
          end

          it "should not create an 'unfixed' reopen event when an irrelevant fixed bug is marked unfixed" do
            @bug.update_attributes irrelevant: true, fixed: true
            Event.delete_all

            @bug.update_attribute :fixed, false
            expect(@bug.events(true).count).to be_zero
          end

          it "should create a 'relevant' reopen event when an unfixed irrelevant bug is marked relevant" do
            @bug.update_attributes irrelevant: true, fixed: false

            @bug.update_attribute :irrelevant, false
            event = @bug.events(true).order('id ASC').last
            expect(event.kind).to eql('reopen')
            expect(event.data['from']).to eql('irrelevant')
            if @bug.modifier.kind_of?(User)
              expect(event.user).to eql(@bug.modifier)
            else
              expect(event.data['occurrence_id']).to eql(@bug.modifier.id)
            end
          end

          it "should not create a 'relevant' reopen event when a fixed irrelevant bug is marked relevant" do
            @bug.update_attributes irrelevant: true, fixed: true
            Event.delete_all

            @bug.update_attribute :irrelevant, false
            expect(@bug.events(true).count).to be_zero
          end
        end
      end
    end
  end

  context "[emails]" do
    context "[assignment]" do
      before :all do
        @project  = FactoryGirl.create(:project)
        @assigner = FactoryGirl.create(:membership, project: @project).user
        @assignee = FactoryGirl.create(:membership, project: @project).user
      end

      before :each do
        @bug = FactoryGirl.create(:bug, environment: FactoryGirl.create(:environment, project: @project))
        ActionMailer::Base.deliveries.clear
      end

      it "should send an email when a user assigns the bug to another user" do
        @bug.modifier = @assigner
        @bug.update_attribute :assigned_user, @assignee
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include("You have been assigned")
        expect(ActionMailer::Base.deliveries.first.to).to include(@assignee.email)
      end

      it "should not send an email when the system assigns the bug to another user" do
        @bug.update_attribute :assigned_user, @assignee
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email when a user assigns the bug to himself" do
        @bug.modifier = @assignee
        @bug.update_attribute :assigned_user, @assignee
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email when a user un-assigns a bug" do
        @bug.modifier = @assigner
        @bug.update_attribute :assigned_user, nil
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the bug is fixed" do
        @bug.update_attribute :fixed, true
        ActionMailer::Base.deliveries.clear

        @bug.modifier = @assigner
        @bug.update_attribute :assigned_user, @assignee
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the bug is irrelevant" do
        @bug.update_attribute :irrelevant, true
        ActionMailer::Base.deliveries.clear

        @bug.modifier = @assigner
        @bug.update_attribute :assigned_user, @assignee
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the environment has email sending disabled" do
        @bug.environment.update_attribute :sends_emails, false
        @bug.modifier = @assigner
        @bug.update_attribute :assigned_user, @assignee
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the user has assignment emails disabled" do
        Membership.for(@assignee, @project).first.update_attribute :send_assignment_emails, false
        @bug.modifier = @assigner
        @bug.update_attribute :assigned_user, @assignee
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "[resolution]" do
      before :all do
        @project  = FactoryGirl.create(:project)
        @resolver = FactoryGirl.create(:membership, project: @project).user
        @assigned = FactoryGirl.create(:membership, project: @project).user
      end

      before :each do
        @bug = FactoryGirl.create(:bug,
                                  environment:   FactoryGirl.create(:environment, project: @project),
                                  assigned_user: @assigned)
        ActionMailer::Base.deliveries.clear
      end

      it "should send an email when someone other than the assigned user resolves a bug" do
        @bug.modifier = @resolver
        @bug.update_attribute :fixed, true

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include("was resolved")
        expect(ActionMailer::Base.deliveries.first.to).to include(@assigned.email)
      end

      it "should send an email when the system resolves a bug" do
        @bug.update_attribute :fixed, true

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include("was resolved")
        expect(ActionMailer::Base.deliveries.first.to).to include(@assigned.email)
      end

      it "should not send an email when the assigned user resolves a bug" do
        @bug.modifier = @assigned
        @bug.update_attribute :fixed, true
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the bug is marked irrelevant" do
        @bug.update_attribute :irrelevant, true
        ActionMailer::Base.deliveries.clear
        @bug.modifier = @resolver
        @bug.update_attribute :fixed, true
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the bug is resolved and no one is assigned" do
        @bug.update_attribute :assigned_user, nil
        ActionMailer::Base.deliveries.clear
        @bug.modifier = @resolver
        @bug.update_attribute :fixed, true
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should send an email when someone other than the assigned user marks a bug irrelevant" do
        @bug.modifier = @resolver
        @bug.update_attribute :irrelevant, true

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include("was marked irrelevant")
        expect(ActionMailer::Base.deliveries.first.to).to include(@assigned.email)
      end

      it "should send an email when the system marks a bug irrelevant" do
        @bug.update_attribute :irrelevant, true

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include("was marked irrelevant")
        expect(ActionMailer::Base.deliveries.first.to).to include(@assigned.email)
      end

      it "should not send an email when the assigned user marks a bug irrelevant" do
        @bug.modifier = @assigned
        @bug.update_attribute :irrelevant, true
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the bug is resolved" do
        @bug.update_attribute :fixed, true
        ActionMailer::Base.deliveries.clear
        @bug.modifier = @resolver
        @bug.update_attribute :irrelevant, true
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the bug is marked irrelevant and no one is assigned" do
        @bug.update_attribute :assigned_user, nil
        ActionMailer::Base.deliveries.clear
        @bug.modifier = @resolver
        @bug.update_attribute :irrelevant, true
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the environment has email sending disabled" do
        @bug.environment.update_attribute :sends_emails, false
        @bug.modifier = @assigned
        @bug.update_attribute :assigned_user, @assigned
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the user has disabled resolution emails" do
        Membership.for(@assigned, @project).first.update_attribute :send_resolution_emails, false
        @bug.modifier = @resolver
        @bug.update_attribute :fixed, true
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "[initial]" do
      before :each do
        ActionMailer::Base.deliveries.clear
      end

      it "should send an email to the all mailing list" do
        project = FactoryGirl.create(:project, all_mailing_list: 'foo@example.com')
        env     = FactoryGirl.create(:environment, project: project)
        bug     = FactoryGirl.create(:bug, environment: env)

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include(bug.class_name)
        expect(ActionMailer::Base.deliveries.first.subject).to include(File.basename(bug.file))
        expect(ActionMailer::Base.deliveries.first.to).to include('foo@example.com')
      end

      it "should not send an email if no all-bugs mailing list is specified" do
        project = FactoryGirl.create(:project, all_mailing_list: nil)
        env     = FactoryGirl.create(:environment, project: project)
        bug     = FactoryGirl.create(:bug, environment: env)

        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the environment has email sending disabled" do
        project = FactoryGirl.create(:project, all_mailing_list: 'foo@example.com')
        env     = FactoryGirl.create(:environment, project: project, sends_emails: false)
        bug     = FactoryGirl.create(:bug, environment: env)
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "[blame]" do
      before :each do
        @bug = FactoryGirl.create(:bug)
        ActionMailer::Base.deliveries.clear
      end

      it "should send an email to the blamed user" do
        @bug = FactoryGirl.build(:bug)
        allow(@bug).to receive(:blamed_email).and_return('foo@example.com')
        allow(@bug).to receive(:blamed_commit).and_return('abc123')
        @bug.save!

        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include(@bug.class_name)
        expect(ActionMailer::Base.deliveries.first.subject).to include(File.basename(@bug.file))
        expect(ActionMailer::Base.deliveries.first.to).to include('foo@example.com')
      end

      it "should not send an email if no one is to blame" do
        @bug = FactoryGirl.build(:bug)
        allow(@bug).to receive(:blamed_email).and_return(nil)
        @bug.save!

        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the environment has email sending disabled" do
        @bug = FactoryGirl.build(:bug, environment: FactoryGirl.create(:environment, sends_emails: false))
        allow(@bug).to receive(:blamed_email).and_return('foo@example.com')
        @bug.save!

        expect(ActionMailer::Base.deliveries).to be_empty
      end

      # other specs in #blamed_email specs
    end

    context "[critical]" do
      before :each do
        @project = FactoryGirl.create(:project, critical_mailing_list: 'foo@example.com', critical_threshold: 3)
        @bug     = FactoryGirl.create(:bug, environment: FactoryGirl.create(:environment, project: @project))
        ActionMailer::Base.deliveries.clear
      end

      it "should send an email to the critical mailing list once when the threshold is exceeded" do
        FactoryGirl.create_list :rails_occurrence, 2, bug: @bug
        expect(ActionMailer::Base.deliveries).to be_empty

        FactoryGirl.create :rails_occurrence, bug: @bug
        expect(ActionMailer::Base.deliveries.size).to eql(1)
        expect(ActionMailer::Base.deliveries.first.subject).to include(@bug.class_name)
        expect(ActionMailer::Base.deliveries.first.subject).to include(File.basename(@bug.file))
        expect(ActionMailer::Base.deliveries.first.to).to include('foo@example.com')

        FactoryGirl.create :rails_occurrence, bug: @bug
        expect(ActionMailer::Base.deliveries.size).to eql(1)
      end

      it "should not send an email if the bug is marked as irrelevant" do
        FactoryGirl.create_list :rails_occurrence, 2, bug: @bug
        @bug.update_attribute :irrelevant, true
        expect(ActionMailer::Base.deliveries).to be_empty

        FactoryGirl.create :rails_occurrence, bug: @bug
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if the bug is fixed" do
        FactoryGirl.create_list :rails_occurrence, 2, bug: @bug
        @bug.update_attribute :fixed, true
        expect(ActionMailer::Base.deliveries).to be_empty

        FactoryGirl.create :rails_occurrence, bug: @bug
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if no critical mailing list is specified" do
        @project.update_attribute :critical_mailing_list, nil
        FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "should not send an email if no critical mailing list is specified" do
        @bug.environment.update_attribute :sends_emails, false
        FactoryGirl.create_list :rails_occurrence, 3, bug: @bug
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "[occurrence]" do
      before :all do
        @project = FactoryGirl.create(:project)
        @user1   = FactoryGirl.create(:membership, project: @project).user
        @user2   = FactoryGirl.create(:membership, project: @project).user
        @user3   = FactoryGirl.create(:membership, project: @project).user
        @bug     = FactoryGirl.create(:bug, environment: FactoryGirl.create(:environment, project: @project))
      end

      before(:each) { ActionMailer::Base.deliveries.clear }

      it "should send an email to the users who have signed up to be notified of occurrences" do
        @bug.update_attribute :notify_on_occurrence, [@user1, @user2].map(&:id)
        @occurrence = FactoryGirl.create(:rails_occurrence, bug: @bug)

        expect(ActionMailer::Base.deliveries.size).to eql(2)
        expect(ActionMailer::Base.deliveries.map(&:to).flatten.sort).to eql([@user1.email, @user2.email])
        ActionMailer::Base.deliveries.each { |d| expect(d.subject).to include('New occurrence') }
      end
    end

    context "[deploy]" do
      before :all do
        @project = FactoryGirl.create(:project)
        @user1   = FactoryGirl.create(:membership, project: @project).user
        @user2   = FactoryGirl.create(:membership, project: @project).user
        @user3   = FactoryGirl.create(:membership, project: @project).user
        @bug     = FactoryGirl.create(:bug, fixed: true, environment: FactoryGirl.create(:environment, project: @project))
      end

      before(:each) { ActionMailer::Base.deliveries.clear }

      it "should send an email to the users who have signed up to be notified of deploys" do
        @bug.update_attribute :notify_on_deploy, [@user1, @user2].map(&:id)
        @bug.update_attribute :fix_deployed, true

        expect(ActionMailer::Base.deliveries.size).to eql(2)
        expect(ActionMailer::Base.deliveries.map(&:to).flatten.sort).to eql([@user1.email, @user2.email])
        ActionMailer::Base.deliveries.each { |d| expect(d.subject).to include('was deployed') }
      end
    end
  end

  context "[auto-watching]" do
    before :each do
      @user = FactoryGirl.create(:user)
      @bug  = FactoryGirl.create(:bug)
      FactoryGirl.create :membership, user: @user, project: @bug.environment.project
    end

    it "should automatically have the assignee watch the bug when assigned" do
      @user.watches.destroy_all
      @bug.update_attribute :assigned_user, @user
      expect(@user.watches.count).to eql(1)
      expect(@user.watches(true).first.bug_id).to eql(@bug.id)
    end

    it "should do nothing if the assignee is already watching the bug" do
      @user.watches.destroy_all
      FactoryGirl.create :watch, user: @user, bug: @bug
      @bug.update_attribute :assigned_user, @user
      expect(@user.watches.count).to eql(1)
      expect(@user.watches(true).first.bug_id).to eql(@bug.id)
    end
  end

  describe "#blamed_users" do
    before :all do
      @bug = FactoryGirl.create(:bug)

      @sean  = FactoryGirl.create(:user, first_name: 'Sean', last_name: 'Sorrell', username: 'ssorrell')
      @karen = FactoryGirl.create(:user, first_name: 'Karen', last_name: 'Liu', username: 'karen')
      @lewis = FactoryGirl.create(:user, first_name: 'mike', last_name: 'lewis', username: 'lewis')

      [@sean, @karen, @lewis].each do |user|
        FactoryGirl.create :membership, user: user, project: @bug.environment.project
      end
    end

    before(:each) do
      allow(@bug).to receive(:blamed_commit).and_return(double('Git::Commit'))
      allow(@bug.blamed_commit).to receive(:author).and_return(double('Git::Author'))
    end

    it "should return the commit author email for known emails" do
      allow(@bug.blamed_commit.author).to receive(:email).and_return(@sean.email)
      allow(@bug.blamed_commit.author).to receive(:name).and_return(nil)
      expect(@bug.blamed_users).to eql([@sean.emails.primary.first])
    end

    it "should match a single commit author by name" do
      allow(@bug.blamed_commit.author).to receive(:email).and_return("github+kliu@squareup.com")
      allow(@bug.blamed_commit.author).to receive(:name).and_return("Karen Liu")
      expect(@bug.blamed_users).to eql([@karen.emails.primary.first])
    end

    it "should match multiple commit authors by name" do
      allow(@bug.blamed_commit.author).to receive(:email).and_return("github+ssorrell+lewis@squareup.com")
      allow(@bug.blamed_commit.author).to receive(:name).and_return("Sean Sorrell + Mike Lewis")
      expect(@bug.blamed_users).to eql([@sean.emails.primary.first, @lewis.emails.primary.first])
    end

    it "should match as many commit authors as it can" do
      allow(@bug.blamed_commit.author).to receive(:email).and_return("github+lewis+zach@squareup.com")
      allow(@bug.blamed_commit.author).to receive(:name).and_return("Mike Lewis & Zach Brock")
      expect(@bug.blamed_users).to eql([@lewis.emails.primary.first])
    end

    it "should return an empty array if no matches can be found" do
      allow(@bug.blamed_commit.author).to receive(:email).and_return("github+ne+ek@squareup.com")
      allow(@bug.blamed_commit.author).to receive(:name).and_return("Nolan Evans + Erica Kwan")
      expect(@bug.blamed_users).to be_empty
    end

    it "should use the commit author if the project is sending to unknown emails and there's an author match" do
      @bug.environment.project.sends_emails_outside_team = true
      allow(@bug.blamed_commit.author).to receive(:email).and_return("github+lewis+zach@squareup.com")
      allow(@bug.blamed_commit.author).to receive(:name).and_return("Mike Lewis & Zach Brock")
      expect(@bug.blamed_users).to eql([@lewis.emails.primary.first])
    end

    it "should use the commit email if the project is sending to unknown emails and there's no author match" do
      @bug.environment.project.sends_emails_outside_team = true
      allow(@bug.blamed_commit.author).to receive(:email).and_return("github+ne+ek@squareup.com")
      allow(@bug.blamed_commit.author).to receive(:name).and_return("Nolan Evans + Erica Kwan")
      expect(@bug.blamed_users.size).to eql(1)
      expect(@bug.blamed_users.first).to be_kind_of(Email)
      expect(@bug.blamed_users.first.email).to eql("github+ne+ek@squareup.com")
      expect(@bug.blamed_users.first.user).to be_nil
    end

    it "should not use the commit email if the project is sending to unknown emails but the domain is not trusted" do
      @bug.environment.project.sends_emails_outside_team = true
      @bug.environment.project.trusted_email_domain      = 'paypal.com'
      allow(@bug.blamed_commit.author).to receive(:email).and_return("github+ne+ek@squareup.com")
      allow(@bug.blamed_commit.author).to receive(:name).and_return("Nolan Evans + Erica Kwan")
      expect(@bug.blamed_users).to be_empty
    end

    it "should use the commit email if the project is sending to unknown emails and the domain is trusted" do
      @bug.environment.project.sends_emails_outside_team = true
      @bug.environment.project.trusted_email_domain      = 'squareup.com'
      allow(@bug.blamed_commit.author).to receive(:email).and_return("github+ne+ek@squareup.com")
      allow(@bug.blamed_commit.author).to receive(:name).and_return("Nolan Evans + Erica Kwan")
      expect(@bug.blamed_users.size).to eql(1)
      expect(@bug.blamed_users.first).to be_kind_of(Email)
      expect(@bug.blamed_users.first.email).to eql("github+ne+ek@squareup.com")
      expect(@bug.blamed_users.first.user).to be_nil
    end

    context "[redirection]" do
      before(:each) { Email.redirected.delete_all }

      it "should return a user who has specified that the commit author's emails be redirected to him" do
        allow(@bug.blamed_commit.author).to receive(:email).and_return(@sean.email)
        FactoryGirl.create(:email, email: @sean.email, user: @karen) # Karen took over Sean's exceptions
        expect(@bug.blamed_email).to eql(@karen.email)
      end

      it "should go deeper" do # BWWWWHHHHHHAAAAAAMMMMMMM
        allow(@bug.blamed_commit.author).to receive(:email).and_return(@sean.email)
        FactoryGirl.create(:email, email: @sean.email, user: @karen)  # Karen took over Sean's exceptions
        FactoryGirl.create(:email, email: @karen.email, user: @lewis) # ... then Mike took over Karen's exceptions

        expect(@bug.blamed_email).to eql(@lewis.email)
      end

      it "should give priority to project-specific redirects" do
        erica = FactoryGirl.create(:user, first_name: 'Erica', last_name: 'Kwan', username: 'erica')

        allow(@bug.blamed_commit.author).to receive(:email).and_return(@sean.email)
        FactoryGirl.create(:email, email: @sean.email, user: erica)                                     # Erica took over all of Sean's exceptions
        FactoryGirl.create(:email, email: @sean.email, user: @karen, project: @bug.environment.project) # .. but Karen took over Sean's exceptions *on that project only*
        FactoryGirl.create(:email, email: @karen.email, user: @lewis)                                   # ... then Mike took over *all* of Karen's exceptions

        expect(@bug.blamed_email).to eql(@lewis.email)
      end

      it "raise an exception for circular redirect chains" do
        allow(@bug.blamed_commit.author).to receive(:email).and_return(@sean.email)
        FactoryGirl.create(:email, email: @sean.email, user: @karen)  # Karen took over Sean's exceptions
        FactoryGirl.create(:email, email: @karen.email, user: @lewis) # ... then Mike took over Karen's exceptions
        FactoryGirl.create(:email, email: @lewis.email, user: @sean)  # ... but then Sean took over Mike's exceptions!

        expect { @bug.blamed_email }.to raise_error(/Circular email redirection/)
      end

      it "should email a user's corporate email if they commit with a personal email" do
        allow(@bug.blamed_commit.author).to receive(:email).and_return("karen.liu@gmail.com")

        # Karen has a tendency to commit under her gmail address
        FactoryGirl.create(:email, email: "karen.liu@gmail.com", user: @karen)

        expect(@bug.blamed_email).to eql(@karen.email)
      end
    end
  end

  context "[duplicates]" do
    before(:all) { @env = FactoryGirl.create(:environment) }

    it "should not allow a bug to be marked as duplicate of a bug that's already a duplicate" do
      already_duplicate_bug = FactoryGirl.create(:bug, environment: @env, duplicate_of: FactoryGirl.create(:bug, environment: @env))
      bug                   = FactoryGirl.build(:bug, environment: @env, duplicate_of: already_duplicate_bug)
      expect(bug).not_to be_valid
      expect(bug.errors[:duplicate_of_id]).to eql(["cannot be the duplicate of a bug that’s marked as a duplicate"])
    end

    it "should not allow a bug to be marked as duplicate if another bug is marking this bug as a duplicate" do
      bug              = FactoryGirl.create(:bug, environment: @env)
      duplicate_of_bug = FactoryGirl.create(:bug, environment: @env, duplicate_of: bug)
      bug.duplicate_of = FactoryGirl.create(:bug, environment: @env)
      expect(bug).not_to be_valid
      expect(bug.errors[:duplicate_of_id]).to eql(["cannot be marked as duplicate because other bugs have been marked as duplicates of this bug"])
    end

    it "should allow a bug to NOT be marked as duplicate if another bug is marking this bug as a duplicate" do
      bug = FactoryGirl.create(:bug, environment: @env)
      FactoryGirl.create :bug, environment: @env, duplicate_of: bug
      expect(bug).to be_valid
    end

    it "should not allow a bug's duplicate-of ID to be changed" do
      bug              = FactoryGirl.create(:bug, environment: @env, duplicate_of: FactoryGirl.create(:bug, environment: @env))
      bug.duplicate_of = FactoryGirl.create(:bug, environment: @env)
      expect(bug).not_to be_valid
      expect(bug.errors[:duplicate_of_id]).to eql(["already marked as duplicate of a bug"])
    end

    it "should not allow a bug to be marked as a duplicate of a bug in a different environment" do
      bug              = FactoryGirl.create(:bug, environment: @env)
      foreign_bug      = FactoryGirl.create(:bug)
      bug.duplicate_of = foreign_bug
      expect(bug).not_to be_valid
      expect(bug.errors[:duplicate_of_id]).to eql(["can only be the duplicate of a bug in the same environment"])
    end

    it "should not allow a bug to be un-marked as a duplicate" do
      bug              = FactoryGirl.create(:bug, environment: @env, duplicate_of: FactoryGirl.create(:bug, environment: @env))
      bug.duplicate_of = nil
      expect(bug).not_to be_valid
      expect(bug.errors[:duplicate_of_id]).to eql(["already marked as duplicate of a bug"])
    end

    describe "#mark_as_duplicate!" do
      before(:all) { @env = FactoryGirl.create(:environment) }

      it "should associate the original bug" do
        bug       = FactoryGirl.create(:bug, environment: @env)
        duplicate = FactoryGirl.create(:bug, environment: @env)

        duplicate.mark_as_duplicate! bug
        expect(duplicate.duplicate_of).to eql(bug)
      end

      it "should move all occurrences" do
        bug         = FactoryGirl.create(:bug, environment: @env)
        duplicate   = FactoryGirl.create(:bug, environment: @env)
        occurrences = 5.times.map { FactoryGirl.create :rails_occurrence, bug: duplicate }

        duplicate.mark_as_duplicate! bug
        expect(occurrences.map(&:reload).map(&:bug_id)).to eql([bug.id]*5)
      end
    end
  end

  describe "#page_threshold_tripped?" do
    before :all do
      @bug = FactoryGirl.create(:bug, page_threshold: 10, page_period: 1.minute, page_last_tripped_at: 2.minutes.ago)
    end

    it "should return false if a threshold or period has not been configured" do
      expect(FactoryGirl.build(:bug, page_threshold: 10, page_period: nil)).not_to be_page_threshold_tripped
      expect(FactoryGirl.build(:bug, page_threshold: nil, page_period: 1.minute)).not_to be_page_threshold_tripped
    end

    it "should return false if the threshold has not yet been exceeded within the period" do
      FactoryGirl.create_list :rails_occurrence, 9, bug: @bug
      expect(@bug).not_to be_page_threshold_tripped
    end

    it "should return true if the threshold has been exceeded within the period" do
      FactoryGirl.create_list :rails_occurrence, 10, bug: @bug
      expect(@bug).to be_page_threshold_tripped
    end

    it "should return false if the threshold was tripped within the last period" do
      FactoryGirl.create_list :rails_occurrence, 10, bug: @bug
      @bug.page_last_tripped_at = 45.seconds.ago
      expect(@bug).not_to be_page_threshold_tripped
    end
  end
end
