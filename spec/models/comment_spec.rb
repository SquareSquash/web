# encoding: utf-8

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

describe Comment do
  context "[database rules]" do
    it "should set number sequentially for a given bug" do
      bug1  = FactoryGirl.create(:bug)
      bug2  = FactoryGirl.create(:bug)
      user1 = bug1.environment.project.owner
      user2 = bug2.environment.project.owner

      comment1_1 = FactoryGirl.create(:comment, bug: bug1, user: user1)
      comment1_2 = FactoryGirl.create(:comment, bug: bug1, user: user1)
      comment2_1 = FactoryGirl.create(:comment, bug: bug2, user: user2)
      comment2_2 = FactoryGirl.create(:comment, bug: bug2, user: user2)

      comment1_1.number.should eql(1)
      comment1_2.number.should eql(2)
      comment2_1.number.should eql(1)
      comment2_2.number.should eql(2)
    end

    it "should not reuse deleted numbers" do
      #bug = FactoryGirl.create(:bug)
      #FactoryGirl.create :comment, bug: bug
      #FactoryGirl.create(:comment, bug: bug).destroy
      #FactoryGirl.create(:comment, bug: bug).number.should eql(3)
      #TODO get this part of the spec to work (for URL-resource identity integrity)

      bug = FactoryGirl.create(:bug)
      FactoryGirl.create :comment, bug: bug, user: bug.environment.project.owner
      c = FactoryGirl.create(:comment, bug: bug, user: bug.environment.project.owner)
      FactoryGirl.create :comment, bug: bug, user: bug.environment.project.owner
      c.destroy
      FactoryGirl.create(:comment, bug: bug, user: bug.environment.project.owner).number.should eql(4)
    end
  end

  context "[validations]" do
    it "should only allow permitted users to leave comments" do
      comment = FactoryGirl.build(:comment, bug: FactoryGirl.create(:bug))
      comment.should_not be_valid
      comment.errors[:bug_id].should eql(["You don’t have permission to comment on this bug."])
    end
  end

  context "[events]" do
    it "should create an event when created" do
      comment = FactoryGirl.create(:comment)
      event   = comment.bug.events.last
      event.kind.should eql('comment')
      event.data['comment_id'].should eql(comment.id)
      event.user.should eql(comment.user)
    end

    it "should destroy related events when deleted" do
      comment = FactoryGirl.create(:comment)
      event   = comment.bug.events.last

      FactoryGirl.create(:comment, bug: comment.bug, user: comment.user)
      red_herring = comment.bug.events(true).last
      comment.destroy
      -> { event.reload }.should raise_error(ActiveRecord::RecordNotFound)
      -> { red_herring.reload }.should_not raise_error
    end
  end

  context "[emails]" do
    before :all do
      @project        = FactoryGirl.create(:project)
      @assigned       = FactoryGirl.create(:membership, project: @project, send_comment_emails: true).user
      @prev_commenter = FactoryGirl.create(:membership, project: @project, send_comment_emails: true).user
      @cur_commenter  = FactoryGirl.create(:membership, project: @project, send_comment_emails: true).user
    end

    before :each do
      @bug = FactoryGirl.create(:bug, environment: FactoryGirl.create(:environment, project: @project), assigned_user: @assigned)
      FactoryGirl.create :comment, bug: @bug, user: @prev_commenter
      ActionMailer::Base.deliveries.clear
    end

    it "should send an email to the assigned user and all previous commenters when someone comments on a bug" do
      FactoryGirl.create :comment, bug: @bug, user: @cur_commenter
      ActionMailer::Base.deliveries.size.should eql(2)
      ActionMailer::Base.deliveries.map(&:to).flatten.sort.should eql([@assigned.email, @prev_commenter.email])
      ActionMailer::Base.deliveries.each { |d| d.subject.should include("A comment has been added") }
    end

    it "should not send an email to the assigned user if the assigned user was the commenter" do
      FactoryGirl.create :comment, bug: @bug, user: @assigned
      ActionMailer::Base.deliveries.size.should eql(1)
      ActionMailer::Base.deliveries.first.to.should eql([@prev_commenter.email])
      ActionMailer::Base.deliveries.first.subject.should include("A comment has been added")
    end

    it "should not send an email to the author even if the author has previously commented" do
      FactoryGirl.create :comment, bug: @bug, user: @prev_commenter
      ActionMailer::Base.deliveries.size.should eql(1)
      ActionMailer::Base.deliveries.first.to.should eql([@assigned.email])
      ActionMailer::Base.deliveries.first.subject.should include("A comment has been added")
    end

    it "should send only one email to the assigned user if the assigned user has previously commented on the bug" do
      FactoryGirl.create :comment, bug: @bug, user: @assigned
      ActionMailer::Base.deliveries.clear

      FactoryGirl.create :comment, bug: @bug, user: @cur_commenter
      ActionMailer::Base.deliveries.size.should eql(2)
      ActionMailer::Base.deliveries.map(&:to).flatten.sort.should eql([@assigned.email, @prev_commenter.email])
      ActionMailer::Base.deliveries.each { |d| d.subject.should include("A comment has been added") }
    end

    it "should not send an email if the environment is configured not to send emails" do
      @bug.environment.update_attribute :sends_emails, false
      FactoryGirl.create :comment, bug: @bug, user: @cur_commenter
      ActionMailer::Base.deliveries.should be_empty
    end

    it "should not send an email if the recipient has turned off comment emails (assigned user)" do
      Membership.for(@assigned, @project).first.update_attribute :send_comment_emails, false
      FactoryGirl.create :comment, bug: @bug, user: @cur_commenter
      ActionMailer::Base.deliveries.size.should eql(1)
      ActionMailer::Base.deliveries.first.to.should eql([@prev_commenter.email])
      ActionMailer::Base.deliveries.first.subject.should include("A comment has been added")
    end

    it "should not send an email if the recipient has turned off comment emails (commenter)" do
      Membership.for(@assigned, @project).first.update_attribute :send_comment_emails, true
      Membership.for(@prev_commenter, @project).first.update_attribute :send_comment_emails, false
      FactoryGirl.create :comment, bug: @bug, user: @cur_commenter
      ActionMailer::Base.deliveries.size.should eql(1)
      ActionMailer::Base.deliveries.first.to.should eql([@assigned.email])
      ActionMailer::Base.deliveries.first.subject.should include("A comment has been added")
    end
  end

  context "[auto-watching]" do
    before :all do
      @user = FactoryGirl.create(:user)
      @bug  = FactoryGirl.create(:bug)
      FactoryGirl.create :membership, user: @user, project: @bug.environment.project
    end

    it "should automatically have the author watch the bug" do
      @user.watches.destroy_all
      FactoryGirl.create :comment, user: @user, bug: @bug
      @user.watches.count.should eql(1)
      @user.watches(true).first.bug_id.should eql(@bug.id)
    end

    it "should do nothing if the author is already watching the bug" do
      @user.watches.destroy_all
      FactoryGirl.create :watch, user: @user, bug: @bug
      FactoryGirl.create :comment, user: @user, bug: @bug
      @user.watches.count.should eql(1)
      @user.watches(true).first.bug_id.should eql(@bug.id)
    end
  end
end
