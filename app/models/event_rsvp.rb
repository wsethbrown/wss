class EventRsvp < ApplicationRecord
  belongs_to :user
  belongs_to :event

  # Enums - Yes/Maybe/No RSVP system
  enum :status, { yes: 'yes', maybe: 'maybe', no: 'no' }

  # Validations
  validates :user_id, uniqueness: { scope: :event_id, message: 'has already RSVPed to this event' }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validate :event_not_past
  validate :rsvp_window_open

  # Note: Rails generates scopes automatically for enums
  # .yes, .maybe, .no are available
  scope :for_upcoming_events, -> { joins(:event).where('events.start_time > ?', Time.current) }

  # Instance methods
  def yes?
    status == 'yes'
  end

  def maybe?
    status == 'maybe'
  end

  def no?
    status == 'no'
  end

  def attending?
    yes?
  end

  def can_change_response?
    event.upcoming? && !event.rsvp_closed?
  end

  private

  def event_not_past
    return unless event
    if event.past?
      errors.add(:base, 'Cannot RSVP to past events')
    end
  end

  # The kitchen needs a headcount: RSVPs close a day before the night.
  def rsvp_window_open
    return unless event
    if event.rsvp_closed? && !event.past?
      errors.add(:base, 'RSVPs close 24 hours before the event')
    end
  end
end
