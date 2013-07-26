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

class TrackCrashes < ActiveRecord::Migration
  def up
    execute "ALTER TABLE occurrences ADD COLUMN crashed BOOLEAN NOT NULL DEFAULT FALSE"
    execute "ALTER TABLE bugs ADD COLUMN any_occurrence_crashed BOOLEAN NOT NULL DEFAULT FALSE"

    execute <<-SQL
      CREATE FUNCTION bugs_new_crashed_occurrence() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
          BEGIN
            UPDATE bugs
              SET any_occurrence_crashed = EXISTS(
                SELECT 1
                  FROM occurrences o
                  WHERE
                    o.bug_id = NEW.bug_id AND
                    o.crashed IS TRUE
              )
              WHERE id = NEW.bug_id;
            RETURN NEW;
          END;
        $$
    SQL

    execute <<-SQL
      CREATE FUNCTION bugs_old_crashed_occurrence() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
          BEGIN
            UPDATE bugs
              SET any_occurrence_crashed = EXISTS(
                SELECT 1
                  FROM occurrences o
                  WHERE
                    o.bug_id = OLD.bug_id AND
                    o.crashed IS TRUE
              )
              WHERE id = OLD.bug_id;
            RETURN OLD;
          END;
        $$
    SQL

    execute <<-SQL
      CREATE TRIGGER occurrences_crashed_bug_updated
        AFTER INSERT OR UPDATE ON occurrences
        FOR EACH ROW
          EXECUTE PROCEDURE bugs_new_crashed_occurrence()
    SQL

    execute <<-SQL
      CREATE TRIGGER occurrences_crashed_bug_deleted
        AFTER DELETE ON occurrences
        FOR EACH ROW
          EXECUTE PROCEDURE bugs_old_crashed_occurrence()
    SQL

    execute "DROP INDEX bugs_env_fo, bugs_env_lo, bugs_env_oc"
    execute "CREATE INDEX bugs_list_fo ON bugs(environment_id, deploy_id, assigned_user_id, fixed, irrelevant, any_occurrence_crashed, first_occurrence, number)"
    execute "CREATE INDEX bugs_list_lo ON bugs(environment_id, deploy_id, assigned_user_id, fixed, irrelevant, any_occurrence_crashed, latest_occurrence, number)"
    execute "CREATE INDEX bugs_list_oc ON bugs(environment_id, deploy_id, assigned_user_id, fixed, irrelevant, any_occurrence_crashed, occurrences_count, number)"
  end

  def down
    execute "ALTER TABLE occurrences DROP COLUMN crashed"
    execute "ALTER TABLE bugs DROP COLUMN any_occurrence_crashed"

    execute "DROP INDEX bugs_list_fo, bugs_list_lo, bugs_list_oc"
    execute "CREATE INDEX bugs_env_fo ON bugs (environment_id, deploy_id, assigned_user_id, fixed, irrelevant, latest_occurrence, number)"
    execute "CREATE INDEX bugs_env_lo ON bugs (environment_id, deploy_id, assigned_user_id, fixed, irrelevant, first_occurrence, number)"
    execute "CREATE INDEX bugs_env_oc ON bugs (environment_id, deploy_id, assigned_user_id, fixed, irrelevant, occurrences_count, number)"
  end
end
