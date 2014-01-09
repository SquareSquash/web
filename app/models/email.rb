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

# An email address for a {User}. These records are principally used to ensure
# that correct user is notified when the VCS blame function gives us an email
# address (that may not be the User's corporate email address).
#
# This model can also be used to give "ownership" of a (presumably former)
# User's email notifications to a different User. For example, if bob@acme.com
# has left the company, and jeff@acme.com has been tasked to take over Bob's
# code, Jeff can add bob@acme.com to his account. Then, any bugs for which
# bob@acme.com is to blame will be rerouted to jeff@acme.com.
#
# This behavior chains, as well -- if Jeff then leaves the company, and
# jan@acme.com takes over for jeff@acme.com, she'll also get Bob's emails.
#
# In order for this to work, there is a uniqueness constraint on `email` and
# `primary`. That is, only Jeff can have jeff@acme.com be his primary address,
# and only Bob can have jeff@acme.com as a non-primary (redirecting) address.
# If Bob changed teams and Mel was to take over Bob's old exceptions, Bob
# would have to relinquish jeff@acme.com before Mel could add it.
#
# When a user signs up, a "primary" Email record is automatically created for
# them with their corporate email address. This email will be used by Squash
# for any email notifications, regardless of the VCS-blamed email.
#
# Associations
# ------------
#
# |           |                                                                          |
# |:----------|:-------------------------------------------------------------------------|
# | `user`    | The {User} who should be notified when this email is blamed.             |
# | `project` | If set, the email will only apply for emails relating to this {Project}. |
#
# Properties
# ----------
#
#
# |           |                                                                           |
# |:----------|:--------------------------------------------------------------------------|
# | `email`   | The email address.                                                        |
# | `primary` | If `true`, this is the email address Squash will use to contact the User. |

class Email < ActiveRecord::Base
  belongs_to :user, inverse_of: :emails
  belongs_to :project, inverse_of: :emails

  validates :email,
            presence:   true,
            email:      true,
            uniqueness: {case_sensitive: false, scope: [:project_id, :primary]}
  validates :user,
            presence: true
  validate :one_primary_email
  validate :cant_redirect_your_own_email
  validate :project_emails_cant_be_primary
  validate :cannot_locally_redirect_gobally_redirected_email
  validate :user_must_be_member_of_project

  after_save :one_primary_email_per_user
  after_save :delete_locally_redirected_emails, if: :global?

  attr_readonly :email

  scope :by_email, ->(email) { email ? where('LOWER(email) = ?', email.downcase) : where('FALSE') }
  scope :global, -> { where(project_id: nil) }
  scope :project_specific, -> { where('project_id IS NOT NULL') }
  scope :primary, -> { where(primary: true) }
  scope :redirected, -> { where(primary: false) }

  # @return [User, nil] The User whose primary email is this email address, or
  #   `nil` if this is a primary email, or if no User has this email as his/her
  #   primary.

  def source
    return nil if primary?
    return Email.primary.by_email(email).first.try!(:user)
  end

  # @return [true, false] `true` if this is a global email redirection, or
  #   `false` if this is a project-specific redirection or a primary email.
  def global?() !primary? && project_id.nil? end

  # @private
  def to_param() email end

  # @private
  def as_json(options=nil)
    options ||= {}
    options[:except] = Array.wrap(options[:except])
    options[:except] << :id << :user_id

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :source

    super options
  end

  private

  def one_primary_email
    errors.add(:primary, :must_be_set) if primary_changed? && !primary?
  end

  def one_primary_email_per_user
    return unless primary && primary_changed?
    user.emails.where('id != ?', id).update_all(primary: false)
  end

  def cant_redirect_your_own_email
    errors.add(:email, :is_your_primary) if !primary? && email == user.email
  end

  def project_emails_cant_be_primary
    errors.add(:primary, :not_allowed) if primary? && project_id
  end

  def cannot_locally_redirect_gobally_redirected_email
    errors.add(:email, :has_global_redirect) if user.emails.redirected.global.by_email(email).any?
  end

  def user_must_be_member_of_project
    errors.add(:project_id, :not_a_member) if project_id && Membership.for(user_id, project_id).empty?
  end

  def delete_locally_redirected_emails
    user.emails.project_specific.by_email(email).delete_all
  end
end
