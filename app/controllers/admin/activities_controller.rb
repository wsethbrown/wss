class Admin::ActivitiesController < Admin::BaseController
  def index
    @activities = ActivityLog.includes(:user, :trackable)
    
    # Filter by user
    if params[:user_id].present?
      @activities = @activities.where(user_id: params[:user_id])
      @selected_user = User.find(params[:user_id])
    end
    
    # Filter by activity type
    if params[:activity_type].present?
      @activities = @activities.by_type(params[:activity_type])
    end
    
    # Filter by date range
    case params[:date_range]
    when 'today'
      @activities = @activities.today
    when 'week'
      @activities = @activities.this_week
    when 'month'
      @activities = @activities.this_month
    end
    
    # Search
    if params[:search].present?
      search_term = params[:search].strip.downcase
      @activities = @activities.joins(:user).where(
        "LOWER(users.first_name) LIKE :search OR 
         LOWER(users.last_name) LIKE :search OR 
         LOWER(users.email) LIKE :search OR 
         LOWER(activity_logs.activity_type) LIKE :search",
        search: "%#{search_term}%"
      )
    end
    
    @activities = @activities.recent.page(params[:page]).per(50)
    
    # Stats
    @total_activities_today = ActivityLog.today.count
    @active_users_today = ActivityLog.today.distinct.count(:user_id)
    @most_common_activity = ActivityLog.this_week.group(:activity_type).count.max_by { |_, count| count }
  end

  def show
    @activity = ActivityLog.find(params[:id])
  end
end