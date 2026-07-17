class CreateEventComments < ActiveRecord::Migration[8.0]
  def change
    create_table :event_comments do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end
    add_index :event_comments, [ :event_id, :created_at ]
  end
end
