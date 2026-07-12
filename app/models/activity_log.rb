class ActivityLog < ApplicationRecord
  belongs_to :user
  belongs_to :trackable, polymorphic: true, optional: true

  # Activity types. Keep this list in lockstep with what controllers emit,
  # the inclusion validation below SILENTLY discards unknown types (the logger
  # swallows the error), which is how paused/resumed events went unrecorded
  # for months. presentation_viewed was retired (per-view rows, unused);
  # downloads live in DownloadLog, not here.
  ACTIVITY_TYPES = {
    login: 'User Login',
    logout: 'User Logout',
    presentation_purchased: 'Presentation Purchased',
    society_joined: 'Society Joined',
    society_left: 'Society Left',
    event_rsvp: 'Event RSVP',
    profile_updated: 'Profile Updated',
    subscription_created: 'Subscription Created',
    subscription_canceled: 'Subscription Canceled',
    subscription_paused: 'Subscription Paused',
    subscription_resumed: 'Subscription Resumed',
    credits_used: 'Credits Used',
    credits_added: 'Credits Added'
  }.freeze

  validates :activity_type, presence: true, inclusion: { in: ACTIVITY_TYPES.keys.map(&:to_s) }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(activity_type: type) }
  scope :today, -> { where(created_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(created_at: 1.week.ago..Time.current) }
  scope :this_month, -> { where(created_at: 1.month.ago..Time.current) }

  def activity_description
    ACTIVITY_TYPES[activity_type.to_sym] || activity_type.humanize
  end

  def trackable_name
    return nil unless trackable

    case trackable_type
    when 'Presentation'
      trackable.title
    when 'Society'
      trackable.name
    when 'Event'
      trackable.title
    when 'User'
      trackable.full_name
    else
      trackable.try(:name) || trackable.try(:title) || "#{trackable_type} ##{trackable_id}"
    end
  end

  # Class method to log activities. IP/UA live in their own columns only.
  def self.log_activity(user, activity_type, trackable = nil, metadata = {}, ip_address: nil, user_agent: nil)
    create!(
      user: user,
      activity_type: activity_type.to_s,
      trackable: trackable,
      metadata: metadata,
      ip_address: ip_address || metadata[:ip_address],
      user_agent: user_agent || metadata[:user_agent]
    )
  end
end