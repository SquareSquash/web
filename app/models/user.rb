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

require 'digest/sha2'

# A user account on this websites. Users have {Membership Memberships} to one or
# more {Project Projects}, allowing them to view and manage {Bug Bugs} in that
# project.
#
# Users can be authenticated by one of several authentication schemes. The value
# in `config/environments/common/authentication.yml` determines which of the
# authentication modules is mixed into this model.
#
# User avatars can come from people.json, or otherwise their {#gravatar}.
#
# Associations
# ============
#
# |                           |                                                                                  |
# |:--------------------------|:---------------------------------------------------------------------------------|
# | `memberships`             | The {Membership Memberships} involving this user.                                |
# | `member_projects`         | The {Project Projects} this user is a member of.                                 |
# | `owned_projects`          | The {Project Projects} this user is the owner of.                                |
# | `watches`                 | The {Watch Watches} representing Bugs this User is watching.                     |
# | `user_events`             | The denormalized {UserEvent UserEvents} from Bugs this User is watching.         |
# | `emails`                  | The blame {Email Emails} that are associated with this User.                     |
# | `notification_thresholds` | The {NotificationThreshold NotificationThresholds} this User has placed on Bugs. |
#
# Properties
# ==========
#
# |            |                                 |
# |:-----------|:--------------------------------|
# | `username` | The LDAP username of this user. |
#
# Metadata
# ========
#
# |              |                        |
# |:-------------|:-----------------------|
# | `first_name` | The user's first name. |
# | `last_name`  | The user's last name.  |

class User < ActiveRecord::Base
  # @private
  class_attribute :people_json

  has_many :assigned_bugs, class_name: 'Bug', foreign_key: 'assigned_user_id', dependent: :nullify, inverse_of: :assigned_user
  has_many :comments, dependent: :nullify, inverse_of: :user
  has_many :events, dependent: :nullify, inverse_of: :user
  has_many :memberships, dependent: :delete_all, inverse_of: :user
  has_many :member_projects, through: :memberships, source: :project
  has_many :owned_projects, class_name: 'Project', foreign_key: 'owner_id', dependent: :restrict_with_exception, inverse_of: :owner
  has_many :watches, dependent: :delete_all, inverse_of: :user
  has_many :user_events, dependent: :delete_all, inverse_of: :user
  has_many :emails, dependent: :delete_all, inverse_of: :user
  has_many :notification_thresholds, dependent: :delete_all, inverse_of: :user

  attr_readonly :username

  include HasMetadataColumn
  has_metadata_column(
      first_name: {length: {maximum: 100}, allow_nil: true},
      last_name:  {length: {maximum: 100}, allow_nil: true}
  )

  validates :username,
            presence:   true,
            length:     {maximum: 50},
            format:     {with: /\A[a-z0-9_\-]+\z/},
            uniqueness: true

  before_validation(on: :create) { |obj| obj.username = obj.username.downcase if obj.username }
  after_create :create_primary_email

  set_nil_if_blank :first_name, :last_name

  scope :prefix, ->(query) { where("LOWER(username) LIKE ?", query.downcase.gsub(/[^a-z0-9\-_]/, '') + '%') }

  include "#{Squash::Configuration.authentication.strategy}_authentication".camelize.constantize

  # @return [String] The user's full name, or as much of it as available, or the
  #   `username`.

  def name
    return username unless first_name.present? || last_name.present?
    I18n.t('models.user.name', first_name: first_name, last_name: last_name).strip
  end

  # @return [String] The user's company email address.

  def email
    @email ||= (emails.loaded? ? emails.detect(&:primary).email : emails.primary.first.email)
  end

  # @return [String] The URL to the user's Gravatar.

  def gravatar
    "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest email}"
  end

  # Returns a symbol describing a user's role in relation to a model object;
  # used for strong attribute roles.
  #
  # @param [ActiveRecord::Base] object A model instance.
  # @return [Symbol, nil] The user's role, or `nil` if the user has no
  #   permissions. Possible values are `:creator`, `:owner`, `:admin`,
  #   `:member`, and `nil`.

  def role(object)
    object = object.environment.project if object.kind_of?(Bug)

    case object
      when Project
        return :owner if object.owner_id == id
        membership = memberships.where(project_id: object.id).first
        return nil unless membership
        return :admin if membership.admin?
        return :member
      when Comment
        return :creator if object.user_id == id
        return :owner if object.bug.environment.project.owner_id == id
        membership = memberships.where(project_id: object.bug.environment.project_id).first
        return :admin if membership.try!(:admin?)
        return nil
      else
        return nil
    end
  end

  # Returns whether or not a User is watching a {Bug}.
  #
  # @param [Bug] bug A Bug.
  # @return [Watch, false] Whether or not the User is watching that Bug.
  # @see Watch

  def watches?(bug)
    watches.where(bug_id: bug.id).first
  end

  # @private
  def to_param() username end

  def as_json(options=nil)
    options ||= {}

    options[:except] = Array.wrap(options[:except])
    options[:except] << :id
    options[:except] << :updated_at

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :name
    options[:methods] << :email
    options[:methods] << :gravatar

    super options
  end

  # @private
  def to_json(options={})
    options[:except] = Array.wrap(options[:except])
    options[:except] << :id
    options[:except] << :updated_at

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :name
    options[:methods] << :email

    super options
  end
end
