class CreateReviewReports < ActiveRecord::Migration[8.0]
  def change
    create_table :review_reports do |t|
      t.references :review, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "open"
      t.timestamps
    end

    # One report per person per review; reporting twice is a no-op.
    add_index :review_reports, [:user_id, :review_id], unique: true
    add_index :review_reports, :status
  end
end
