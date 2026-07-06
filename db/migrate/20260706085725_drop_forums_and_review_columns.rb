class DropForumsAndReviewColumns < ActiveRecord::Migration[8.0]
  def change
    # Forums were never built (no routes/UI); ratings had no review system —
    # both were dead weight. "Popular" now means actual purchase count.
    drop_table :forums, if_exists: true
    remove_column :presentations, :rating, :decimal, if_exists: true
    remove_column :presentations, :review_count, :integer, if_exists: true
  end
end
