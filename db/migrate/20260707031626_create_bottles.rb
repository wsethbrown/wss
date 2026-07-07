class CreateBottles < ActiveRecord::Migration[8.0]
  def change
    create_table :bottles do |t|
      t.string :name, null: false
      t.string :distillery
      t.string :region
      t.string :style
      t.decimal :abv, precision: 4, scale: 1
      t.string :slug, null: false
      t.references :created_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :bottles, :slug, unique: true
    # Case-insensitive lookup for autocomplete and near-match warnings.
    add_index :bottles, "lower(name), lower(coalesce(distillery, ''))",
              name: "index_bottles_on_lower_name_distillery"
  end
end
