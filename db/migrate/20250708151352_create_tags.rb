class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :color, null: false, default: '#3B82F6'
      t.string :category, default: 'whiskey'
      t.text :description

      t.timestamps
    end

    add_index :tags, :name, unique: true
    add_index :tags, :category
  end
end
