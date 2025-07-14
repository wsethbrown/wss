class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show]

  def index
    @users = User.includes(:profile_image_attachment)
                 .order(created_at: :desc)
    
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @users = @users.where(
        "email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?",
        search_term, search_term, search_term
      )
    end
    
    @users = @users.page(params[:page]).per(25)
  end

  def show
    @recent_purchases = @user.user_presentations
                            .includes(:presentation)
                            .order(created_at: :desc)
                            .limit(10)
    
    @society_memberships = @user.society_memberships
                               .includes(:society)
                               .order(created_at: :desc)
  end

  private

  def set_user
    @user = User.find(params[:id])
  end
end