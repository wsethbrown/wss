# Deck reviews (owner-approved design, built July 2026): star rating +
# short text on a deck, one per person. Eligibility is the owner's rule,
# enforced here at create so no controller can skip it: the reviewer
# PURCHASED the deck, or ATTENDED (RSVP yes) an already-finished event
# that ran it. Ties the societies side to the marketplace.
class PresentationReview < ApplicationRecord
  belongs_to :presentation
  belongs_to :user

  VALID_RATINGS = Review::VALID_RATINGS

  validates :rating, presence: true, inclusion: { in: VALID_RATINGS }
  validates :body, length: { maximum: 1000 }
  validates :user_id, uniqueness: { scope: :presentation_id, message: "has already reviewed this deck" }
  validate :reviewer_is_eligible, on: :create

  scope :recent, -> { order(created_at: :desc) }

  # Keep the deck's cached summary honest through every path (create, rating
  # edit, delete). after_commit so it reflects what actually landed.
  after_commit :refresh_presentation_stats

  private def refresh_presentation_stats
    presentation.refresh_review_stats!
  rescue => e
    Rails.logger.error "Deck #{presentation_id}: review stats refresh failed after review #{id}: #{e.class}: #{e.message}"
  end
  public

  def self.eligible?(user, presentation)
    return false unless user && presentation
    return true if UserPresentation.exists?(user_id: user.id, presentation_id: presentation.id)

    EventRsvp.joins(:event)
             .where(user_id: user.id, status: "yes")
             .where(events: { presentation_id: presentation.id })
             .where(events: { end_time: ..Time.current })
             .exists?
  end

  private

  def reviewer_is_eligible
    unless self.class.eligible?(user, presentation)
      errors.add(:base, "You can review a deck after you've bought it or attended a night that ran it")
    end
  end
end
