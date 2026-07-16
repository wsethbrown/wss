# A member flagging a review (text or photos) for admin attention. Post-
# moderation by design: content stays public until an admin acts. One report
# per person per review; the admin queue shows open reports grouped by review.
class ReviewReport < ApplicationRecord
  STATUSES = %w[open dismissed].freeze

  belongs_to :review
  belongs_to :user

  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :review_id }
  validate :cannot_report_own_review

  scope :open_reports, -> { where(status: "open") }

  private

  # Reporting your own review is a mistake, not moderation.
  def cannot_report_own_review
    errors.add(:base, "You can't report your own review") if review && user_id == review.user_id
  end
end
