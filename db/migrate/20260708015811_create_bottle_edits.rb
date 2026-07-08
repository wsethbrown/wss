class CreateBottleEdits < ActiveRecord::Migration[8.0]
  def change
    create_table :bottle_edits do |t|
      t.references :bottle, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :field, null: false
      t.string :proposed_value, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :applied_at
      t.references :applied_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :bottle_edits, [ :bottle_id, :field, :user_id ], unique: true,
      where: "status = 'pending'", name: "index_bottle_edits_on_live_proposal"
    add_index :bottle_edits, [ :bottle_id, :field, :status ], name: "index_bottle_edits_on_bottle_field_status"
  end
end
