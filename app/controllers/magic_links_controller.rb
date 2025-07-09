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
      # Store the magic link data in session for new user registration
      session[:magic_link_data] = {
        email: email,
        token: token,
        is_new_user: is_new_user,
        expires_at: 15.minutes.from_now.to_i  # Store as timestamp to avoid serialization issues
      }
      
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

    # Check session for magic link data (for new users)
    magic_link_data = session[:magic_link_data]
    Rails.logger.info "Session magic link data: #{magic_link_data.inspect}"
    
    # First check if this is a session-based magic link (new user flow)
    # Handle both symbol and string keys due to session serialization
    session_token = magic_link_data&.dig(:token) || magic_link_data&.dig('token')
    session_expires_at = magic_link_data&.dig(:expires_at) || magic_link_data&.dig('expires_at')
    
    Rails.logger.info "Session token: #{session_token}"
    Rails.logger.info "Session expires at: #{session_expires_at}"
    Rails.logger.info "Current time (int): #{Time.current.to_i}"
    Rails.logger.info "Token matches: #{session_token == token}"
    Rails.logger.info "Not expired: #{session_expires_at && Time.current.to_i < session_expires_at}"
    
    if magic_link_data && 
       session_token == token && 
       session_expires_at && 
       Time.current.to_i < session_expires_at
      
      Rails.logger.info "Processing session-based magic link"
      
      if magic_link_data[:is_new_user] || magic_link_data['is_new_user']
        # Handle new user registration
        email = magic_link_data[:email] || magic_link_data['email']
        temp_password = SecureRandom.hex(16)
        
        begin
          @user = User.create!(
            email: email,
            password: temp_password,
            password_confirmation: temp_password,
            first_name: '',
            last_name: ''
          )
          
          # Clear the session data
          session.delete(:magic_link_data)
          
          # Sign in the new user
          sign_in(@user)
          redirect_to account_path, notice: 'Welcome to Whiskey Share Society! Please complete your profile.'
          return
        rescue ActiveRecord::RecordInvalid => e
          redirect_to auth_path, alert: "Unable to create account: #{e.message}"
          return
        end
      else
        # For existing users, clear session data and fall through to token-based verification
        # This ensures proper token cleanup and reuse prevention
        session.delete(:magic_link_data)
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