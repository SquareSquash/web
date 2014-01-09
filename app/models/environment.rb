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

# {Bug Bugs} in a {Project} are assigned to an Environment, as specified by the
# client library when delivering the occurrence report. Environments are just
# string identifiers, and can be any useful platform-specific differentiator;
# for example, the Rails environment of a Rails project, or the build channel of
# an Android app. A new Environment is automatically created the first time its
# string identifier is encountered.
#
# Associations
# ============
#
# |           |                                       |
# |:----------|:--------------------------------------|
# | `deploys` | The {Deploy Deploys} of this project. |
# | `bugs`    | The {Bug Bugs} in this project.       |
#
# Properties
# ==========
#
# |        |                                      |
# |:-------|:-------------------------------------|
# | `name` | The environment's unique identifier. |
#
# Metadata
# ========
#
# |                      |                                                                                  |
# |:---------------------|:---------------------------------------------------------------------------------|
# | `sends_emails`       | Whether or not exceptions in this environment generate email notifications.      |
# | `notifies_pagerduty` | If `true`, PagerDuty incidents are created and managed for Bugs and Occurrences. |

class Environment < ActiveRecord::Base
  belongs_to :project, inverse_of: :environments

  has_one :default_project, class_name: 'Project', foreign_key: 'default_environment_id', inverse_of: :default_environment
  has_many :deploys, dependent: :delete_all, inverse_of: :environment
  has_many :bugs, dependent: :delete_all, inverse_of: :environment
  has_many :source_maps, inverse_of: :environment, dependent: :delete_all

  include HasMetadataColumn
  has_metadata_column(
      sends_emails:       {type: Boolean, default: true},
      notifies_pagerduty: {type: Boolean, default: true}
  )

  attr_readonly :project, :name

  validates :project,
            presence: true
  validates :name,
            presence:   true,
            length:     {maximum: 100},
            uniqueness: {case_sensitive: false, scope: :project_id},
            format:     {with: /\A[a-zA-Z0-9\-_]+\z/}

  scope :with_name, ->(name) { where("LOWER(name) = ?", name.downcase) }

  # @private
  def to_param() name end

  def as_json(options=nil)
    options ||= {}

    options[:except] = Array.wrap(options[:except])
    options[:except] << :id
    options[:except] << :project_id

    super options
  end
end
