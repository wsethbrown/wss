class EventRsvp < ApplicationRecord
  belongs_to :user
  belongs_to :event

  # Enums
  enum status: { pending: 'pending', confirmed: 'confirmed', declined: 'declined', cancelled: 'cancelled' }

  # Validations
  validates :user_id, uniqueness: { scope: :event_id, message: 'has already RSVPed to this event' }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validate :event_not_past

  # Scopes
  scope :confirmed, -> { where(status: 'confirmed') }
  scope :pending, -> { where(status: 'pending') }
  scope :for_upcoming_events, -> { joins(:event).where('events.start_time > ?', Time.current) }

  # Instance methods
  def confirmed?
    status == 'confirmed'
  end

  def pending?
    status == 'pending'
  end

  def declined?
    status == 'declined'
  end

  def cancelled?
    status == 'cancelled'
  end

  def can_cancel?
    confirmed? && event.upcoming?
  end

  private

  def event_not_past
    return unless event
    if event.past?
      errors.add(:base, 'Cannot RSVP to past events')
    end
  end
end
