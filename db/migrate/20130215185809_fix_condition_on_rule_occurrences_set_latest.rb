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
