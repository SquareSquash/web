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

module Blamer

  # This blamer uses the recency of the commit that most recently modified a
  # given stack trace element to determine how likely that line is to be at
  # fault.
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

  class Message < Base
    def find_or_create_bug!
      
      criteria = bug_search_criteria
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
                             find_or_create!(bug_attributes)
                   end
                   b.deploy = deploy
                   b
                 else
                   # for hosted projects, we search for any bug matching the criteria under
                   # our current environment
                   occurrence.message = occurrence.message.partition(/[^"]+/)[1]
                   occurrences = environment.occurrences.where("\"occurrences\".\"metadata\" LIKE ?", "%#{occurrence.message}%").joins(:bug).where(bugs: bug_search_criteria)
                   
                   if occurrences.empty?
                     environment.bugs.create! bug_attributes.merge(bug_search_criteria).merge(class_name: occurrence.bug.class_name)
                   else
                     occurrences.first.bug
                   end
                 end

      # If this code works as it should, there should only be one open record of
      # a Bug at any time. A bug occurs, a new Bug is created. A new release is
      # out, but it doesn't fix the bug, and that same Bug is reused. A new
      # release is out that DOES fix the bug, and the bug is closed. The bug
      # recurs, and a new open Bug is created.

      # Lastly, we need to resolve the bug if it's a duplicate.
      bug      = bug.duplicate_of(true) if bug.duplicate?

      return bug
    end

    def self.resolve_revision(project, revision)
      commit   = project.repo.object(revision)
      if commit.nil?
        project.repo(&:fetch)
        commit = project.repo.object(revision)
      end
      raise "Unknown revision" unless commit
      commit.sha
    end

    protected

    def bug_search_criteria
      commit = occurrence.commit || deploy.try!(:commit)
      raise "Need a resolvable commit" unless commit

      file, line, commit = blamed_revision(commit)
      {
          class_name:      occurrence.bug.class_name,
          file:             file,
          line:             line
          # blamed_revision:  commit.try!(:sha)
      }
    end

    private

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
      file, line         = file_and_line_for_bt_element(element)
      return file, line, commit
    end

    def file_and_line_for_bt_element(element)
      case element['type']
        when nil
          [element['file'], element['line']]
        when 'obfuscated'
          @special = true
          [element['file'], element['line'].abs]
        when 'js:hosted'
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
  end
end
