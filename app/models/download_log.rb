class DownloadLog < ApplicationRecord
  belongs_to :user
  belongs_to :presentation

  validates :file_type, presence: true, inclusion: { 
    in: %w[sneak_peek full_presentation speaker_notes outline recommendations] 
  }
  validates :downloaded_at, presence: true

  # Scopes for analytics
  scope :recent, -> { order(downloaded_at: :desc) }
  scope :by_file_type, ->(type) { where(file_type: type) }
  scope :by_presentation, ->(presentation) { where(presentation: presentation) }
  scope :by_user, ->(user) { where(user: user) }
  scope :today, -> { where(downloaded_at: Date.current.all_day) }
  scope :this_week, -> { where(downloaded_at: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :this_month, -> { where(downloaded_at: Date.current.beginning_of_month..Date.current.end_of_month) }

  # Analytics methods
  def self.download_stats_for_presentation(presentation)
    by_presentation(presentation).group(:file_type).count
  end

  def self.popular_downloads(limit = 10)
    select('presentation_id, COUNT(*) as download_count')
      .group(:presentation_id)
      .order('download_count DESC')
      .limit(limit)
      .includes(:presentation)
  end

  def self.user_download_history(user, limit = 20)
    by_user(user)
      .includes(:presentation)
      .recent
      .limit(limit)
  end
end