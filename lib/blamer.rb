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

# This class analyzes an Occurrence and determines which Bug is responsible. A
# new Bug is created if no existing Bug matches the search criteria.
#
# Usage
# -----
#
# To re-calculate blame for an existing Occurrence, and potentially re-assign it
# to a different Bug, it is sufficient to pass the Occurrence to this class's
# initializer.
#
# To assign blame to a new, unsaved Occurrence, it will be necessary to create
# an unsaved Bug and fill it out with the data Blamer needs in order to perform
# its search. This data is:
#
# * the Bug's `environment`,
# * the Bug's `class_name`, and
# * the Bug's `deploy`, if any.
#
# This new Bug should be temporarily associated with the Occurrence before the
# Occurrence is given to Blamer. The result of the {#find_or_create_bug!} method
# will always be a different, saved Bug; you should leave your temporary Bug
# unsaved.
#
# Matching to a Bug
# -----------------
#
# In order to match an Occurrence to a Bug, the line number of the backtrace
# that is at fault must first be determined. This is done probabilistically, by
# assigning a score to each line of the backtrace and picking the line with
# the highest score. Currently, the factors that influence a line's score are
#
# * the "height" of that line in the backtrace, and
# * the age of the commit that most recently modified that line.
#
# The highest-scoring file and line number are termed the **relevant file** and
# **relevant line**.
#
# An Occurrence is matched to a Bug using three mandatory criteria:
#
# * the relevant file path,
# * the relevant line number, and
# * the class name of the raised exception.
#
# In addition, if a "blamed" commit is available for the relevant file and line,
# the bug is matched on that commit ID as well. Note that the exception message
# is _not_ included in the search criteria.
#
# While each Occurrence maintains the original exception message, the Bug
# filters the exception message to remove occurrence-specific information. There
# are two ways of filtering exception messages:
#
# * If the exception can be filtered using {MessageTemplateMatcher}, that
#   filtered message is used.
# * Otherwise, a general search-and-replace is used to replace likely
#   occurrence-specific information (like numbers, inspect values, etc.) with
#   placeholders.
#
# All placeholders take the form "[ALL CAPS IN BRACKETS]" so that the view can
# recognize them as such and format them appropriately.
#
# Deployed Projects
# -----------------
#
# For Occurrences that come from Projects deployed onto client platforms, the
# Deploy is also taken into account. For such Projects, the Blamer will try to
# find, in order:
#
# * an open Bug matching the search criteria under any Deploy,
# * a fixed Bug matching the criteria under the current Deploy, or
# * a newly-created Bug.
#
# In no case will an open Bug in a different Deploy be chosen.
#
# Reopening Bugs
# --------------
#
# After linking and saving the Bug returned from {#find_or_create_bug!}, you
# should call {#reopen_if_necessary!} to potentially reopen the Bug. This should
# only be done after the Occurrence and Bug are both linked and saved.

class Blamer
  # The amount of time after a bug is fixed _without_ being deployed after which
  # it will be reopened if new occurrences appear.
  STALE_TIMEOUT = 10.days

  attr_reader :occurrence

  # Creates a new instance suitable for placing a given Occurrence.
  #
  # @param [Occurrence] occurrence The Occurrence to find a Bug for.

  def initialize(occurrence)
    @occurrence = occurrence
    @special    = false
  end

  # @return [Bug] A Bug the Occurrence should belong to. Does not assign the
  #   Occurrence to the Bug. If no suitable Bug is found, saves and returns a
  #   new one.

  def find_or_create_bug!
    commit = occurrence.commit || deploy.try(:commit)
    raise "Need a resolvable commit" unless commit

    criteria = bug_search_criteria(commit)
    bug      = if deploy
                 # for distributed projects, we need to find either
                 # * a bug associated with the exact deploy specified in the build attribute
                 # * or, if the exact deploy specified does not have such a bug:
                 #   * find any open (not fixed) bug matching the criteria;
                 #   * if such a bug exists, use that bug and alter its deploy_id to
                 #     the given deploy;
                 #   * otherwise, a new bug is created.
                 b        = Bug.transaction do
                   environment.bugs.where(criteria.merge(deploy_id: deploy.id)).first ||
                       environment.bugs.where(criteria.merge(fixed: false)).
                           find_or_create!(bug_attributes, as: :worker)
                 end
                 b.deploy = deploy
                 b
               else
                 # for hosted projects, we search for any bug matching the criteria under
                 # our current environment
                 environment.bugs.where(criteria).
                     find_or_create!(bug_attributes, as: :worker)
               end

    # If this code works as it should, there should only be one open record of
    # a Bug at any time. A bug occurs, a new Bug is created. A new release is
    # out, but it doesn't fix the bug, and that same Bug is reused. A new
    # release is out that DOES fix the bug, and the bug is closed. The bug
    # recurs, and a new open Bug is created.

    # Lastly, we need to resolve the bug if it's a duplicate.
    bug = bug.duplicate_of(true) if bug.duplicate?

    return bug
  end

  # This method determines if the Bug should be reopened. You should pass in the
  # Bug returned from {#find_or_create_bug!}, after it has been linked to the
  # Occurrence and saved.
  #
  # This method will reopen the Bug if necessary. The Bug is only reopened if
  # it recurs after being fixed and after the fix is deployed. A fix is
  # considered deployed if the fix has been marked `fix_deployed` or if the fix
  # is over 30 days old.
  #
  # Bugs of distributed Projects are never reopened.
  #
  # @param [Bug] bug The bug that was returned from {#find_or_create_bug!}.

  def reopen_bug_if_necessary!(bug)
    return if bug.deploy

    # now that things are saved, reopen the bug if we need to
    # this is so the occurrence has an id we can write into the reopen event
    occurrence_deploy = bug.environment.deploys.where(revision: occurrence.revision).order('deployed_at DESC').first
    latest_deploy     = bug.environment.deploys.order('deployed_at DESC').first
    if bug.fix_deployed? && occurrence_deploy.try(:id) == latest_deploy.try(:id)
      # reopen the bug if it was purportedly fixed and deployed, and the occurrence
      # we're seeing is on the latest deploy -- or if we don't have any deploy
      # information
      bug.reopen occurrence
      bug.save!
    elsif !bug.fix_deployed? && bug.fixed? && bug.fixed_at < STALE_TIMEOUT.ago
      # or, if it was fixed but never marked as deployed, and is more than 30 days old, reopen it
      bug.reopen occurrence
      bug.save!
    end
  end

  private

  def bug() occurrence.bug end
  def environment() occurrence.bug.environment end
  def project() occurrence.bug.environment.project end
  def deploy() occurrence.bug.deploy end

  def bug_search_criteria(occurrence_commit)
    file, line, commit = blamed_revision(occurrence_commit)
    {
        class_name:      occurrence.bug.class_name,
        file:            file,
        line:            line,
        blamed_revision: commit.try(:sha)
    }
  end

  def bug_attributes
    message = if project.disable_message_filtering?
                occurrence.message
              else
                filter_message(occurrence.bug.class_name, occurrence.message)
              end.truncate(1000)

    {
        message_template: message,
        revision:         occurrence.revision,
        environment:      occurrence.bug.environment,
        client:           occurrence.client,
        special_file:     @special
    }
  end

  def blamed_revision(occurrence_commit)
    # first, strip irrelevant lines from the backtrace.
    backtrace = occurrence.faulted_backtrace.select { |elem| elem['type'].nil? }
    backtrace.select! { |elem| project.path_type(elem['file']) == :project }
    backtrace.reject! { |elem| elem['line'].nil? }

    if backtrace.empty? # no project files in the trace; just use the top library file
      file, line = file_and_line_for_bt_element(occurrence.faulted_backtrace.first)
      return file, line, nil
    end

    # collect the blamed commits for each line
    backtrace.map! do |elem|
      commit = Blamer::Cache.instance.blame(project, occurrence_commit.sha, elem['file'], elem['line'])
      [elem, commit]
    end

    top_element = backtrace.first
    backtrace.reject! { |(_, commit)| commit.nil? }
    if backtrace.empty? # no file has an associated commit; just use the top file
      file, line = file_and_line_for_bt_element(top_element.first)
      return file, line, nil
    end

    earliest_commit = backtrace.sort_by { |(_, commit)| commit.committer.date }.first.last

    # now, for each line, assign a score consisting of different weighted factors
    # indicating how likely it is that that line is to blame
    backtrace.each_with_index do |line, index|
      line << score_backtrace_line(index, backtrace.length, line.last.committer.date, occurrence_commit.date, earliest_commit.date)
    end

    element, commit, _ = backtrace.sort_by(&:last).last
    file, line = file_and_line_for_bt_element(element)
    return file, line, commit
  end

  def file_and_line_for_bt_element(element)
    case element['type']
      when nil
        [element['file'], element['line']]
      when 'obfuscated'
        @special = true
        [element['file'], element['line'].abs]
      when 'minified'
        @special = true
        [element['url'], element['line']]
      when 'address'
        @special = true #TODO not the best way of doing this
        return "0x#{element['address'].to_s(16).rjust(8, '0').upcase}", 1
      else
        @special = true
        return '(unknown)', 1
    end
  end

  def score_backtrace_line(index, size, commit_date, latest_date, earliest_date)
    height  = (size-index)/size.to_f
    recency = if commit_date && earliest_date
                if latest_date - earliest_date == 0
                  0
                else
                  1 - (latest_date - commit_date)/(latest_date - earliest_date)
                end
              else
                0
              end

    0.5*height**2 + 0.5*recency #TODO determine better factors through experimentation
  end

  def filter_message(class_name, message)
    template_message = MessageTemplateMatcher.instance.sanitized_message(class_name, message)
    return template_message if template_message

    message = message.
        gsub(/#<([^\s]+) (\w+: .+?(, )?)+>/, "#<\\1 [ATTRIBUTES]>") # #<Project id: 1, foo: bar>
    message.gsub!(/#<([^\s]+) .+?>/, "#<\\1 [DESCRIPTION]>")        # #<Net::HTTP www.apple.com:80 open=true>
    message.gsub!(/#<(.+?):0x[0-9a-f]+>/, "#<\\1:[ADDRESS]>")       # #<Object:0x007fedfa0aa920>
    message.gsub!(/\b[0-9a-f]{40}\b/, "[SHA1]")                     # 0e32b153039e46d4165c65eef1fc277d0f8f11d2
    message.gsub!(/\b\d+\.\d+\.\d+\.\d+\b/, "[IPv4]")               # 144.89.172.115
    message.gsub!(/\b-?\d+(\.\d+)?\b/, "[NUMBER]")                  # 42.24 or 42 or -42
    message
  end

  # A write-through LRU cache of `git-blame` results, backed by the PostgreSQL
  # `blames` table by means of the {Blame} model.

  class Cache
    include Singleton

    # The maximum number of cached blame entries to store.
    MAX_ENTRIES = 500_000

    # Returns the cached result of a blame operation, or performs the blame on a
    # cache miss. `nil` blame results are never cached.
    #
    # @param [Project] project The project whose repository will be used for the
    #   blame operation.
    # @param [String] revision The SHA1 revision at which point to run the
    #   blame.
    # @param [String] file The file to run the blame on.
    # @param [Integer] line The line number in the file to run the blame at.
    # @return [String, nil] The SHA of the blamed revision, or `nil` if blame
    #   could not be determined for some reason.

    def blame(project, revision, file, line)
      cached_blame(project, revision, file, line) ||
          write_blame(project, revision, file, line, git_blame(project, revision, file, line))
    end

    private

    def cached_blame(project, revision, file, line)
      blame = Blame.for_project(project).where(revision: revision, file: file, line: line).first
      if blame
        blame.touch
        return project.repo.object(blame.blamed_revision)
      else
        return nil
      end
    end

    def git_blame(project, revision, file, line)
      rev = project.repo.blame(file,
                               revision:               revision,
                               detect_interfile_moves: true,
                               detect_intrafile_moves: true,
                               start:                  line,
                               end:                    line)[line]
      rev ? project.repo.object(rev) : nil
    rescue Git::GitExecuteError
      Rails.logger.tagged('Blamer') { Rails.logger.error "Couldn't git-blame #{project.slug}:#{revision}: #{$!}" }
      nil
    end

    def write_blame(project, revision, file, line, blamed_commit)
      if blamed_commit
        purge_entry_if_necessary
        Blame.for_project(project).
            where(revision: revision, file: file, line: line).
            create_or_update! do |blame|
          blame.blamed_revision = blamed_commit.sha
        end
      end
      return blamed_commit
    end

    def purge_entry_if_necessary
      Blame.transaction do
        if (count = Blame.count) >= MAX_ENTRIES
          query = Blame.select(:id).order('updated_at ASC').limit((count + 1) - MAX_ENTRIES).to_sql
          Blame.where("id = ANY(ARRAY(#{query}))").delete_all
        end
      end
    end
  end
end
