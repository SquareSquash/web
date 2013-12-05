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

# A bug is a group of {Occurrence Occurrences} that Squash believes to share the
# same root cause. Bugs are the core unit of functionality in Squash; they can
# be assigned to {User Users}, {Comment commented} on, etc.
#
# Separate Bugs are created for each `environment` they occur in.
#
# Like {Comment Comments}, each Bug is assigned a `number` in sequence among
# other Bugs of the same Project. This number is used when referring to Bugs,
# providing more useful information than the ID.
#
# Occurrences of a Bug can span multiple {Deploy Deploys} of different revisions
# of the code, so the revision/file/line number is recorded from the first
# occurrence of the Bug. Thus, when `git blame` is run to guess at who is at
# fault, this is done on the revision of the code at the first occurrence.
#
# When a bug is first created, the program determines the relevant file and line
# number. This is in general the highest line of back trace that is not library
# code.
#
# Duplicate Bugs
# --------------
#
# The user can mark a Bug as a duplicate of another Bug; this is done by
# associating the original Bug to the duplicate by way of the `duplicate_of_id`
# relation.
#
# When this happens, all Occurrences of the duplicate Bug are moved to the
# original Bug instead, and future Occurrences are placed under the original
# Bug. Because of this, marking a Bug as a duplicate is irreversible.
#
# When the user deletes a Bug with duplicates, the duplicates are also deleted.
#
# Associations
# ============
#
# |                           |                                                                                   |
# |:--------------------------|:----------------------------------------------------------------------------------|
# | `environment`             | The {Environment} this Bug occurred in.                                           |
# | `project`                 | The {Project} this Bug occurred in.                                               |
# | `deploy`                  | The {Deploy} that introduced the Bug.                                             |
# | `assigned_user`           | The {User} assigned to fix this Bug.                                              |
# | `occurrences`             | The separate {Occurrence Occurrences} of this Bug.                                |
# | `comments`                | The {Comment Comments} on this Bug.                                               |
# | `events`                  | The {Event Events} that happened to this Bug.                                     |
# | `watches`                 | The {Watch Watches} representing Users watching this Bug.                         |
# | `duplicate_of`            | Indicates that this Bug was marked as a duplicate of the associated {Bug}.        |
# | `duplicate_bugs`          | The {Bug Bugs} that were marked as a duplicate of this Bug.                       |
# | `notification_thresholds` | The {NotificationThreshold NotificationThresholds} Users have placed on this Bug. |
#
# Properties
# ==========
#
# |                          |                                                                                            |
# |:-------------------------|:-------------------------------------------------------------------------------------------|
# | `class_name`             | The name of exception class (or error class/number).                                       |
# | `file`                   | The path name of the file determined to be where the Bug is, relative to the project root. |
# | `line`                   | The line number of the above file where the Bug was determined to be.                      |
# | `revision`               | The revision of the project when the Bug first occurred.                                   |
# | `blamed_revision`        | The most recent commit that modified the above file and line number.                       |
# | `resolution_revision`    | The commit that fixed this Bug.                                                            |
# | `number`                 | A consecutively incrementing value among other Bugs of the same Project.                   |
# | `fixed`                  | If `true`, this Bug has already been resolved.                                             |
# | `fix_deployed`           | If `true`, the commit that fixes this Bug has been deployed.                               |
# | `irrelevant`             | If `true`, this Bug does not represent an actual programmer error, and will not be fixed.  |
# | `first_occurrence`       | The time at which this Bug first occurred.                                                 |
# | `latest_occurrence`      | The time of the most recent occurrence.                                                    |
# | `occurrences_count`      | The total number of occurrences so far.                                                    |
# | `comments_count`         | The total number of comments left on the Bug.                                              |
# | `client`                 | The client library that first saw the Bug (Rails, iOS, Android, etc.).                     |
# | `searchable_text`        | Automatically-managed lexeme vector for text-based search.                                 |
# | `any_occurrence_crashed` | `true` if any associated Occurrence crashed.                                               |
#
# Metadata
# ========
#
# |                        |                                                                                                      |
# |:-----------------------|:-----------------------------------------------------------------------------------------------------|
# | `message_template`     | The form of error messages of this error, with occurrence-specific parts replaced with placeholders. |
# | `fixed_at`             | When the bug was marked as fixed (set automatically).                                                |
# | `notify_on_occurrence` | An array of User IDs to email whenever a new Occurrence is added.                                    |
# | `notify_on_deploy`     | An array of User IDs to email when the Bug's resolution commit has been deployed.                    |
# | `special_file`         | If `true`, the `file` property has a special value (e.g., a function address), as does `line`.       |
# | `jira_issue`           | The key of a linked JIRA issue, such as "PROJ-123".                                                  |
# | `jira_status_id`       | The ID value of the status field of the JIRA issue that should automatically resolve this Bug.       |

class Bug < ActiveRecord::Base
  belongs_to :environment, inverse_of: :bugs
  belongs_to :assigned_user, class_name: 'User', inverse_of: :assigned_bugs
  belongs_to :deploy, inverse_of: :bugs
  belongs_to :duplicate_of, class_name: 'Bug', inverse_of: :duplicate_bugs
  has_many :duplicate_bugs, class_name: 'Bug', foreign_key: 'duplicate_of_id', inverse_of: :duplicate_of, dependent: :destroy
  has_one :project, through: :environment

  has_many :occurrences, dependent: :delete_all, inverse_of: :bug
  has_many :comments, dependent: :delete_all, inverse_of: :bug
  has_many :events, dependent: :delete_all, inverse_of: :bug
  has_many :watches, dependent: :delete_all, inverse_of: :bug
  has_many :notification_thresholds, dependent: :delete_all, inverse_of: :bug
  has_many :device_bugs, dependent: :delete_all, inverse_of: :bug

  # @return [User, Occurrence, JIRA::Resource::Issue] The User who is currently
  #   modifying this Bug, or the Occurrence that is causing this bug to be
  #   reopened, or other object that is responsible for the change, or `nil` for
  #   internal modifications. Used for {Event Events}.
  attr_accessor :modifier
  # @return [Deploy] The deploy that will mark this Bug as `fix_deployed`. Used
  #   for Events.
  attr_accessor :fixing_deploy
  # @private
  attr_accessor :duplicate_of_number

  attr_readonly :environment, :number, :first_occurrence, :latest_occurrence,
                :occurrences_count, :comments_count, :class_name,
                :message_template, :revision, :file, :line, :blamed_revision

  include HasMetadataColumn
  has_metadata_column(
      message_template:     {presence: true, length: {maximum: 1000}},
      fixed_at:             {type: Time, allow_nil: true},
      notify_on_occurrence: {type: Array, default: []},
      notify_on_deploy:     {type: Array, default: []},
      special_file:         {type: Boolean, default: false, allow_nil: false},

      jira_issue:           {type: String, allow_nil: true},
      jira_status_id:       {type: Fixnum, allow_nil: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}}
  )

  validates :environment,
            presence: true
  validates :class_name,
            presence: true,
            length:   {maximum: 128}
  validates :file,
            presence: true,
            length:   {maximum: 255}
  validates :line,
            presence:     true,
            numericality: {only_integer: true, greater_than: 0}
  validates :blamed_revision, :resolution_revision,
            length:    {is: 40},
            format:    {with: /\A[0-9a-f]+\z/},
            allow_nil: true
  validates :revision,
            presence: true,
            length:   {is: 40},
            format:   {with: /\A[0-9a-f]+\z/}
  #validates :first_occurrence,
  #          presence: true
  #validates :latest_occurrence,
  #          presence: true
  #validates :occurrences_count,
  #          presence:     true,
  #          numericality: {only_integer: true, greater_than_or_equal_to: 0}
  #validates :comments_count,
  #          presence:     true,
  #          numericality: {only_integer: true, greater_than_or_equal_to: 0}
  #validates :number,
  #          presence:     true,
  #          numericality: {only_integer: true, greater_than: 0},
  #          uniqueness:   {scope: :environment_id}
  validate :open_bugs_cannot_be_deployed, :assigned_user_must_be_project_member,
           :resolution_revision_cant_be_set_without_closing,
           :cannot_be_duplicate_of_duplicate, :cannot_set_duplicate_twice,
           :cannot_change_original_to_duplicate,
           :cannot_be_duplicate_of_foreign_bug

  before_validation(on: :create) { |obj| obj.revision = obj.revision.downcase if obj.revision }
  before_validation { |obj| obj.fixed_at = Time.now if obj.fixed? && !obj.fixed_was }
  before_create { |obj| obj.notify_on_occurrence = [] } # if anyone can explain to me why this defaults to [1] and not []...
  after_create :reload # grab the number value after the rule has been run
  after_save :index_for_search!
  set_nil_if_blank :blamed_revision, :resolution_revision, :jira_issue

  scope :query, ->(query) {
    select('*, TS_RANK_CD(searchable_text, query, 2|4|32) AS rank').
      from("bugs, TO_TSQUERY('english', #{connection.quote(query || '')}) query").
      where("query @@ searchable_text").
      order('rank DESC')
  }

  # Reopens a Bug by marking it as unfixed. Sets `fix_deployed` to `false` as
  # well. You can pass in a cause that will be used to add information to the
  # resulting {Event}.
  #
  # @param [User, Occurrence] cause The User or Occurrence that caused this Bug
  #   to be reopened.

  def reopen(cause=nil)
    self.fixed        = false
    self.fix_deployed = false
    self.modifier     = cause
  end

  # @return [:open, :assigned, :fixed, :fix_deployed] The current status of this
  #   Bug.

  def status
    return :fix_deployed if fix_deployed?
    return :fixed if fixed?
    return :assigned if assigned_user_id
    return :open
  end

  # @return [Git::Object::Commit] The commit corresponding to `revision`.

  def occurrence_commit
    return nil unless environment.project.repo
    @occurrence_commit ||= begin
      oc = environment.project.repo.object revision
      BackgroundRunner.run(ProjectRepoFetcher, environment.project_id) unless oc
      oc
    end
  end

  # @return [Git::Object::Commit] The commit corresponding to `blamed_revision`.

  def blamed_commit
    return nil unless environment.project.repo
    @blamed_commit ||= begin
      bc = environment.project.repo.object blamed_revision
      BackgroundRunner.run(ProjectRepoFetcher, environment.project_id) unless bc
      bc
    end
  end

  # @return [Git::Object::Commit] The commit corresponding to
  #   `resolution_revision`.

  def resolution_commit
    return nil unless environment.project.repo
    @resolution_commit ||= begin
      rc = environment.project.repo.object resolution_revision
      BackgroundRunner.run(ProjectRepoFetcher, environment.project_id) unless rc
      rc
    end
  end

  # @return [String, Array<String>, nil] The email(s) of the person/people who
  #   is/are determined via `git-blame` to be at fault. This is typically the
  #   email associated with the commit, but could be a different email if a
  #   nonstandard author format is used, another User has assumed the original
  #   User's emails, or the User has specified a different primary Email.

  def blamed_email
    emails = blamed_users.map(&:email)
    return case emails.size
             when 0 then nil
             when 1 then emails.first
             else        emails
           end
  end

  # Similar to {#blamed_email}, but returns an array of Email objects that are
  # associated with Users. Any unrecognized email addresses are represented as
  # unsaved Email objects whose `user` is set to `nil`.
  #
  # @return [Array<Email>] The email(s) of the person/people who is/are
  #   determined via `git-blame` to be at fault.
  # @see #blamed_email

  def blamed_users
    return [] unless blamed_commit

    all_emails = [find_responsible_user(blamed_commit.author.email)].compact

    # first priority is to use the email associated with the commit itself
    emails     = all_emails.map { |em| Email.primary.by_email(em).first }.compact

    # second priority is matching a project member by commit author(s)
    emails = emails_from_commit_author.map do |em|
      Email.primary.by_email(find_responsible_user(em)).first || Email.new(email: em)
      # build a fake empty email object to stand in for emails not linked to known user accounts
    end if emails.empty?

    # third priority is unknown emails associated with the commit itself (if the project is so configured)
    if emails.empty? && environment.project.sends_emails_outside_team?
      # build a fake empty email object to stand in for emails not linked to known user accounts
      emails = all_emails.map { |em| Email.new(email: em) }
      if environment.project.trusted_email_domain
        emails.select! { |em| em.email.split('@').last == environment.project.trusted_email_domain }
      end
    end

    return emails
  end

  # @return [true, false] `true` if `file` is a library file, or `false` if it
  #   is a project file.

  def library_file?
    special_file? || environment.project.path_type(file) == :library
  end

  # @private
  def to_param() number.to_s end

  # @return [String] Localized, human-readable name. This duck-types this class
  #   for use with breadcrumbs.

  def name
    I18n.t 'models.bug.name', number: number
  end

  # Marks this Bug as duplicate of another Bug, and transfers all Occurrences
  # over to the other Bug. `save!`s the record.
  #
  # @param [Bug] bug The Bug this Bug is a duplicate of.

  def mark_as_duplicate!(bug)
    transaction do
      self.duplicate_of = bug
      save!
      occurrences.update_all(bug_id: bug.id)
    end
  end

  # @return [true, false] Whether this Bug is marked as a duplicate of another
  #   Bug.

  def duplicate?() !duplicate_of_id.nil? end

  # @private
  def as_json(options=nil)
    options          ||= {}
    options[:except] = Array.wrap(options[:except])
    options[:except] << :id << :environment_id << :assigned_user_id <<
        :searchable_text << :notify_on_occurrence << :notify_on_deploy

    options[:methods] = Array.wrap(options[:methods])
    options[:methods] << :status

    super options
  end

  # @private
  def to_json(*args) as_json(*args).to_json end

  # Re-creates the text search index for this Bug. Loads all the Bug's Comments;
  # should be done in a thread. Saves the record.

  def index_for_search!
    message_text = message_template.gsub(/\[.+?\]/, '')
    comment_text = comments.map(&:body).compact.join(' ')
    self.class.connection.execute <<-SQL
        UPDATE bugs
          SET searchable_text = SETWEIGHT(TO_TSVECTOR(#{self.class.connection.quote(class_name || '')}), 'A') ||
            SETWEIGHT(TO_TSVECTOR(#{self.class.connection.quote(message_text || '')}), 'B') ||
            SETWEIGHT(TO_TSVECTOR(#{self.class.connection.quote(comment_text || '')}), 'C')
          WHERE id = #{id}
    SQL
  end

  # @return [String] The incident key used to refer to this Bug in PagerDuty.

  def pagerduty_incident_key
    "Squash:Bug:#{id}"
  end

  private

  # warning: this can get slow. always returns valid primary emails
  def emails_from_commit_author
    names  = blamed_commit.author.name.split(/\s*(?:[+&]| and )\s*/)
    emails = []
    environment.project.memberships.includes(:user).find_each do |m|
      emails << m.user.email if names.any? { |name| m.user.name.downcase.strip.squeeze(' ') == name.downcase.strip.squeeze(' ') }
    end
    emails
  end

  def open_bugs_cannot_be_deployed
    errors.add(:fix_deployed, :not_fixed) if fix_deployed? && !fixed?
  end

  def assigned_user_must_be_project_member
    errors.add(:assigned_user_id, :not_member) if assigned_user && assigned_user.role(environment.project).nil?
  end

  def resolution_revision_cant_be_set_without_closing
    if !fixed_changed? && !fixed? && resolution_revision_changed? && resolution_revision.present?
      errors.add(:resolution_revision, :set_on_unfixed)
    end
  end

  def find_responsible_user(email, history=[])
    # verify that the email's not one we've seen before (circular dependency)
    raise "Circular email redirection! #{history.join(' -> ')} -> #{email}" if history.include? email
    # add this email to the history
    history << email

    # locate a user who has this address as a non-primary (redirecting) email
    redirected_email = Email.redirected.by_email(email).where(project_id: environment.project.id).first
    redirected_email ||= Email.redirected.by_email(email).first
    # if one exists
    if redirected_email
      # recurse again with the redirected user's primary email, in case someone has taken over HIS/HER emails
      return find_responsible_user(redirected_email.user.email, history)
    else
      # this email has not been assumed by anyone else; return it
      return email
    end
  end

  def cannot_be_duplicate_of_duplicate
    errors.add(:duplicate_of_id, :is_a_duplicate) if duplicate_of.try!(:duplicate?)
  end

  def cannot_change_original_to_duplicate
    errors.add(:duplicate_of_id, :has_duplicates) if duplicate_of_id? && !duplicate_bugs.empty?
  end

  def cannot_set_duplicate_twice
    errors.add(:duplicate_of_id, :already_duplicate) if duplicate_of_id_changed? && !duplicate_of_id_was.nil?
  end

  def cannot_be_duplicate_of_foreign_bug
    errors.add(:duplicate_of_id, :foreign_bug) if duplicate_of && duplicate_of.environment_id != environment_id
  end
end
