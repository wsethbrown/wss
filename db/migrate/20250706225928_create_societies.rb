class CreateSocieties < ActiveRecord::Migration[8.0]
  def change
    create_table :societies do |t|
      t.string :name, null: false
      t.text :description
      t.string :location
      t.references :creator, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :societies, :name
    add_index :societies, :location
  end
end
