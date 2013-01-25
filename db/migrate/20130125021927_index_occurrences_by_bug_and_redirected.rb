class IndexOccurrencesByBugAndRedirected < ActiveRecord::Migration
  def up
    execute "CREATE INDEX occurrences_bug_redirect ON occurrences(bug_id, redirect_target_id)"
  end

  def down
    execute "DROP INDEX occurrences_bug_redirect"
  end
end

