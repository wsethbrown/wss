class Review < ApplicationRecord
  VALID_RATINGS = (1..10).map { |n| n / 2.0 }.freeze # 0.5 .. 5.0 in half steps

  belongs_to :user
  belongs_to :bottle
  belongs_to :event, optional: true

  validates :rating, presence: true, inclusion: { in: VALID_RATINGS }
  validates :notes, length: { maximum: 5_000 }
  validates :nose, :palate, :finish, :body_notes, length: { maximum: 500 }
  validates :bottle_id, uniqueness: {
    scope: [:user_id, :event_id],
    message: "already has your review — edit it instead"
  }
  validate :event_review_gates, on: :create, if: -> { event.present? }

  scope :recent_first, -> { order(created_at: :desc) }

  # A tasting outside any event.
  def solo? = event_id.nil?

  private

  # Event reviews are the society's record of the night — they only exist for
  # bottles that were actually poured, written by people who actually said
  # they were going, once the pour list is public knowledge. Create-only:
  # edits never re-check (a deleted RSVP must not brick an existing review),
  # and ReviewsController's strong params can't move a review between events.
  def event_review_gates
    unless event.event_bottles.exists?(bottle_id: bottle_id)
      errors.add(:base, "That bottle isn't on this event's pour list")
    end
    unless event.pours_revealed?
      errors.add(:base, "The pours haven't been revealed yet")
    end
    unless event.event_rsvps.exists?(user_id: user_id, status: "yes")
      errors.add(:base, %(Only members who RSVP'd "going" can review this event's pours))
    end
  end
end
