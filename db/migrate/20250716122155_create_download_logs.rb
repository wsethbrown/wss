class CreateDownloadLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :download_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :presentation, null: false, foreign_key: true
      t.string :file_type, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :downloaded_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :download_logs, [ :presentation_id, :file_type ]
    add_index :download_logs, [ :user_id, :downloaded_at ]
    add_index :download_logs, :downloaded_at
  end
end
