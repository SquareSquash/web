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

describe User do
  describe "#gravatar" do
    it "should return the correct Gravatar URL" do
      user = FactoryGirl.create(:user, username: 'gravatar-test')
      Email.where(id: user.emails.first.id).update_all email: 'gravatar-test@example.com'
      expect(user.reload.gravatar).to eql('http://www.gravatar.com/avatar/db77ada176df02f0a82b5655c95a2705')
    end if Squash::Configuration.authentication.strategy == 'ldap'

    it "should return the correct Gravatar URL" do
      expect(FactoryGirl.create(:user, email_address: 'gravatar@example.com').gravatar).
          to eql('http://www.gravatar.com/avatar/0cef130e32e054dd516c99e5181d30c4')
    end if Squash::Configuration.authentication.strategy == 'password'
  end

  describe "#name" do
    it "should return a user's full name" do
      expect(FactoryGirl.create(:user).name).to eql("Sancho Sample")
    end

    it "should handle just a first name" do
      expect(FactoryGirl.create(:user, last_name: nil).name).to eql("Sancho")
    end

    it "should handle just a last name" do
      expect(FactoryGirl.create(:user, first_name: nil).name).to eql("Sample")
    end

    it "should return the username if no name is given" do
      user = FactoryGirl.create(:user, first_name: nil, last_name: nil)
      expect(user.name).to eql(user.username)
    end
  end

  describe "#email" do
    it "should return the user's corporate email address" do
      expect(FactoryGirl.create(:user, username: 'email-test').email).to eql("email-test@#{Squash::Configuration.mailer.domain}")
    end if Squash::Configuration.authentication.strategy == 'ldap'

    it "should return the user's corporate email address" do
      expect(FactoryGirl.create(:user, email_address: 'email-test@example.com').email).to eql("email-test@example.com")
    end if Squash::Configuration.authentication.strategy == 'password'
  end

  describe "#distinguished_name" do
    it "should return a user's LDAP DN" do
      expect(FactoryGirl.create(:user, username: 'dn-test').distinguished_name).to eql("uid=dn-test,#{Squash::Configuration.authentication.ldap.tree_base}")
    end
  end if Squash::Configuration.authentication.strategy == 'ldap'

  describe "#role" do
    context "[Project]" do
      before(:all) { @project = FactoryGirl.create(:project) }
      before(:each) { @user = FactoryGirl.create(:user) }

      it "should return :owner for a project owner" do
        @project.update_attribute :owner, @user
        expect(@user.role(@project)).to eql(:owner)
      end

      it "should return :admin for a project admin" do
        FactoryGirl.create :membership, user: @user, project: @project, admin: true
        expect(@user.role(@project)).to eql(:admin)
      end

      it "should return :member for a project member" do
        FactoryGirl.create :membership, user: @user, project: @project, admin: false
        expect(@user.role(@project)).to eql(:member)
      end

      it "should return nil otherwise" do
        expect(@user.role(@project)).to be_nil
      end
    end

    context "[Comment]" do
      before(:all) { @comment = FactoryGirl.create(:comment) }

      it "should return :creator for the comment creator" do
        expect(@comment.user.role(@comment)).to eql(:creator)
      end

      it "should return :owner for a project owner" do
        expect(@comment.bug.environment.project.owner.role(@comment)).to eql(:owner)
      end

      it "should return :admin for a project admin" do
        membership = FactoryGirl.create(:membership, project: @comment.bug.environment.project, admin: true)
        expect(membership.user.role(@comment)).to eql(:admin)
      end

      it "should return nil for a project member" do
        membership = FactoryGirl.create(:membership, project: @comment.bug.environment.project, admin: false)
        expect(membership.user.role(@comment)).to be_nil
      end

      it "should return nil otherwise" do
        expect(FactoryGirl.create(:user).role(@comment)).to be_nil
      end
    end
  end

  context '[hooks]' do
    it "should downcase the username" do
      expect(FactoryGirl.create(:user, username: 'TestCase').username).to eql('testcase')
    end
  end

  describe "#watches?" do
    it "should return a Watch for a watched bug" do
      watch = FactoryGirl.create(:watch)
      expect(watch.user.watches?(watch.bug)).to eql(watch)
    end

    it "should return nil for an unwatched bug" do
      expect(FactoryGirl.create(:user).watches?(FactoryGirl.create(:bug))).to be_nil
    end
  end

  describe "#email" do
    before :all do
      @user  = FactoryGirl.create(:user)
      @email = FactoryGirl.create(:email, user: @user)
    end

    it "should return the primary email" do
      expect(@user.email).to eql(@user.emails.where(primary: true).first.email)
    end
  end

  describe "[primary email]" do
    it "should automatically create one" do
      user = FactoryGirl.create(:user, username: 'primary_email_test')
      expect(user.emails.size).to eql(1)
      expect(user.emails.first.email).to eql("primary_email_test@#{Squash::Configuration.mailer.domain}")
      expect(user.emails.first).to be_primary
    end if Squash::Configuration.authentication.strategy == 'ldap'

    it "should automatically create one" do
      user = FactoryGirl.create(:user, username: 'primary_email_test', email_address: 'primary@example.com')
      expect(user.emails.size).to eql(1)
      expect(user.emails.first.email).to eql("primary@example.com")
      expect(user.emails.first).to be_primary
    end if Squash::Configuration.authentication.strategy == 'password'

    it "should require a unique email" do
      FactoryGirl.create :user, email_address: 'taken@example.com'
      user = FactoryGirl.build(:user, email_address: 'taken@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:email_address]).to eql(['already taken'])
    end if Squash::Configuration.authentication.strategy == 'password'
  end

  context "[password-based authentication]" do
    it "should encrypt the user's password on save" do
      expect(FactoryGirl.create(:user).crypted_password).not_to be_nil
    end

    describe "#authentic?" do
      it "should return true for valid credentials and false for invalid credentials" do
        user = FactoryGirl.create(:user, password: 'developers developers developers developers')
        expect(user.authentic?('developers developers developers')).to be_false
        expect(user.authentic?('developers developers developers developers')).to be_true
      end
    end
  end if Squash::Configuration.authentication.strategy == 'password'
end
