class FixConditionOnRuleOccurrencesSetLatest < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE OR REPLACE RULE occurrences_set_latest AS
        ON INSERT TO occurrences DO
          UPDATE bugs
            SET latest_occurrence = NEW.occurred_at
            WHERE (bugs.id = NEW.bug_id)
              AND ((bugs.latest_occurrence IS NULL)
              OR (bugs.latest_occurrence < NEW.occurred_at))
    SQL
  end

  def down
    execute <<-SQL
      CREATE OR REPLACE RULE occurrences_set_latest AS
        ON INSERT TO occurrences DO
          UPDATE bugs
            SET latest_occurrence = NEW.occurred_at
            WHERE (bugs.id = NEW.bug_id)
              AND (bugs.latest_occurrence IS NULL)
              OR (bugs.latest_occurrence < NEW.occurred_at)
    SQL
  end
end
