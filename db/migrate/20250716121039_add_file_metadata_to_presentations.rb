class AddFileMetadataToPresentations < ActiveRecord::Migration[8.0]
  def change
    add_column :presentations, :file_access_settings, :jsonb, default: {}
    add_column :presentations, :download_count, :integer, default: 0
    add_column :presentations, :preview_pages, :integer, default: 3
    
    add_index :presentations, :download_count
  end
end
