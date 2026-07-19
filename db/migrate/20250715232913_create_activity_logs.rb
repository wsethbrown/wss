class CreateActivityLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :trackable, polymorphic: true
      t.string :activity_type, null: false
      t.jsonb :metadata, default: {}
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :activity_logs, :activity_type
    add_index :activity_logs, :created_at
    add_index :activity_logs, [ :user_id, :created_at ]
  end
end
