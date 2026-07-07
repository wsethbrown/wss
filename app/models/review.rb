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

  scope :recent_first, -> { order(created_at: :desc) }

  # A tasting outside any event. Event-tagged reviews arrive in Phase 2.
  def solo? = event_id.nil?
end
