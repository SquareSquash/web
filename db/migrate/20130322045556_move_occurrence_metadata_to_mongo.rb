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

class MoveOccurrenceMetadataToMongo < ActiveRecord::Migration
  def up
    Occurrence.where('metadata IS NOT NULL').find_each do |occurrence|
      JSON.parse(occurrence.metadata).each do |key, value|
        occurrence._attribute_record[key] = value
        occurrence._attribute_record.crashed = occurrence.crashed
      end
      occurrence._attribute_record.save!
    end

    execute "ALTER TABLE occurrences DROP COLUMN metadata, DROP COLUMN crashed"
    execute "DROP TRIGGER occurrences_crashed_bug_deleted ON occurrences"
    execute "DROP TRIGGER occurrences_crashed_bug_updated ON occurrences"
    execute "DROP FUNCTION bugs_new_crashed_occurrence()"
    execute "DROP FUNCTION bugs_old_crashed_occurrence()"
  end

  def down
    execute "ALTER TABLE occurrences ADD COLUMN metadata TEXT, ADD COLUMN crashed BOOLEAN"

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

    execute "CREATE TRIGGER occurrences_crashed_bug_deleted AFTER DELETE ON occurrences FOR EACH ROW EXECUTE PROCEDURE bugs_old_crashed_occurrence()"
    execute "CREATE TRIGGER occurrences_crashed_bug_updated AFTER INSERT OR UPDATE ON occurrences FOR EACH ROW EXECUTE PROCEDURE bugs_new_crashed_occurrence()"

    OccurrenceData.all.each do |data|
      occ = Occurrence.find_by_id(data.occurrence_id)
      next unless occ
      occ.update_column :metadata, data.attributes.to_json
      occ.update_column :crashed, data.crashed
    end
  end
end
