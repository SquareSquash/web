module Blamer
  class Message < Recency
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
  end
end
