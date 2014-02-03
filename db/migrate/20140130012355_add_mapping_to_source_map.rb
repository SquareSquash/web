class AddMappingToSourceMap < ActiveRecord::Migration
  def up
    execute <<-SQL
      ALTER TABLE source_maps
        ADD COLUMN "from" CHARACTER VARYING(24) NOT NULL DEFAULT 'minified' CHECK (CHAR_LENGTH("from") > 0),
        ADD COLUMN "to" CHARACTER VARYING(24) NOT NULL DEFAULT 'original' CHECK (CHAR_LENGTH("to") > 0)
    SQL

    execute 'ALTER TABLE source_maps ALTER "from" DROP NOT NULL'
    execute 'ALTER TABLE source_maps ALTER "to" DROP NOT NULL'
    execute "DROP INDEX source_maps_env_revision"
    execute 'CREATE INDEX source_maps_env_revision ON source_maps(environment_id, revision, "from")'
  end

  def down
    execute 'ALTER TABLE source_maps DROP "from", DROP "to"'
  end
end
