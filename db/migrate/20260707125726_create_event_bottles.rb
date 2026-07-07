class CreateEventBottles < ActiveRecord::Migration[8.0]
  def change
    create_table :event_bottles do |t|
      t.references :event, null: false, foreign_key: true
      t.references :bottle, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :label

      t.timestamps
    end

    add_index :event_bottles, [:event_id, :bottle_id], unique: true
    add_index :event_bottles, [:event_id, :position]

    # The secret toggle: while true and the event hasn't ended, the pour list
    # is hidden from everyone except the organizer/society admins.
    add_column :events, :pours_hidden_until_complete, :boolean, null: false, default: false
  end
end
