class CreateEventRsvps < ActiveRecord::Migration[8.0]
  def change
    create_table :event_rsvps do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'

      t.timestamps
    end

    add_index :event_rsvps, [:user_id, :event_id], unique: true
    add_index :event_rsvps, :status
  end
end
