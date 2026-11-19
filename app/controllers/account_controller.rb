class AccountController < ApplicationController
  include ActivityLogger

  include RateLimitedResponses

  EMAIL_CHANGE_LIMIT = 5  # email-change requests per user per hour
  EMAIL_CHANGE_WINDOW = 1.hour

  before_action :authenticate_user!
  rate_limit to: EMAIL_CHANGE_LIMIT, within: EMAIL_CHANGE_WINDOW, only: :request_email_change, store: RateLimitStore,
             by: -> { "user-#{current_user.id}" }, with: -> { rate_limit_response("user") }

  def index
    # Clear any expired email change requests
    current_user.clear_expired_email_change

    # Landing back from Stripe Checkout. On success, grant the welcome
    # credit NOW, synchronously, so it's on screen with the banner (the
    # invoice.payment_succeeded webhook stays as the closed-tab fallback;
    # grant_welcome_credit dedups the two). Then redirect to strip the
    # ?subscription param, flash makes the banner one-shot instead of
    # immortal across refreshes.
    if params[:subscription].present?
      ensure_welcome_credit_after_checkout if params[:subscription] == "success"
      flash[:checkout_result] = params[:subscription]
      return redirect_to account_path(anchor: "subscription")
    end

    @available_tags = Tag.order(:category, :name)
    @user_tags = current_user.tags.order(:category, :name)

    # Fetch Stripe products if available
    @stripe_products = fetch_stripe_products
  end

  def update_profile
    if current_user.update(profile_params)
      log_activity(:profile_updated, current_user, { fields: profile_params.keys })
      respond_to do |format|
        format.html { redirect_to account_path, notice: "Profile updated successfully" }
        format.turbo_stream { redirect_to account_path, notice: "Profile updated successfully" }
      end
    else
      respond_to do |format|
        format.html { redirect_to account_path, alert: "Failed to update profile" }
        format.turbo_stream { redirect_to account_path, alert: "Failed to update profile" }
      end
    end
  end

  def update_tags
    current_user.user_tags.destroy_all

    if params[:tag_ids].present?
      params[:tag_ids].each do |tag_id|
        tag = Tag.find(tag_id)
        current_user.user_tags.create(tag: tag)
      end
    end

    redirect_to account_path
  end

  def upload_avatar
    if params[:profile_image].present?
      current_user.profile_image.attach(params[:profile_image])
      message = "Profile photo updated successfully"
    else
      message = "No photo selected"
    end

    respond_to do |format|
      format.html { redirect_to account_path, notice: message }
      format.turbo_stream { redirect_to account_path, notice: message }
    end
  end

  def remove_avatar
    if current_user.profile_image.attached?
      current_user.profile_image.purge
      message = "Profile photo removed successfully"
    else
      message = "No photo to remove"
    end

    respond_to do |format|
      format.html { redirect_to account_path, notice: message }
      format.turbo_stream { redirect_to account_path, notice: message }
    end
  end

  # Email change (B8, S6): Auth::EmailChangeService sends the confirm link to
  # the NEW address and a notice to the current one; only a digest is stored.
  def request_email_change
    result = Auth::EmailChangeService.request(current_user, params[:new_email])
    flash_key = result.success? ? :notice : :alert

    respond_to do |format|
      format.html { redirect_to account_path, flash_key => result.message }
      format.turbo_stream { redirect_to account_path, flash_key => result.message }
    end
  end

  def verify_email_change
    result = Auth::EmailChangeService.confirm(params[:token])

    unless result.success?
      flash[:alert] = result.message
      redirect_to account_path
      return
    end

    # Sign out all sessions for security
    sign_out(result.user)

    flash[:notice] = result.message
    redirect_to auth_path
  end

  def change_password
    # For users with existing passwords, verify current password
    if current_user.has_password?
      unless current_user.valid_password?(params[:current_password])
        respond_to do |format|
          format.html { redirect_to account_path, alert: "Current password is incorrect" }
          format.turbo_stream { redirect_to account_path, alert: "Current password is incorrect" }
        end
        return
      end
    end

    # Validate new password
    if params[:new_password] != params[:confirm_password]
      respond_to do |format|
        format.html { redirect_to account_path, alert: "New passwords do not match" }
        format.turbo_stream { redirect_to account_path, alert: "New passwords do not match" }
      end
      return
    end

    if params[:new_password].length < 8
      respond_to do |format|
        format.html { redirect_to account_path, alert: "New password must be at least 8 characters long" }
        format.turbo_stream { redirect_to account_path, alert: "New password must be at least 8 characters long" }
      end
      return
    end

    # Check if this is adding a password for the first time
    was_passwordless = current_user.passwordless_only?

    # Update password and mark as manually set
    current_user.update!(
      password: params[:new_password],
      password_set_manually: true
    )

    # Keep the user signed in after password change
    bypass_sign_in(current_user)

    # Different success messages based on whether password was added or changed
    message = if was_passwordless
      "Password added successfully! You can now sign in with either magic links or your password."
    else
      "Password updated successfully"
    end

    respond_to do |format|
      format.html { redirect_to account_path, notice: message }
      format.turbo_stream { redirect_to account_path, notice: message }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to account_path, alert: "Failed to update password. Please try again." }
      format.turbo_stream { redirect_to account_path, alert: "Failed to update password. Please try again." }
    end
  end

  private

  # Verifies with Stripe (the ?subscription=success param alone is
  # forgeable) that a subscription was just created, then grants the
  # welcome credit. Only subscriptions under an hour old count, anything
  # older is not "just checked out" and belongs to the webhook path.
  # Stripe hiccups here are fine: the webhook fallback still grants.
  def ensure_welcome_credit_after_checkout
    return if current_user.stripe_customer_id.blank?

    subscription = Stripe::Subscription.list(customer: current_user.stripe_customer_id, status: "active", limit: 1).data.first
    return unless subscription && Time.at(subscription.created) > 1.hour.ago

    record_plan_from_checkout_subscription(subscription)

    if CreditTransaction.grant_welcome_credit(current_user)
      log_activity(:credits_added, current_user, { amount: 1, reason: "new_subscription" })
    end
  rescue Stripe::StripeError => e
    Rails.logger.error "Welcome-credit sync check failed for user #{current_user.id}: #{e.message}"
  end

  # The redirect can beat both webhooks, so the local subscription_plan may
  # still be unset. Read the plan from the subscription's price id (same
  # mapping as the webhook) so a society-only plan is never given a deck credit.
  def record_plan_from_checkout_subscription(subscription)
    items = subscription.respond_to?(:items) ? subscription.items : nil
    price_id = items&.data&.first&.price&.id
    plan = User.plan_for_price_id(price_id)

    if plan == "unknown"
      Rails.logger.info "Checkout return for user #{current_user.id}: plan not determinable from subscription price; leaving plan #{current_user.subscription_plan.inspect}"
      return
    end

    if current_user.subscription_plan != plan
      current_user.update!(subscription_plan: plan)
    end
    Rails.logger.info "Checkout return for user #{current_user.id}: plan #{plan.inspect} from price id#{plan == 'founding_society' ? ' (society-only, no deck credit)' : ''}"
  end

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :bio, :event_emails)
  end

  # Membership products/prices live in SubscriptionProducts (shared with the
  # homepage, subscriptions, and admin revenue) so pricing is never hardcoded
  # in two places.
  def fetch_stripe_products
    SubscriptionProducts.all
  end
end
