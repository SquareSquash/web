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

describe Email do
  context "[validations]" do
    it "should not allow a primary email to be downgraded" do
      email         = FactoryGirl.create(:email, primary: true)
      email.primary = false
      email.should_not be_valid
      email.errors[:primary].should eql(['cannot be unset without setting another email as primary'])
    end

    it "should only allow one user to assume redirect ownership of another's primary email" do
      old_user = FactoryGirl.create(:user)
      FactoryGirl.create :email, email: old_user.email
      email = FactoryGirl.build(:email, email: old_user.email)
      email.should_not be_valid
      email.errors[:email].should eql(['is already being handled by someone else'])
    end

    it "should allow a user to assume ownership of an otherwise unknown email" do
      email = FactoryGirl.build(:email, email: 'heretoforeunknown@email.com')
      email.should be_valid
    end

    it "should not allow a user to assume redirect ownership of his/hera primary email" do
      user  = FactoryGirl.create(:user)
      email = FactoryGirl.build(:email, email: user.email, user: user)
      email.should_not be_valid
      email.errors[:email].should eql(['is already your main email address'])
    end

    it "should not allow a user to assume redirect ownership of an email twice" do
      old_user  = FactoryGirl.create(:user)
      redirect1 = FactoryGirl.create(:email, email: old_user.email)
      redirect2 = FactoryGirl.build(:email, email: old_user.email, user: redirect1.user)
      redirect2.should_not be_valid
      redirect2.errors[:email].should include('is already being handled by someone else')
    end

    it "should not allow a user to assume redirect ownership of an email within a project that he has global redirect ownership of" do
      user          = FactoryGirl.create(:user)
      global_email  = FactoryGirl.create(:email, user: user)
      project_email = FactoryGirl.build(:email, user: user, email: global_email.email, project: FactoryGirl.create(:membership, user: user).project)
      project_email.should_not be_valid
      project_email.errors[:email].should eql(['is already globally handled by you'])
    end

    it "should allow a user to assume redirect ownership of an email within a project that someone else has global redirect ownership of" do
      user          = FactoryGirl.create(:user)
      global_email  = FactoryGirl.create(:email)
      project_email = FactoryGirl.build(:email, user: user, email: global_email.email, project: FactoryGirl.create(:membership, user: user).project)
      project_email.should be_valid
    end

    it "should not allow a user to assume redirect ownership of an email for a project he is not a member of" do
      email = FactoryGirl.build(:email, project: FactoryGirl.create(:project))
      email.should_not be_valid
      email.errors[:project_id].should eql(['not a member'])
    end

    it "should remove project-specific redirect ownership for emails the user claims global ownership of" do
      user          = FactoryGirl.create(:user)
      project_email = FactoryGirl.create(:email, user: user, project: FactoryGirl.create(:membership, user: user).project)
      global_email  = FactoryGirl.create(:email, email: project_email.email, user: user)
      user.emails.redirected.pluck(:id).should eql([global_email.id])
    end

    it "should not remove project-specific redirect ownership for emails the another user claims global ownership of" do
      user          = FactoryGirl.create(:user)
      project_email = FactoryGirl.create(:email, user: user, project: FactoryGirl.create(:membership, user: user).project)
      global_email  = FactoryGirl.create(:email, email: project_email.email)
      user.emails.redirected.pluck(:id).should eql([project_email.id])
    end
  end

  context "[hooks]" do
    it "should downgrade another primary email when set as primary" do
      user  = FactoryGirl.create(:user)
      email = user.emails.first
      email.should be_primary

      FactoryGirl.create(:email, user: user, primary: true)
      email.reload.should_not be_primary
    end
  end
end
