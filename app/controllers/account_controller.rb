class AccountController < ApplicationController
  include ActivityLogger
  
  before_action :authenticate_user!

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
        format.html { redirect_to account_path, notice: 'Profile updated successfully' }
        format.turbo_stream { redirect_to account_path, notice: 'Profile updated successfully' }
      end
    else
      respond_to do |format|
        format.html { redirect_to account_path, alert: 'Failed to update profile' }
        format.turbo_stream { redirect_to account_path, alert: 'Failed to update profile' }
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
      message = 'Profile photo updated successfully'
    else
      message = 'No photo selected'
    end
    
    respond_to do |format|
      format.html { redirect_to account_path, notice: message }
      format.turbo_stream { redirect_to account_path, notice: message }
    end
  end

  def remove_avatar
    if current_user.profile_image.attached?
      current_user.profile_image.purge
      message = 'Profile photo removed successfully'
    else
      message = 'No photo to remove'
    end
    
    respond_to do |format|
      format.html { redirect_to account_path, notice: message }
      format.turbo_stream { redirect_to account_path, notice: message }
    end
  end

  def request_email_change
    new_email = params[:new_email]

    # Validate new email
    if new_email.blank?
      respond_to do |format|
        format.html { redirect_to account_path, alert: "Please enter a new email address." }
        format.turbo_stream { redirect_to account_path, alert: "Please enter a new email address." }
      end
      return
    end

    if new_email == current_user.email
      respond_to do |format|
        format.html { redirect_to account_path, alert: "The new email address must be different from your current email." }
        format.turbo_stream { redirect_to account_path, alert: "The new email address must be different from your current email." }
      end
      return
    end

    # Check if email is already taken
    if User.where(email: new_email).exists?
      respond_to do |format|
        format.html { redirect_to account_path, alert: "This email address is already in use." }
        format.turbo_stream { redirect_to account_path, alert: "This email address is already in use." }
      end
      return
    end

    # Generate verification token
    token = SecureRandom.urlsafe_base64(32)

    # Store the email change request
    current_user.update!(
      unconfirmed_email: new_email,
      email_change_token: token,
      email_change_token_expires_at: 1.hour.from_now
    )

    # Send verification email
    UserMailer.email_change_verification(current_user, new_email, token).deliver_now

    message = "A verification link has been sent to your current email address (#{current_user.email}). Please check your inbox and click the link to confirm the email change."
    
    respond_to do |format|
      format.html { redirect_to account_path, notice: message }
      format.turbo_stream { redirect_to account_path, notice: message }
    end
  end

  def verify_email_change
    token = params[:token]

    user = User.find_by(email_change_token: token)

    if user.nil?
      flash[:alert] = "Invalid verification link."
      redirect_to account_path
      return
    end

    if user.email_change_token_expires_at < Time.current
      flash[:alert] = "Verification link has expired. Please request a new email change."
      user.update!(unconfirmed_email: nil, email_change_token: nil, email_change_token_expires_at: nil)
      redirect_to account_path
      return
    end

    # Update the email
    old_email = user.email
    user.update!(
      email: user.unconfirmed_email,
      unconfirmed_email: nil,
      email_change_token: nil,
      email_change_token_expires_at: nil
    )

    # Sign out all sessions for security
    sign_out(user)

    flash[:notice] = "Your email has been successfully changed from #{old_email} to #{user.email}. Please sign in again with your new email address."
    redirect_to auth_path
  end

  def change_password
    # For users with existing passwords, verify current password
    if current_user.has_password?
      unless current_user.valid_password?(params[:current_password])
        respond_to do |format|
          format.html { redirect_to account_path, alert: 'Current password is incorrect' }
          format.turbo_stream { redirect_to account_path, alert: 'Current password is incorrect' }
        end
        return
      end
    end

    # Validate new password
    if params[:new_password] != params[:confirm_password]
      respond_to do |format|
        format.html { redirect_to account_path, alert: 'New passwords do not match' }
        format.turbo_stream { redirect_to account_path, alert: 'New passwords do not match' }
      end
      return
    end

    if params[:new_password].length < 8
      respond_to do |format|
        format.html { redirect_to account_path, alert: 'New password must be at least 8 characters long' }
        format.turbo_stream { redirect_to account_path, alert: 'New password must be at least 8 characters long' }
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
      'Password added successfully! You can now sign in with either magic links or your password.'
    else
      'Password updated successfully'
    end
    
    respond_to do |format|
      format.html { redirect_to account_path, notice: message }
      format.turbo_stream { redirect_to account_path, notice: message }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to account_path, alert: 'Failed to update password. Please try again.' }
      format.turbo_stream { redirect_to account_path, alert: 'Failed to update password. Please try again.' }
    end
  end

  def setup_2fa
    current_user.generate_otp_secret
    current_user.save!

    render json: {
      qr_code: current_user.otp_qr_code,
      secret_key: current_user.otp_secret_key
    }
  end

  def enable_2fa
    code = params[:code]

    unless current_user.otp_secret_key.present?
      render json: { error: "Please set up 2FA first" }, status: :unprocessable_entity
      return
    end

    totp = ROTP::TOTP.new(current_user.otp_secret_key)
    if totp.verify(code, drift_ahead: 30, drift_behind: 30)
      current_user.otp_enabled = true
      backup_codes = current_user.generate_backup_codes
      current_user.save!

      render json: {
        success: true,
        backup_codes: backup_codes,
        message: "2FA enabled successfully!"
      }
    else
      render json: { error: "Invalid verification code" }, status: :unprocessable_entity
    end
  end

  def disable_2fa
    password = params[:password]

    unless current_user.valid_password?(password)
      render json: { error: "Invalid password" }, status: :unprocessable_entity
      return
    end

    current_user.update!(
      otp_enabled: false,
      otp_secret_key: nil,
      backup_codes: nil
    )

    render json: {
      success: true,
      message: "2FA disabled successfully!"
    }
  end

  def regenerate_backup_codes
    unless current_user.two_factor_enabled?
      render json: { error: "2FA is not enabled" }, status: :unprocessable_entity
      return
    end

    password = params[:password]
    unless current_user.valid_password?(password)
      render json: { error: "Invalid password" }, status: :unprocessable_entity
      return
    end

    backup_codes = current_user.generate_backup_codes
    current_user.save!

    render json: {
      success: true,
      backup_codes: backup_codes,
      message: "Backup codes regenerated successfully!"
    }
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

    if CreditTransaction.grant_welcome_credit(current_user)
      log_activity(:credits_added, current_user, { amount: 1, reason: "new_subscription" })
    end
  rescue Stripe::StripeError => e
    Rails.logger.error "Welcome-credit sync check failed for user #{current_user.id}: #{e.message}"
  end

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :bio, :whiskey_shelf)
  end

  # Membership products/prices live in SubscriptionProducts (shared with the
  # homepage, subscriptions, and admin revenue) so pricing is never hardcoded
  # in two places.
  def fetch_stripe_products
    SubscriptionProducts.all
  end
end
