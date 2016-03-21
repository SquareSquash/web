class AddHostedFilenameToSourceMaps < ActiveRecord::Migration
  def up
    add_column :source_maps, :filename, :string, limit: 255

    say "Updating existing source maps"
    SourceMap.reset_column_information
    SourceMap.find_each(batch_size: 50) do |map|
      map.update_attribute :filename, map.map.filename
    end

    change_column :source_maps, :filename, :string, null: false, limit: 255

    add_index :source_maps, :filename
  end

  def down
    remove_column :source_maps, :filename
  end
end
