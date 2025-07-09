class CreateUserPresentations < ActiveRecord::Migration[8.0]
  def change
    create_table :user_presentations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :presentation, null: false, foreign_key: true
      t.string :purchase_type
      t.datetime :purchased_at

      t.timestamps
    end
  end
end
