class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show, :edit, :update]

  def index
    @users = User.all
    
    # Search functionality
    if params[:search].present?
      search_term = params[:search].strip.downcase
      
      @users = @users.where(
        "LOWER(first_name) LIKE :search OR 
         LOWER(last_name) LIKE :search OR 
         LOWER(email) LIKE :search OR 
         LOWER(CONCAT(first_name, ' ', last_name)) LIKE :search OR
         id::text = :exact_search",
        search: "%#{search_term}%",
        exact_search: search_term
      )
    end
    
    # Filter by subscription status
    if params[:subscription_status].present?
      case params[:subscription_status]
      when 'active'
        @users = @users.where(subscription_status: 'active')
      when 'inactive'
        @users = @users.where.not(subscription_status: 'active').or(@users.where(subscription_status: nil))
      when 'canceled'
        @users = @users.where(subscription_status: 'canceled')
      end
    end
    
    # Sort
    case params[:sort]
    when 'newest'
      @users = @users.order(created_at: :desc)
    when 'oldest'
      @users = @users.order(created_at: :asc)
    when 'name'
      @users = @users.order(:first_name, :last_name)
    when 'credits'
      @users = @users.order(credits: :desc)
    else
      @users = @users.order(created_at: :desc)
    end
    
    # Pagination
    @users = @users.page(params[:page]).per(25)
    
    # Stats for dashboard
    @total_users = User.count
    @active_subscriptions = User.where(subscription_status: 'active').count
    @total_credits = User.sum(:credits)
  end

  def show
    @society_memberships = @user.society_memberships.includes(:society)
    @recent_purchases = @user.user_presentations.includes(:presentation).order(created_at: :desc).limit(5)
    @recent_activities = [] # TODO: Implement activity tracking
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: 'User updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :first_name, 
      :last_name, 
      :email, 
      :credits,
      :subscription_status,
      :subscription_plan,
      :bio
    )
  end
end