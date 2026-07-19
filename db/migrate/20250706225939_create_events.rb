class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string :title, null: false
      t.text :description
      t.string :location
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.references :society, null: false, foreign_key: true
      t.references :organizer, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :events, :title
    add_index :events, :location
    add_index :events, :start_time
    add_index :events, [ :society_id, :start_time ]
  end
end
