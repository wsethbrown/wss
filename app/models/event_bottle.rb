# A pour on an event's lineup, in order. Managed by the organizer or society
# admins; the reviews that reference it are the society's record of the night.
class EventBottle < ApplicationRecord
  belongs_to :event
  belongs_to :bottle

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :label, length: { maximum: 100 }
  validates :bottle_id, uniqueness: { scope: :event_id, message: "is already on this event's pour list" }

  scope :ordered, -> { order(:position, :id) }

  before_destroy :keep_reviewed_pours

  # The night's reviews of this pour: event-tagged only. Solo reviews of the
  # same bottle never count here (spec's aggregation table).
  def reviews
    event.reviews.where(bottle_id: bottle_id)
  end

  def group_average
    reviews.average(:rating)&.to_f&.round(2)
  end

  private

  def keep_reviewed_pours
    return if reviews.none?

    errors.add(:base, "Can't remove a pour that has reviews")
    throw :abort
  end
end
