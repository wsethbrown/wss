class AddReviewStatsToPresentations < ActiveRecord::Migration[8.0]
  def up
    # Cached summary so deck cards (rendered in bulk on the homepage and the
    # library) cost no queries. ALWAYS recomputed from presentation_reviews by
    # Presentation#refresh_review_stats! — never incremented in place, same
    # discipline as the credits cache.
    add_column :presentations, :reviews_count, :integer, null: false, default: 0
    add_column :presentations, :reviews_average, :decimal, precision: 3, scale: 2

    up_only do
      execute <<~SQL
        UPDATE presentations SET
          reviews_count = COALESCE(stats.count, 0),
          reviews_average = stats.average
        FROM (
          SELECT presentation_id, COUNT(*) AS count, AVG(rating) AS average
          FROM presentation_reviews GROUP BY presentation_id
        ) stats
        WHERE presentations.id = stats.presentation_id
      SQL
    end
  end

  def down
    remove_column :presentations, :reviews_count
    remove_column :presentations, :reviews_average
  end
end
