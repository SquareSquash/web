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

describe User do
  describe "#gravatar" do
    it "should return the correct Gravatar URL" do
      user = FactoryGirl.create(:user, username: 'gravatar-test')
      Email.where(id: user.emails.first.id).update_all email: 'gravatar-test@example.com'
      user.reload.gravatar.should eql('http://www.gravatar.com/avatar/db77ada176df02f0a82b5655c95a2705')
    end if Squash::Configuration.authentication.strategy == 'ldap'

    it "should return the correct Gravatar URL" do
      FactoryGirl.create(:user, email_address: 'gravatar@example.com').gravatar.
          should eql('http://www.gravatar.com/avatar/0cef130e32e054dd516c99e5181d30c4')
    end if Squash::Configuration.authentication.strategy == 'password'
  end

  describe "#name" do
    it "should return a user's full name" do
      FactoryGirl.create(:user).name.should eql("Sancho Sample")
    end

    it "should handle just a first name" do
      FactoryGirl.create(:user, last_name: nil).name.should eql("Sancho")
    end

    it "should handle just a last name" do
      FactoryGirl.create(:user, first_name: nil).name.should eql("Sample")
    end

    it "should return the username if no name is given" do
      user = FactoryGirl.create(:user, first_name: nil, last_name: nil)
      user.name.should eql(user.username)
    end
  end

  describe "#email" do
    it "should return the user's corporate email address" do
      FactoryGirl.create(:user, username: 'email-test').email.should eql("email-test@#{Squash::Configuration.mailer.domain}")
    end if Squash::Configuration.authentication.strategy == 'ldap'

    it "should return the user's corporate email address" do
      FactoryGirl.create(:user, email_address: 'email-test@example.com').email.should eql("email-test@example.com")
    end if Squash::Configuration.authentication.strategy == 'password'
  end

  describe "#distinguished_name" do
    it "should return a user's LDAP DN" do
      FactoryGirl.create(:user, username: 'dn-test').distinguished_name.should eql("uid=dn-test,#{Squash::Configuration.authentication.ldap.tree_base}")
    end
  end if Squash::Configuration.authentication.strategy == 'ldap'

  describe "#role" do
    context "[Project]" do
      before(:all) { @project = FactoryGirl.create(:project) }
      before(:each) { @user = FactoryGirl.create(:user) }

      it "should return :owner for a project owner" do
        @project.update_attribute :owner, @user
        @user.role(@project).should eql(:owner)
      end

      it "should return :admin for a project admin" do
        FactoryGirl.create :membership, user: @user, project: @project, admin: true
        @user.role(@project).should eql(:admin)
      end

      it "should return :member for a project member" do
        FactoryGirl.create :membership, user: @user, project: @project, admin: false
        @user.role(@project).should eql(:member)
      end

      it "should return nil otherwise" do
        @user.role(@project).should be_nil
      end
    end

    context "[Comment]" do
      before(:all) { @comment = FactoryGirl.create(:comment) }

      it "should return :creator for the comment creator" do
        @comment.user.role(@comment).should eql(:creator)
      end

      it "should return :owner for a project owner" do
        @comment.bug.environment.project.owner.role(@comment).should eql(:owner)
      end

      it "should return :admin for a project admin" do
        membership = FactoryGirl.create(:membership, project: @comment.bug.environment.project, admin: true)
        membership.user.role(@comment).should eql(:admin)
      end

      it "should return nil for a project member" do
        membership = FactoryGirl.create(:membership, project: @comment.bug.environment.project, admin: false)
        membership.user.role(@comment).should be_nil
      end

      it "should return nil otherwise" do
        FactoryGirl.create(:user).role(@comment).should be_nil
      end
    end
  end

  context '[hooks]' do
    it "should downcase the username" do
      FactoryGirl.create(:user, username: 'TestCase').username.should eql('testcase')
    end
  end

  describe "#watches?" do
    it "should return a Watch for a watched bug" do
      watch = FactoryGirl.create(:watch)
      watch.user.watches?(watch.bug).should eql(watch)
    end

    it "should return nil for an unwatched bug" do
      FactoryGirl.create(:user).watches?(FactoryGirl.create(:bug)).should be_nil
    end
  end

  describe "#email" do
    before :all do
      @user  = FactoryGirl.create(:user)
      @email = FactoryGirl.create(:email, user: @user)
    end

    it "should return the primary email" do
      @user.email.should eql(@user.emails.where(primary: true).first.email)
    end
  end

  describe "[primary email]" do
    it "should automatically create one" do
      user = FactoryGirl.create(:user, username: 'primary_email_test')
      user.emails.size.should eql(1)
      user.emails.first.email.should eql("primary_email_test@#{Squash::Configuration.mailer.domain}")
      user.emails.first.should be_primary
    end if Squash::Configuration.authentication.strategy == 'ldap'

    it "should automatically create one" do
      user = FactoryGirl.create(:user, username: 'primary_email_test', email_address: 'primary@example.com')
      user.emails.size.should eql(1)
      user.emails.first.email.should eql("primary@example.com")
      user.emails.first.should be_primary
    end if Squash::Configuration.authentication.strategy == 'password'

    it "should require a unique email" do
      FactoryGirl.create :user, email_address: 'taken@example.com'
      user = FactoryGirl.build(:user, email_address: 'taken@example.com')
      user.should_not be_valid
      user.errors[:email_address].should eql(['already taken'])
    end if Squash::Configuration.authentication.strategy == 'password'
  end

  context "[password-based authentication]" do
    it "should encrypt the user's password on save" do
      FactoryGirl.create(:user).crypted_password.should_not be_nil
    end

    describe "#authentic?" do
      it "should return true for valid credentials and false for invalid credentials" do
        user = FactoryGirl.create(:user, password: 'developers developers developers developers')
        user.authentic?('developers developers developers').should be_false
        user.authentic?('developers developers developers developers').should be_true
      end
    end
  end if Squash::Configuration.authentication.strategy == 'password'
end
