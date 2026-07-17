# A comment on a single tasting night's page ("Table talk"). Deliberately NOT
# a forum (that was rejected): flat, scoped to one event, and the window
# closes a week after the night ends. Old comments stay readable forever;
# only creation is gated.
class EventComment < ApplicationRecord
  belongs_to :event
  belongs_to :user

  validates :body, presence: true, length: { maximum: 2000 }
  validate :window_open, on: :create

  scope :ordered, -> { order(:created_at, :id) }

  private

  def window_open
    return unless event
    errors.add(:base, "Comments close a week after the night") unless event.comments_open?
  end
end
