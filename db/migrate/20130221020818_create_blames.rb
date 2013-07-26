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

class CreateBlames < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE UNLOGGED TABLE blames (
        id SERIAL PRIMARY KEY,
        repository_hash CHARACTER(40) NOT NULL,
        revision CHARACTER(40) NOT NULL,
        file CHARACTER VARYING(255) NOT NULL CHECK (CHAR_LENGTH(file) > 0),
        line INTEGER NOT NULL CHECK (line > 0),
        blamed_revision CHARACTER VARYING(40) NOT NULL,
        updated_at TIMESTAMP WITHOUT TIME ZONE
      )
    SQL

    execute "CREATE UNIQUE INDEX blames_key ON blames(repository_hash, revision, file, line)"
    execute "CREATE UNIQUE INDEX blames_lru ON blames(updated_at)"
  end

  def down
    drop_table :blames
  end
end
