class Event < ApplicationRecord
  belongs_to :society
  belongs_to :organizer, class_name: 'User'

  # Associations
  has_many :event_rsvps, dependent: :destroy
  has_many :attendees, through: :event_rsvps, source: :user

  # Validations
  validates :title, presence: true, length: { minimum: 2, maximum: 200 }
  validates :description, length: { maximum: 2000 }
  validates :location, length: { maximum: 200 }
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time

  # Scopes
  scope :upcoming, -> { where('start_time > ?', Time.current).order(:start_time) }
  scope :past, -> { where('start_time < ?', Time.current).order(start_time: :desc) }
  scope :today, -> { where(start_time: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(start_time: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :by_society, ->(society_id) { where(society_id: society_id) if society_id.present? }
  scope :search, ->(query) { where('title ILIKE ? OR description ILIKE ?', "%#{query}%", "%#{query}%") if query.present? }

  # Instance methods
  def confirmed_attendees
    event_rsvps.where(status: 'confirmed').includes(:user)
  end

  def confirmed_attendee_count
    event_rsvps.where(status: 'confirmed').count
  end

  def pending_rsvps
    event_rsvps.where(status: 'pending').includes(:user)
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

  def can_rsvp?(user)
    return false unless user
    return false if past?
    !event_rsvps.exists?(user: user)
  end

  def user_rsvp_status(user)
    return nil unless user
    rsvp = event_rsvps.find_by(user: user)
    rsvp&.status
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time
    if end_time <= start_time
      errors.add(:end_time, 'must be after start time')
    end
  end
end
