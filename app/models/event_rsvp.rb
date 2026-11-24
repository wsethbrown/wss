class EventRsvp < ApplicationRecord
  belongs_to :user
  belongs_to :event

  # Enums - Yes/Maybe/No RSVP system
  enum :status, { yes: "yes", maybe: "maybe", no: "no" }

  # Validations
  validates :user_id, uniqueness: { scope: :event_id, message: "has already RSVPed to this event" }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validate :event_not_past
  validate :rsvp_window_open

  # Note: Rails generates scopes automatically for enums
  # .yes, .maybe, .no are available
  scope :for_upcoming_events, -> { joins(:event).where("events.start_time > ?", Time.current) }

  # Instance methods
  def yes?
    status == "yes"
  end

  def maybe?
    status == "maybe"
  end

  def no?
    status == "no"
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
      errors.add(:base, "Cannot RSVP to past events")
    end
  end

  # Answers stay changeable until the night starts; the kitchen still needs a
  # headcount, so a NEW yes closes 24 hours out (see Event#answer_allowed?).
  # Re-saving an existing yes (a note edit) is not a new yes.
  def rsvp_window_open
    return unless event
    return if event.past? # event_not_past already says so

    previous = persisted? ? status_in_database : nil
    unless event.answer_allowed?(status, previous)
      errors.add(:base, "New yes answers close 24 hours before the event")
    end
  end
end
