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

# A join table associating a {User} with a {Project} he is a member of. While it
# is implied that a project's owner is also a member, a Membership is created to
# that effect as well, just to be thorough.
#
# Memberships can be marked as `admin`, in which case they can create and delete
# other memberships. Only the project owner can confer and revoke admin status,
# or assign project ownership to another user.
#
# Associations
# ============
#
# |           |                                              |
# |:----------|:---------------------------------------------|
# | `user`    | The {User} having membership in the project. |
# | `project` | The {Project} the user is a member of.       |
#
# Properties
# ==========
#
# |         |                                                                                         |
# |:--------|:----------------------------------------------------------------------------------------|
# | `admin` | If true, this member has the ability to add and remove other users to/from the project. |
#
# Metadata
# ========
#
# |                          |                                                                                                                  |
# |:-------------------------|:-----------------------------------------------------------------------------------------------------------------|
# | `send_assignment_emails` | If `true`, emails will be sent when the User is assigned to a Bug in this Project.                               |
# | `send_comment_emails`    | If `true`, emails will be sent when a User comments on a Bug in this Project that this User is participating in. |
# | `send_resolution_emails` | If `true`, emails will be sent when a Bug in this Project that the User is assigned to is resolved.              |

class Membership < ActiveRecord::Base
  self.primary_keys = :user_id, :project_id

  belongs_to :user, inverse_of: :memberships
  belongs_to :project, inverse_of: :memberships

  attr_readonly :user, :project

  include HasMetadataColumn
  has_metadata_column(
      send_assignment_emails: {type: Boolean, default: true},
      send_comment_emails:    {type: Boolean, default: false},
      send_resolution_emails: {type: Boolean, default: true}
  )

  validates :user,
            presence: true
  validates :project,
            presence: true

  delegate :to_param, to: :user

  scope :project_prefix, ->(query) { joins(:project).where("LOWER(projects.name) LIKE ?", query.downcase.gsub(/[^a-z0-9\-_]/, '') + '%') }
  scope :user_prefix, ->(query) { joins(:user).where("LOWER(users.username) LIKE ?", query.downcase.gsub(/[^a-z0-9\-_]/, '') + '%') }
  scope :for, ->(user, project) {
    user    = user.id if user.kind_of?(User)
    project = project.id if project.kind_of?(Project)
    where(user_id: user, project_id: project)
  }

  # @private
  def as_json(options=nil)
    options           ||= {}
    options[:except]  = Array.wrap(options[:except]) + [:user_id, :project_id, :id]
    super(options).merge(user: user.as_json, project: project.as_json)
  end

  # @return [:owner, :admin, :member] The user's role in this project.
  # @see #human_role

  def role
    return :owner if project.owner_id == user_id
    return :admin if admin?
    return :member
  end

  # @return [String] A localized string representation of {#role}.

  def human_role
    I18n.t "models.membership.role.#{role}"
  end
end
