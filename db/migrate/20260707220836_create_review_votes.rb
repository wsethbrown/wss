class CreateReviewVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :review_votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :review, null: false, foreign_key: true
      t.timestamps
    end
    add_index :review_votes, [ :user_id, :review_id ], unique: true
    add_column :reviews, :votes_count, :integer, null: false, default: 0
  end
end
