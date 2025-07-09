class AccountController < ApplicationController
  before_action :authenticate_user!

  def index
    # Clear any expired email change requests
    current_user.clear_expired_email_change
    
    @available_tags = Tag.order(:category, :name)
    @user_tags = current_user.tags.order(:category, :name)
  end

  def update_profile
    if current_user.update(profile_params)
      flash[:notice] = "Profile updated successfully!"
    else
      flash[:alert] = "Error updating profile. Please check your information."
    end
    redirect_to account_path
  end

  def update_tags
    current_user.user_tags.destroy_all

    if params[:tag_ids].present?
      params[:tag_ids].each do |tag_id|
        tag = Tag.find(tag_id)
        current_user.user_tags.create(tag: tag)
      end
    end

    flash[:notice] = "Tags updated successfully!"
    redirect_to account_path
  end

  def upload_avatar
    Rails.logger.info "Upload avatar called with params: #{params.inspect}"
    if params[:profile_image].present?
      Rails.logger.info "Profile image param present: #{params[:profile_image].inspect}"
      if current_user.profile_image.attach(params[:profile_image])
        Rails.logger.info "Profile image attached successfully"
        flash[:notice] = "Profile picture updated successfully!"
      else
        Rails.logger.info "Profile image attach failed"
        flash[:alert] = "Failed to upload profile picture. Please try again."
      end
    else
      Rails.logger.info "No profile image param present"
      flash[:alert] = "Please select an image file."
    end
    redirect_to account_path
  end

  def remove_avatar
    if current_user.profile_image.attached?
      current_user.profile_image.purge
      flash[:notice] = "Profile picture removed successfully!"
    else
      flash[:alert] = "No profile picture to remove."
    end
    redirect_to account_path
  end

  def request_email_change
    new_email = params[:new_email]

    # Validate new email
    if new_email.blank?
      flash[:alert] = "Please enter a new email address."
      redirect_to account_path
      return
    end

    if new_email == current_user.email
      flash[:alert] = "The new email address must be different from your current email."
      redirect_to account_path
      return
    end

    # Check if email is already taken
    if User.where(email: new_email).exists?
      flash[:alert] = "This email address is already in use."
      redirect_to account_path
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

    flash[:notice] = "A verification link has been sent to your current email address (#{current_user.email}). Please check your inbox and click the link to confirm the email change."
    redirect_to account_path
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
        redirect_to account_path, alert: 'Current password is incorrect'
        return
      end
    end

    # Validate new password
    if params[:new_password] != params[:confirm_password]
      redirect_to account_path, alert: 'New passwords do not match'
      return
    end

    if params[:new_password].length < 8
      redirect_to account_path, alert: 'New password must be at least 8 characters long'
      return
    end

    # Check if this is adding a password for the first time
    was_passwordless = current_user.passwordless_only?
    
    # Update password and mark as manually set
    current_user.update!(
      password: params[:new_password],
      password_set_manually: true
    )
    
    # Different success messages based on whether password was added or changed
    if was_passwordless
      redirect_to account_path, notice: 'Password added successfully! You can now sign in with either magic links or your password.'
    else
      redirect_to account_path, notice: 'Password updated successfully'
    end
  rescue => e
    redirect_to account_path, alert: 'Failed to update password. Please try again.'
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

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :bio, :whiskey_shelf)
  end
end
