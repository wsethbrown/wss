class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :bottle, null: false, foreign_key: true
      # Present from day one; no Phase-1 UI sets it. Event flows are Phase 2.
      t.references :event, null: true, foreign_key: true
      t.decimal :rating, precision: 2, scale: 1, null: false
      t.text :notes
      t.string :nose
      t.string :palate
      t.string :finish
      t.string :body_notes

      t.timestamps
    end

    # One review per tasting context...
    add_index :reviews, [:user_id, :bottle_id, :event_id], unique: true
    # ...and NULL event_id rows are all "solo", so they need their own guard
    # (Postgres treats NULLs as distinct in the index above).
    add_index :reviews, [:user_id, :bottle_id], unique: true,
              where: "event_id IS NULL", name: "index_reviews_solo_uniqueness"
  end
end
