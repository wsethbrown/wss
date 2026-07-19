class CreatePresentationBottles < ActiveRecord::Migration[8.0]
  def change
    # A deck's pour list, linked to real catalog bottles (Phase 3 "deck ties").
    # Mirrors event_bottles: ordered rows with an optional label, so the deck
    # can say "pour #2, the ringer" while still pointing at a real Bottle —
    # which is what lets a deck show what societies thought of its pours, and
    # a bottle show which decks call for it.
    create_table :presentation_bottles do |t|
      t.references :presentation, null: false, foreign_key: true
      t.references :bottle, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :label
      t.timestamps
    end
    add_index :presentation_bottles, [:presentation_id, :bottle_id], unique: true
  end
end
