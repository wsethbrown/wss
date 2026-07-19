class CreatePresentationReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :presentation_reviews do |t|
      t.references :presentation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :rating, precision: 2, scale: 1, null: false
      t.text :body
      t.timestamps
    end
    add_index :presentation_reviews, [:presentation_id, :user_id], unique: true
  end
end
