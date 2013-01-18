# Copyright 2012 Square Inc.
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

# A Deploy record is created every time the {Project} is (for hosted projects)
# deployed to either a staging or production server, or (for distributed
# projects) every time a new release is distributed internally or externally.
# The Deploy records the revision that was deployed and the time the deploy
# occurred. For releases only, it records the internal build identifier of the
# release (e.g., the build number).
#
# {Bug Bugs} will only be associated with deploys that have matching
# `environment` values.
#
# Associations
# ============
#
# |               |                                                                                                     |
# |:--------------|:----------------------------------------------------------------------------------------------------|
# | `environment` | The {Environment} that was deployed to.                                                             |
# | `project`     | The {Project} that was deployed.                                                                    |
# | `occurrences` | The {Occurrence Occurrences} of bugs that have happened since this deploy and before any newer one. |
#
# Properties
# ==========
#
# Deploys and releases
# --------------------
#
# |               |                                                          |
# |:--------------|:---------------------------------------------------------|
# | `revision`    | The revision of the codebase that was deployed/released. |
# | `deployed_at` | The time at which the deploy/release occurred.           |
#
# Deploys only
# ------------
#
# |            |                                               |
# |:-----------|:----------------------------------------------|
# | `hostname` | The host from where the deploy was initiated. |
#
# Releases only
# -------------
#
# |           |                                                 |
# |:----------|:------------------------------------------------|
# | `build`   | The internal version identifier of the release. |
# | `version` | The human readable version number.              |

class Deploy < ActiveRecord::Base
  belongs_to :environment, inverse_of: :deploys
  has_one :project, through: :environment
  # internal only
  has_many :bugs, inverse_of: :deploy, dependent: :nullify
  has_one :obfuscation_map, inverse_of: :deploy, dependent: :destroy

  attr_accessible :revision, :deployed_at, :hostname, :build, :version,
                  as: :worker
  attr_readonly :environment, :revision, :build, :hostname, :deployed_at,
                :version

  validates :environment,
            presence: true
  validates :revision,
            presence:       true,
            known_revision: {repo: ->(map) { RepoProxy.new(map, :environment, :project) }}
  validates :deployed_at,
            presence:   true,
            timeliness: {type: :time}
  validates :hostname,
            length:    {maximum: 126},
            allow_nil: true
  validates :build,
            length:     {maximum: 40},
            uniqueness: {scope: :environment_id},
            allow_nil:  true
  validates :version,
            length:    {maximum: 126},
            allow_nil: true

  after_commit(on: :create) do |deploy|
    worker = DeployFixMarker.new(deploy)
    Multithread.spinoff("DeployFixMarker:#{deploy.id}", 70, deploy: deploy, changes: deploy.changes) { worker.perform }
  end
  set_nil_if_blank :hostname, :build

  scope :builds, where('build IS NOT NULL')
  scope :by_time, order('deployed_at DESC')

  # @return [Git::Object::Commit] The Commit for this Deploy's `revision`.
  def commit() environment.project.repo.object revision end

  # @private
  def to_json(options={})
    options[:except] = Array.wrap(options[:except])
    options[:except] << :id
    options[:except] << :environment_id
    super options
  end
end
