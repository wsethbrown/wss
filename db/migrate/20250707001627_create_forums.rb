class CreateForums < ActiveRecord::Migration[8.0]
  def change
    create_table :forums do |t|
      t.references :society, null: false, foreign_key: true
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
