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

class TrackBugsPerDevice < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE TABLE device_bugs (
          bug_id INTEGER NOT NULL REFERENCES bugs(id) ON DELETE CASCADE,
          device_id CHARACTER VARYING(126) NOT NULL,
          PRIMARY KEY (bug_id, device_id)
      )
    SQL
  end

  def down
    drop_table :device_bugs
  end
end
