# The bell's landing page: newest first, unread highlighted once, then
# everything is marked read (visiting the page IS acknowledging it).
class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications.recent.includes(:actor, :notifiable).limit(50).to_a
    @unread_ids = @notifications.reject(&:read?).map(&:id)
    current_user.notifications.unread.update_all(read_at: Time.current)
  end
end
