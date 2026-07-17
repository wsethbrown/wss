class CreateShelfItems < ActiveRecord::Migration[8.0]
  # Blank AR classes so the backfill doesn't depend on app models.
  class MigrationBottle < ActiveRecord::Base
    self.table_name = "bottles"
  end

  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class MigrationShelfItem < ActiveRecord::Base
    self.table_name = "shelf_items"
  end

  def up
    create_table :shelf_items do |t|
      t.references :user, null: false, foreign_key: true
      t.references :bottle, foreign_key: true
      t.string :custom_name
      t.integer :position, null: false
      t.timestamps
    end
    add_index :shelf_items, [ :user_id, :bottle_id ], unique: true, where: "bottle_id IS NOT NULL"
    add_index :shelf_items, "user_id, lower(custom_name)", unique: true,
              where: "custom_name IS NOT NULL", name: "index_shelf_items_on_user_and_lower_custom_name"

    # Backfill from the legacy newline-separated users.whiskey_shelf. A line
    # becomes a linked entry only on an unambiguous case-insensitive name
    # match; anything else is kept verbatim as a free-text entry. The legacy
    # column is retained until the backfill is verified in production.
    MigrationUser.where.not(whiskey_shelf: [ nil, "" ]).find_each do |user|
      seen_bottle_ids = {}
      seen_names = {}
      position = 0
      user.whiskey_shelf.split("\n").map(&:strip).reject(&:blank?).each do |line|
        matches = MigrationBottle.where("lower(name) = ?", line.downcase).limit(2).pluck(:id)
        if matches.length == 1
          next if seen_bottle_ids[matches.first]

          seen_bottle_ids[matches.first] = true
          MigrationShelfItem.create!(user_id: user.id, bottle_id: matches.first, position: position += 1)
        else
          next if seen_names[line.downcase]

          seen_names[line.downcase] = true
          MigrationShelfItem.create!(user_id: user.id, custom_name: line, position: position += 1)
        end
      end
    end
  end

  def down
    drop_table :shelf_items
  end
end
