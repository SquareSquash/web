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
