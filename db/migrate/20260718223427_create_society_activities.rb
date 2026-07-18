class CreateSocietyActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :society_activities do |t|
      t.references :society, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :detail
      t.timestamps
    end
    add_index :society_activities, [:society_id, :created_at]
  end
end
