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

describe Email do
  context "[validations]" do
    it "should not allow a primary email to be downgraded" do
      email         = FactoryGirl.create(:email, primary: true)
      email.primary = false
      expect(email).not_to be_valid
      expect(email.errors[:primary]).to eql(['cannot be unset without setting another email as primary'])
    end

    it "should only allow one user to assume redirect ownership of another's primary email" do
      old_user = FactoryGirl.create(:user)
      FactoryGirl.create :email, email: old_user.email
      email = FactoryGirl.build(:email, email: old_user.email)
      expect(email).not_to be_valid
      expect(email.errors[:email]).to eql(['is already being handled by someone else'])
    end

    it "should allow a user to assume ownership of an otherwise unknown email" do
      email = FactoryGirl.build(:email, email: 'heretoforeunknown@email.com')
      expect(email).to be_valid
    end

    it "should not allow a user to assume redirect ownership of his/hera primary email" do
      user  = FactoryGirl.create(:user)
      email = FactoryGirl.build(:email, email: user.email, user: user)
      expect(email).not_to be_valid
      expect(email.errors[:email]).to eql(['is already your main email address'])
    end

    it "should not allow a user to assume redirect ownership of an email twice" do
      old_user  = FactoryGirl.create(:user)
      redirect1 = FactoryGirl.create(:email, email: old_user.email)
      redirect2 = FactoryGirl.build(:email, email: old_user.email, user: redirect1.user)
      expect(redirect2).not_to be_valid
      expect(redirect2.errors[:email]).to include('is already being handled by someone else')
    end

    it "should not allow a user to assume redirect ownership of an email within a project that he has global redirect ownership of" do
      user          = FactoryGirl.create(:user)
      global_email  = FactoryGirl.create(:email, user: user)
      project_email = FactoryGirl.build(:email, user: user, email: global_email.email, project: FactoryGirl.create(:membership, user: user).project)
      expect(project_email).not_to be_valid
      expect(project_email.errors[:email]).to eql(['is already globally handled by you'])
    end

    it "should allow a user to assume redirect ownership of an email within a project that someone else has global redirect ownership of" do
      user          = FactoryGirl.create(:user)
      global_email  = FactoryGirl.create(:email)
      project_email = FactoryGirl.build(:email, user: user, email: global_email.email, project: FactoryGirl.create(:membership, user: user).project)
      expect(project_email).to be_valid
    end

    it "should not allow a user to assume redirect ownership of an email for a project he is not a member of" do
      email = FactoryGirl.build(:email, project: FactoryGirl.create(:project))
      expect(email).not_to be_valid
      expect(email.errors[:project_id]).to eql(['not a member'])
    end

    it "should remove project-specific redirect ownership for emails the user claims global ownership of" do
      user          = FactoryGirl.create(:user)
      project_email = FactoryGirl.create(:email, user: user, project: FactoryGirl.create(:membership, user: user).project)
      global_email  = FactoryGirl.create(:email, email: project_email.email, user: user)
      expect(user.emails.redirected.pluck(:id)).to eql([global_email.id])
    end

    it "should not remove project-specific redirect ownership for emails the another user claims global ownership of" do
      user          = FactoryGirl.create(:user)
      project_email = FactoryGirl.create(:email, user: user, project: FactoryGirl.create(:membership, user: user).project)
      global_email  = FactoryGirl.create(:email, email: project_email.email)
      expect(user.emails.redirected.pluck(:id)).to eql([project_email.id])
    end
  end

  context "[hooks]" do
    it "should downgrade another primary email when set as primary" do
      user  = FactoryGirl.create(:user)
      email = user.emails.first
      expect(email).to be_primary

      FactoryGirl.create(:email, user: user, primary: true)
      expect(email.reload).not_to be_primary
    end
  end
end
