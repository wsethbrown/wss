class Event < ApplicationRecord
  belongs_to :society
  belongs_to :organizer, class_name: "User"

  # Associations
  has_many :event_rsvps, dependent: :destroy
  has_many :attendees, through: :event_rsvps, source: :user
  # Reviews are members' words, an event that has them can't be deleted.
  has_many :reviews, dependent: :restrict_with_error
  has_many :event_bottles, dependent: :destroy
  has_many :pour_bottles, through: :event_bottles, source: :bottle
  has_many :event_comments, dependent: :destroy

  # Validations
  validates :title, presence: true, length: { minimum: 2, maximum: 200 }
  validates :description, length: { maximum: 2000 }
  validates :location, length: { maximum: 200 }
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time

  # Scopes
  scope :upcoming, -> { where("start_time > ?", Time.current).order(:start_time) }
  scope :past, -> { where("start_time < ?", Time.current).order(start_time: :desc) }
  scope :today, -> { where(start_time: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(start_time: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :by_society, ->(society_id) { where(society_id: society_id) if society_id.present? }
  scope :search, ->(query) { where("title ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%") if query.present? }

  # Instance methods
  def yes_attendees
    User.joins(:event_rsvps).where(event_rsvps: { event_id: id, status: "yes" })
  end

  def maybe_attendees
    User.joins(:event_rsvps).where(event_rsvps: { event_id: id, status: "maybe" })
  end

  def no_attendees
    User.joins(:event_rsvps).where(event_rsvps: { event_id: id, status: "no" })
  end

  def yes_count
    event_rsvps.where(status: "yes").count
  end

  def maybe_count
    event_rsvps.where(status: "maybe").count
  end

  def no_count
    event_rsvps.where(status: "no").count
  end

  # Legacy method for compatibility - returns "Yes" attendees
  def confirmed_attendees
    yes_attendees
  end

  def confirmed_attendee_count
    yes_count
  end

  def total_rsvp_count
    event_rsvps.count
  end

  def potential_attendees
    society.members
  end

  def unanswered_count
    # Get society members who haven't RSVPd
    society.members.where.not(id: event_rsvps.select(:user_id)).count
  end

  def unanswered_users
    society.members.where.not(id: event_rsvps.select(:user_id))
  end

  def upcoming?
    start_time > Time.current
  end

  def past?
    start_time < Time.current
  end

  def ongoing?
    start_time <= Time.current && end_time >= Time.current
  end

  def duration
    return nil unless start_time && end_time
    (end_time - start_time) / 1.hour
  end

  def rsvp_closed?
    start_time <= 24.hours.from_now
  end

  def can_rsvp?(user)
    return false unless user
    return false if past? || rsvp_closed?
    !event_rsvps.exists?(user: user)
  end

  def user_rsvp_status(user)
    return nil unless user
    rsvp = event_rsvps.find_by(user: user)
    rsvp&.status
  end

  # --- Pours (review system Phase 2) ---

  # Secret pours auto-reveal once the night ends; non-secret pours are
  # always revealed (even before the event happens).
  def pours_revealed?
    !pours_hidden_until_complete? || (end_time.present? && end_time <= Time.current)
  end

  def pours_visible_to?(user)
    pours_revealed? || managed_by?(user)
  end

  # Table talk stays open until a week after the night ends.
  def comments_open?
    Time.current <= end_time + 7.days
  end

  # Mirrors EventPolicy#update?, the people who run the night.
  def managed_by?(user)
    return false unless user

    user.admin? || organizer_id == user.id || society.has_admin?(user)
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end
