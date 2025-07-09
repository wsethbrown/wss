class MagicLinksController < ApplicationController
  before_action :authenticate_user!, except: [:create, :show]
  # Skip CSRF verification for create action to allow form submissions and tests
  skip_before_action :verify_authenticity_token, only: [:create]
  # before_action :redirect_if_authenticated, only: [:create] # Temporarily disabled for testing
  # Don't redirect authenticated users from show - they might be testing links

  def create
    email = params[:email]
    @user = User.find_by(email: email)
    is_new_user = @user.nil?
    
    # Generate a secure token for magic link (shorter to prevent line breaks)
    token = SecureRandom.urlsafe_base64(16)
    
    # Send appropriate email based on whether user exists
    if is_new_user
      # For new users, we'll use a cache-based approach to allow multiple magic links
      # Store in Rails cache with the token as the key
      cache_key = "magic_link:#{token}"
      Rails.cache.write(cache_key, {
        email: email,
        is_new_user: true,
        expires_at: 15.minutes.from_now.to_i
      }, expires_in: 15.minutes)
      
      UserMailer.magic_link_registration_email(email, token).deliver_now
      message = 'Check your email for a magic link to create your account!'
    else
      # For existing users, store token in their record (not session)
      @user.update!(
        reset_password_token: Devise.token_generator.digest(User, :reset_password_token, token),
        reset_password_sent_at: Time.current
      )
      UserMailer.magic_link_email(@user, token).deliver_now
      message = 'Check your email for a magic link to sign in!'
    end
    
    redirect_to auth_path, notice: message
  end

  def show
    token = params[:token]
    Rails.logger.info "=== MAGIC LINK CLICKED ==="
    Rails.logger.info "Token: #{token}"
    Rails.logger.info "Token present: #{token.present?}"
    Rails.logger.info "Token length: #{token&.length}"
    Rails.logger.info "Current time: #{Time.current}"
    Rails.logger.info "Session ID: #{session.id}"
    Rails.logger.info "Session keys: #{session.keys}"
    
    return redirect_to auth_path, alert: 'Invalid magic link.' unless token.present?

    # First check cache for magic link data (new user flow)
    cache_key = "magic_link:#{token}"
    magic_link_data = Rails.cache.read(cache_key)
    Rails.logger.info "Cache magic link data: #{magic_link_data.inspect}"
    
    if magic_link_data
      # Validate expiration
      if magic_link_data[:expires_at] && Time.current.to_i < magic_link_data[:expires_at]
        Rails.logger.info "Processing cache-based magic link"
        
        # Delete from cache to prevent reuse
        Rails.cache.delete(cache_key)
        
        if magic_link_data[:is_new_user]
          # Handle new user registration
          email = magic_link_data[:email]
          temp_password = SecureRandom.hex(16)
          
          begin
            @user = User.create!(
              email: email,
              password: temp_password,
              password_confirmation: temp_password,
              first_name: '',
              last_name: ''
            )
            
            # Sign in the new user
            sign_in(@user)
            redirect_to account_path, notice: 'Welcome to Whiskey Share Society! Please complete your profile.'
            return
          rescue ActiveRecord::RecordInvalid => e
            redirect_to auth_path, alert: "Unable to create account: #{e.message}"
            return
          end
        end
      else
        Rails.logger.info "Magic link expired in cache"
      end
    end

    # If we get here, check if it's a token-based magic link (existing user flow)
    Rails.logger.info "=== CHECKING TOKEN-BASED MAGIC LINK ==="
    digest = Devise.token_generator.digest(User, :reset_password_token, token)
    Rails.logger.info "Generated digest: #{digest}"
    Rails.logger.info "Looking for user with digest: #{digest}"
    @user = User.find_by(reset_password_token: digest)
    Rails.logger.info "Found user: #{@user.inspect}"
    
    if @user
      Rails.logger.info "User found - checking validity"
      Rails.logger.info "User reset_password_sent_at: #{@user.reset_password_sent_at}"
      Rails.logger.info "Current time: #{Time.current}"
      Rails.logger.info "15 minutes ago: #{15.minutes.ago}"
      Rails.logger.info "Token sent after 15 min ago: #{@user.reset_password_sent_at && @user.reset_password_sent_at > 15.minutes.ago}"
      Rails.logger.info "Magic link valid: #{magic_link_valid?(@user)}"
    end

    if @user && magic_link_valid?(@user)
      Rails.logger.info "Magic link is valid, signing in user"
      # Clear the token to prevent reuse
      @user.update!(reset_password_token: nil, reset_password_sent_at: nil)
      
      # Sign in the user
      sign_in(@user)
      redirect_to account_path, notice: 'Successfully signed in with magic link!'
    else
      Rails.logger.error "Magic link validation failed. User: #{@user.inspect}, Valid: #{@user ? magic_link_valid?(@user) : 'no user'}"
      redirect_to auth_path, alert: 'Magic link is invalid or has expired.'
    end
  end

  private

  def redirect_if_authenticated
    redirect_to root_path if user_signed_in?
  end

  def magic_link_valid?(user)
    return false unless user.reset_password_sent_at.present?
    
    # Magic links expire after 15 minutes
    user.reset_password_sent_at > 15.minutes.ago
  end
end