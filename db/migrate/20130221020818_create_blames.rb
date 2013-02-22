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
