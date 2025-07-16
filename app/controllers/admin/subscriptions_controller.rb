class Admin::SubscriptionsController < Admin::BaseController
  before_action :set_user, only: [:edit, :update, :cancel, :pause, :resume]

  def index
    @subscriptions = User.where.not(subscription_status: nil)
    
    # Filter by status
    if params[:status].present?
      @subscriptions = @subscriptions.where(subscription_status: params[:status])
    end
    
    # Filter by plan
    if params[:plan].present?
      @subscriptions = @subscriptions.where(subscription_plan: params[:plan])
    end
    
    # Search
    if params[:search].present?
      search_term = params[:search].strip.downcase
      @subscriptions = @subscriptions.where(
        "LOWER(first_name) LIKE :search OR 
         LOWER(last_name) LIKE :search OR 
         LOWER(email) LIKE :search OR 
         LOWER(CONCAT(first_name, ' ', last_name)) LIKE :search",
        search: "%#{search_term}%"
      )
    end
    
    # Sort
    case params[:sort]
    when 'newest'
      @subscriptions = @subscriptions.order(created_at: :desc)
    when 'ending_soon'
      @subscriptions = @subscriptions.where.not(subscription_ends_at: nil).order(subscription_ends_at: :asc)
    when 'customer'
      @subscriptions = @subscriptions.order(:first_name, :last_name)
    else
      @subscriptions = @subscriptions.order(created_at: :desc)
    end
    
    @subscriptions = @subscriptions.includes(:profile_image_attachment).page(params[:page]).per(25)
    
    # Stats
    @total_active = User.where(subscription_status: 'active').count
    @total_canceled = User.where(subscription_status: 'canceled').count
    @total_revenue = calculate_monthly_revenue
  end

  def edit
    # Edit subscription details
  end

  def update
    if @user.update(subscription_params)
      # Log subscription change
      Rails.logger.info "Admin #{current_user.email} updated subscription for user #{@user.email}"
      
      # Handle special actions
      if params[:add_credits].present?
        credits_to_add = params[:add_credits].to_i
        @user.increment!(:credits, credits_to_add)
        flash[:notice] = "Added #{credits_to_add} credits to #{@user.full_name}"
      end
      
      redirect_to admin_subscriptions_path, notice: 'Subscription updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def cancel
    begin
      # Cancel in Stripe if subscription ID exists
      if @user.stripe_subscription_id.present?
        begin
          # Cancel the subscription immediately in Stripe
          subscription = Stripe::Subscription.cancel(@user.stripe_subscription_id)
          
          Rails.logger.info "Admin #{current_user.email} canceled Stripe subscription #{@user.stripe_subscription_id} for user #{@user.email}"
          
          # Update local database to match Stripe - clear the subscription ID since it's canceled
          @user.update!(
            stripe_subscription_id: nil,
            subscription_status: 'canceled',
            subscription_ends_at: Time.current,
            cancel_at_period_end: false
          )
        rescue Stripe::InvalidRequestError => e
          Rails.logger.error "Stripe subscription not found for cancellation: #{e.message}"
          # Subscription doesn't exist in Stripe, just update our database
          @user.update!(
            stripe_subscription_id: nil,
            subscription_status: 'canceled',
            subscription_ends_at: Time.current
          )
        end
      else
        # No Stripe subscription, just update our database
        @user.update!(
          subscription_status: 'canceled',
          subscription_ends_at: Time.current
        )
      end
      
      redirect_to admin_subscriptions_path, notice: "Subscription canceled for #{@user.full_name}"
    rescue Stripe::StripeError => e
      Rails.logger.error "Error canceling subscription: #{e.message}"
      redirect_to admin_subscriptions_path, alert: "Error canceling subscription: #{e.message}"
    end
  end

  def pause
    # TODO: Implement pause functionality with Stripe
    @user.update!(subscription_paused_at: Time.current)
    redirect_to admin_subscriptions_path, notice: "Subscription paused for #{@user.full_name}"
  end

  def resume
    # TODO: Implement resume functionality with Stripe
    @user.update!(subscription_paused_at: nil)
    redirect_to admin_subscriptions_path, notice: "Subscription resumed for #{@user.full_name}"
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def subscription_params
    params.require(:user).permit(
      :subscription_status,
      :subscription_plan,
      :subscription_ends_at,
      :credits
    )
  end

  def calculate_monthly_revenue
    # TODO: Calculate based on actual Stripe data
    active_users = User.where(subscription_status: 'active')
    monthly_users = active_users.where(subscription_plan: 'monthly').count
    annual_users = active_users.where(subscription_plan: 'annual').count
    
    (monthly_users * 9.99) + (annual_users * 99.99 / 12)
  end
end