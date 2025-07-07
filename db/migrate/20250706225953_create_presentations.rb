class CreatePresentations < ActiveRecord::Migration[8.0]
  def change
    create_table :presentations do |t|
      t.string :title, null: false
      t.text :description
      t.text :content
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.decimal :price, precision: 10, scale: 2, default: 0.0
      t.string :category

      t.timestamps
    end

    add_index :presentations, :title
    add_index :presentations, :category
    add_index :presentations, :price
  end
end
