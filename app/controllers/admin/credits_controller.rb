class Admin::CreditsController < Admin::BaseController
  def index
    @users = User.all
    
    # Filter by credit balance
    if params[:filter].present?
      case params[:filter]
      when 'has_credits'
        @users = @users.where('credits > 0')
      when 'no_credits'
        @users = @users.where(credits: 0)
      when 'negative'
        @users = @users.where('credits < 0')
      end
    end
    
    # Search
    if params[:search].present?
      search_term = params[:search].strip.downcase
      @users = @users.where(
        "LOWER(first_name) LIKE :search OR 
         LOWER(last_name) LIKE :search OR 
         LOWER(email) LIKE :search OR 
         LOWER(CONCAT(first_name, ' ', last_name)) LIKE :search",
        search: "%#{search_term}%"
      )
    end
    
    # Sort
    case params[:sort]
    when 'most_credits'
      @users = @users.order(credits: :desc)
    when 'least_credits'
      @users = @users.order(credits: :asc)
    when 'name'
      @users = @users.order(:first_name, :last_name)
    else
      @users = @users.order(credits: :desc)
    end
    
    @users = @users.includes(:profile_image_attachment).page(params[:page]).per(25)
    
    # Stats
    @total_credits = User.sum(:credits)
    @users_with_credits = User.where('credits > 0').count
    @average_credits = User.average(:credits).to_f.round(2)
    @credit_transactions = [] # TODO: Implement credit transaction logging
  end

  def bulk_add
    if request.post?
      credits_to_add = params[:credits_to_add].to_i
      user_ids = params[:user_ids] || []
      
      if credits_to_add > 0 && user_ids.any?
        users = User.where(id: user_ids)
        users.update_all("credits = credits + #{credits_to_add}")
        
        flash[:notice] = "Added #{credits_to_add} credits to #{users.count} users"
        redirect_to admin_credits_path
      else
        flash[:alert] = "Please select users and enter a valid credit amount"
        redirect_to admin_credits_path
      end
    end
  end

  def transactions
    @transactions = [] # TODO: Implement credit transaction history
    
    # Placeholder for future implementation
    @transactions = [
      { user: User.first, amount: 1, type: 'monthly_grant', created_at: 1.day.ago },
      { user: User.last, amount: -1, type: 'presentation_purchase', created_at: 2.days.ago }
    ] if User.any?
  end

  def grant_monthly
    # Grant monthly credits to all active subscribers
    active_users = User.where(subscription_status: 'active')
    active_users.update_all("credits = credits + 1")
    
    flash[:notice] = "Granted 1 credit to #{active_users.count} active subscribers"
    redirect_to admin_credits_path
  end

  def adjust
    @user = User.find(params[:id])
    
    if request.post?
      adjustment = params[:adjustment].to_i
      reason = params[:reason]
      
      if adjustment != 0
        @user.increment!(:credits, adjustment)
        
        # TODO: Log this transaction
        Rails.logger.info "Admin #{current_user.email} adjusted credits for #{@user.email} by #{adjustment}: #{reason}"
        
        flash[:notice] = "Credits adjusted successfully"
        redirect_to admin_credits_path
      else
        flash[:alert] = "Please enter a valid adjustment amount"
      end
    end
  end
end