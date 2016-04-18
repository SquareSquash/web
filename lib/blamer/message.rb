module Blamer
  class Message < Base

    def self.resolve_revision(project, revision)
      commit   = project.repo.object(revision)
      if commit.nil?
        project.repo(&:fetch)
        commit = project.repo.object(revision)
      end
      raise "Unknown revision" unless commit
      commit.sha
    end

    def find_or_create_bug!
      criteria = bug_search_criteria
      bug = if deploy
        b = Bug.transaction do
            environment.bugs.where(criteria.merge(deploy_id: deploy.id)).first ||
                environment.bugs.where(criteria.merge(fixed: false)).find_or_create!(bug_attributes)
        end

        b.deploy = deploy
        b
      else
        # This call to partition is used to remove speech marks (") from around the message.
        occurrence.message = occurrence.message.partition(/[^"]+/)[1]
        occurrences = environment.occurrences.where("\"occurrences\".\"metadata\" LIKE ?", "%#{occurrence.message}%").joins(:bug).where(bugs: bug_search_criteria)

        if occurrences.empty?
          environment.bugs.create! bug_attributes.merge(bug_search_criteria).merge(class_name: occurrence.bug.class_name)
        else
          occurrences.first.bug
        end
      end
               
      bug = bug.duplicate_of(true) if bug.duplicate?

      return bug
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
