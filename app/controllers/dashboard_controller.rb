class DashboardController < ApplicationController
  def index
    @user_societies = current_user.member_societies.includes(:creator).limit(5)
    @user_events = current_user.events.upcoming.includes(:society).limit(5)
    @upcoming_rsvps = current_user.event_rsvps.for_upcoming_events.includes(:event).limit(5)
    @user_presentations = current_user.presentations.recent.limit(5)
    @recent_presentations = Presentation.includes(:author).recent.limit(5)
  end
end
