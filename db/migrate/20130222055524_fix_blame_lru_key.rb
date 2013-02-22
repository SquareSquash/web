class FixBlameLruKey < ActiveRecord::Migration
  def up
    execute "DROP INDEX blames_lru"
    execute "CREATE INDEX blames_lru ON blames(updated_at)"
  end

  def down
    execute "DROP INDEX blames_lru"
    execute "CREATE UNIQUE INDEX blames_lru ON blames(updated_at)"
  end
end
