class Admin::ActivitiesController < Admin::BaseController
  def index
    activities = ActivityLog.includes(:user, :trackable)

    # Filter by user
    if params[:user_id].present?
      activities = activities.where(user_id: params[:user_id])
      @selected_user = User.find(params[:user_id])
    end

    # Filter by activity type
    activities = activities.by_type(params[:activity_type]) if params[:activity_type].present?

    # Filter by date range
    activities = case params[:date_range]
                 when "today" then activities.today
                 when "week" then activities.this_week
                 when "month" then activities.this_month
                 else activities
                 end

    # Search
    if params[:search].present?
      search_term = params[:search].strip.downcase
      activities = activities.joins(:user).where(
        "LOWER(users.first_name) LIKE :search OR
         LOWER(users.last_name) LIKE :search OR
         LOWER(users.email) LIKE :search OR
         LOWER(activity_logs.activity_type) LIKE :search",
        search: "%#{search_term}%"
      )
    end

    @activities = activities.recent.page(params[:page]).per(50)

    # Stats
    @total_activities_today = ActivityLog.today.count
    @active_users_today = ActivityLog.today.distinct.count(:user_id)
    @most_common_activity = ActivityLog.this_week.group(:activity_type).count.max_by { |_, count| count }
  end

  def show
    @activity = ActivityLog.find(params[:id])
  end
end
