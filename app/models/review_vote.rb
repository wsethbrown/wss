# A thumbs-up on a review. No downvotes. Maintains reviews.votes_count via
# counter_cache for bottle-page ordering; the hot feed's 30-day window still
# needs a real join (Review.hot_ranked) since this cache is lifetime-total.
class ReviewVote < ApplicationRecord
  belongs_to :user
  belongs_to :review, counter_cache: :votes_count

  validates :review_id, uniqueness: { scope: :user_id }
  validate :not_own_review

  private

  def not_own_review
    errors.add(:base, "You can't vote for your own review") if review && review.user_id == user_id
  end
end
