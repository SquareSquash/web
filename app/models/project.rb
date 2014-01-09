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

require 'securerandom'

# A Project is a single code repository that can (and probably does) have
# {Bug bugs}. Only {User Users} who are {Membership members} of a project can
# view and manage its exceptions.
#
# A project also has an `owner`, that can promote/demote administrators. (See
# {Membership} for more information.) Each project has a local, bare checkout of
# its repository in `tmp/repos`. This repo is used for analyzing bugs,
# assigning blame, and providing code context.
#
# A project consists of one or more {Environment Environments} in which Bugs can
# occur.
#
# Associations
# ============
#
# |                       |                                                         |
# |:----------------------|:--------------------------------------------------------|
# | `owner`               | The {User} who owns this project.                       |
# | `default_environment` | The default {Environment} to display when viewing bugs. |
# | `environments`        | The {Environment Environments} in this project.         |
# | `memberships`         | The {Membership Memberships} in this project.           |
# | `members`             | The {User Users} who have memberships in this project.  |
#
# Properties
# ==========
#
# |                  |                                                                         |
# |:-----------------|:------------------------------------------------------------------------|
# | `name`           | The human-readable name of the project.                                 |
# | `api_key`        | A unique key sent with occurrences to associate them with this project. |
# | `repository_url` | The URL to the project's repository.                                    |
#
# Metadata
# ========
#
# General
# =======
#
# |                             |                                                                                                                                                                  |
# |:----------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
# | `uses_releases`             | If `true`, bug views will be segregated by release, and release data will be displayed. Automatically set to true if any Deploys with release data are received. |
# | `uses_releases_override`    | `uses_releases` is set automatically. If the user has set the value at least once manually, this is `true`, and automatic updates are suppressed.                |
# | `disable_message_filtering` | If `true`, Bug messages are not filtered for potentially sensitive information.                                                                                  |
# | `blamer_type`               | The name of a subclass of {Blamer::Base} that will be used to perform the blame operation.                                                                       |
#
# Code configuration
# ------------------
#
# |                     |                                                                                                               |
# |:--------------------|:--------------------------------------------------------------------------------------------------------------|
# | `commit_url_format` | The format of the URL to a web page describing a commit (includes the "%!{commit}" interpolation).            |
# | `filter_paths`      | Paths to ignore when determining a Bug's relevant file and line.                                              |
# | `whitelist_paths`   | Paths to _not_ ignore when determining a Bug's relevant file and line (takes precedence over `filter_paths`). |
#
# Mailer
# ------
#
# |                             |                                                                                                                                    |
# |:----------------------------|:-----------------------------------------------------------------------------------------------------------------------------------|
# | `critical_mailing_list`     | The mailing list to send exception reports when a Bug exceeds `critical_threshold` Occurrences.                                    |
# | `all_mailing_list`          | The mailing list to send reports of every new Bug.                                                                                 |
# | `critical_threshold`        | The number of Occurrences a Bug must have to notify the `critical_mailing_list`.                                                   |
# | `sender`                    | The address to use for the "Sender" field of notification emails.                                                                  |
# | `locale`                    | The ISO 639-1 name of the locale to use for emails.                                                                                |
# | `sends_emails_outside_team` | If `true`, emails will be sent blamed email addresses even if they don't correspond to a project member.                           |
# | `trusted_email_domain`      | If `sends_emails_outside_team` is true, only email addresses with this domain will be notified. If `nil`, all domains are trusted. |
#
# Integrations
# ------------
#
# |                           |                                                                                                                                             |
# |:--------------------------|:--------------------------------------------------------------------------------------------------------------------------------------------|
# | `pagerduty_enabled`       | If `true`, new Occurrences are sent to PagerDuty. Note that PagerDuty "acknowledge" and "resolve" events are sent regardless of this value. |
# | `pagerduty_service_key`   | The service key assigned to this project by PagerDuty.                                                                                      |
# | `always_notify_pagerduty` | If `true`, all new Bugs are sent to PagerDuty. If `false`, only those Bugs that exceed the critical threshold are sent.                     |

class Project < ActiveRecord::Base
  # The directory where repositories are checked out.
  REPOS_DIRECTORY = File.expand_path(Squash::Configuration.repositories.directory, Rails.root.to_s)
  # File names that appear in backtraces that aren't really file names
  META_FILE_NAMES = %w( (irb) (eval) -e )

  # If set to `true`, Git will attempt to clone the repository, and add an error
  # to the `repository_url` attribute if it cannot.
  attr_accessor :validate_repo_connectivity

  belongs_to :owner, class_name: 'User', inverse_of: :owned_projects
  belongs_to :default_environment, class_name: 'Environment', inverse_of: :default_project

  has_many :environments, dependent: :delete_all, inverse_of: :project
  has_many :memberships, dependent: :delete_all, inverse_of: :project
  has_many :members, through: :memberships, source: :user
  has_many :emails, inverse_of: :project, dependent: :delete_all

  include Slugalicious
  slugged :name

  include HasMetadataColumn
  has_metadata_column(
      commit_url_format:         {allow_nil: true},
      filter_paths:              {type: Array, default: []},
      whitelist_paths:           {type: Array, default: []},

      critical_mailing_list:     {email: true, allow_nil: true},
      all_mailing_list:          {email: true, allow_nil: true},
      critical_threshold:        {type: Fixnum, presence: true, default: 100, numericality: {only_integer: true, greater_than_or_equal_to: 1}},
      sender:                    {email: true, allow_nil: true},
      locale:                    {default: 'en', presence: true},
      sends_emails_outside_team: {type: Boolean, default: false, allow_nil: false},
      trusted_email_domain:      {allow_nil: true},

      pagerduty_enabled:         {type: Boolean, default: false},
      pagerduty_service_key:     {presence: {if: :pagerduty_enabled}},
      always_notify_pagerduty:   {type: Boolean, default: false},

      uses_releases:             {type: Boolean, default: false},
      uses_releases_override:    {type: Boolean, default: false},

      disable_message_filtering: {type: Boolean, default: false},
      blamer_type:               {presence: true, default: 'Blamer::Recency'}
  )

  validates :owner,
            presence: true
  validates :name,
            presence: true,
            length:   {maximum: 126}
  validates :api_key,
            presence:   true
            #uniqueness: true,
            #length:     {is: 36},
            #format:     {with: /[0-9a-f\-]+/}
  validates :repository_url,
            presence:   true,
            length:     {maximum: 255}
  validate :default_environment_belongs_to_project
  validate :can_clone_repo, if: :validate_repo_connectivity

  before_validation :create_api_key, on: :create
  set_nil_if_blank :commit_url_format, :critical_mailing_list,
                   :all_mailing_list, :sender, :trusted_email_domain,
                   :pagerduty_service_key

  after_save do |obj|
    obj.memberships.where(user_id: obj.owner_id).create_or_update!(admin: true) if owner_id_changed?
    obj.memberships.where(user_id: obj.owner_id_was).create_or_update!(admin: true) if owner_id_was
  end
  before_validation :set_commit_url_format

  scope :prefix, ->(query) { where("LOWER(name) LIKE ?", query.downcase.gsub(/[^a-z0-9\-_ ]/, '') + '%') }

  # Returns a `Git::Repository` proxy object that allows you to work with the
  # local checkout of this Project's repository. The repository will be checked
  # out if it hasn't been already.
  #
  # Any Git errors that occur when attempting to clone the repository are
  # swallowed, and `nil` is returned.
  #
  # @overload repo
  #   @return [Git::Repository, nil] The proxy object for the repository.
  #
  # @overload repo(&block)
  #   If passed a block, this method will lock a mutex and yield the repository,
  #   giving you exclusive access to the repository. This is recommended when
  #   performing any repository-altering operations (e.g., fetches). The mutex
  #   is freed when the block completes.
  #   @yield A block that is given exclusive control of the repository.
  #   @yieldparam [Git::Repository] repo The proxy object for the repository.

  def repo
    repo_mutex.synchronize do
      @repo ||= begin
        exists = File.exist?(repo_path) || clone_repo
        exists ? Git.bare(repo_path) : nil
      end
    end

    if block_given?
      repo_mutex.synchronize { yield @repo }
    else
      @repo
    end
  end

  # Returns the URL to a web page describing a commit in this project.
  #
  # @param [String] commit The commit ID.
  # @return [String, nil] The URL to the commit's web page, or `nil` if
  #   `commit_url_format` has not been set.

  def commit_url(commit)
    return nil unless commit_url_format
    commit_url_format.gsub '%{commit}', commit
  end

  # Generates a new API key for the Project. Does not save the Project.

  def create_api_key
    self.api_key = SecureRandom.uuid
  end

  # Determines if a file is project source code, filtered project source code,
  # or library code. The project root must have already been stripped from the
  # path for this to work.
  #
  # @param [String] file A path to a file.
  # @return [Symbol] `:project` if this a project file, `:filtered` if this is a
  #   project file that should be filtered from the backtrace, and `:library` if
  #   this is a library file.

  def path_type(file)
    return :library if file.start_with?('/') # not within project root
    return :library if META_FILE_NAMES.include?(file) # file names that aren't really file names
    # in filter paths and not in whitelist paths
    return :filtered if filter_paths.any? { |filter_line| file.start_with? filter_line } &&
        whitelist_paths.none? { |filter_line| file.start_with? filter_line }
    # everything else is a project file
    return :project
  end

  # @private
  def as_json(options=nil)
    options ||= {}

    options[:except] = Array.wrap(options[:except])
    options[:except] << :id
    options[:except] << :default_environment_id
    options[:except] << :owner_id
    options[:except] << :updated_at

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :slug

    super options
  end

  # @return [Service::PagerDuty, nil] A module for interacting with this
  #   Project's PagerDuty integration, or `nil` if PagerDuty is not enabled.

  def pagerduty
    @pagerduty ||= (pagerduty_service_key? ? Service::PagerDuty.new(pagerduty_service_key) : nil)
  end

  # @return [Class] The subclass of {Blamer::Base} that will be used to perform
  #   the blame operation for this Project's Occurrences.

  def blamer
    blamer_type.constantize
  end

  # @private
  def repository_hash
    Digest::SHA1.hexdigest(repository_url)
  end

  private

  def repo_path
    @repo_path ||= File.join(REPOS_DIRECTORY, repo_directory)
  end

  def repo_directory
    @repo_dir ||= repository_hash + '.git'
  end

  def clone_repo
    Git.clone repository_url, repo_directory, path: REPOS_DIRECTORY, mirror: true
  rescue Git::GitExecuteError
    return nil
  end

  def default_environment_belongs_to_project
    errors.add(:default_environment_id, :wrong_project) if default_environment && default_environment.project_id != id
  end

  def set_commit_url_format
    if repository_url =~ /^git@github\.com:([^\/]+)\/(.+)\.git$/ ||
        repository_url =~ /https:\/\/\w+@github\.com\/([^\/]+)\/(.+)\.git/ ||
        repository_url =~ /git:\/\/github\.com\/([^\/]+)\/(.+)\.git/ # GitHub
      self.commit_url_format ||= "https://github.com/#{$1}/#{$2}/commit/%{commit}"
    end
  end

  def can_clone_repo
    unless system('git', 'ls-remote', repository_url, out: '/dev/null', err: '/dev/null')
      errors.add :repository_url, :unreachable
    end
  end

  def repo_mutex
    @repo_mutex ||= FileMutex.new(repo_path.to_s + '.lock')
  end
end
