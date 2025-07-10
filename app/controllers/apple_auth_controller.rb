class AppleAuthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:callback]
  
  def callback
    Rails.logger.info "=== APPLE AUTH DIRECT CALLBACK ==="
    Rails.logger.info "Method: #{request.method}"
    Rails.logger.info "All params: #{params.inspect}"
    Rails.logger.info "Headers: #{request.headers.select { |k,v| k.start_with?('HTTP_') }.inspect}"
    Rails.logger.info "Body: #{request.body.read}" if request.post?
    request.body.rewind if request.post?
    
    # Apple sends the callback as POST with form data
    if request.post? && (params[:code].present? || params[:id_token].present?)
      handle_apple_response
    elsif params[:message] == 'invalid_credentials'
      # This is coming from OmniAuth failure, not Apple
      redirect_to auth_path, alert: "Apple Sign In failed due to security validation. Please try again."
    else
      redirect_to auth_path, alert: "Apple Sign In failed - no authorization code received"
    end
  end
  
  private
  
  def handle_apple_response
    Rails.logger.info "=== HANDLING APPLE RESPONSE ==="
    Rails.logger.info "Code: #{params[:code]}"
    Rails.logger.info "ID Token present: #{params[:id_token].present?}"
    Rails.logger.info "State: #{params[:state]}"
    Rails.logger.info "User data: #{params[:user]}" if params[:user]
    
    # Parse the Apple ID token to get user email
    apple_email = extract_email_from_apple_response
    
    if apple_email.blank?
      redirect_to auth_path, alert: "Could not retrieve email from Apple. Please try again."
      return
    end
    
    Rails.logger.info "Apple email extracted: #{apple_email}"
    
    # Find or create user with the Apple email
    user = User.find_by(email: apple_email)
    
    if user
      # User exists - update their Apple OAuth info if they don't have a provider yet
      if user.provider.blank?
        user.update(provider: 'apple', uid: params[:state] || SecureRandom.hex(8))
      elsif user.provider != 'apple'
        redirect_to auth_path, alert: "This email is already associated with #{user.provider.humanize} login. Please use #{user.provider.humanize} to sign in."
        return
      end
      
      sign_in(user)
      redirect_to account_path, notice: "Successfully signed in with Apple!"
    else
      # Create a new user with Apple OAuth
      user_data = parse_apple_user_data
      
      user = User.create!(
        email: apple_email,
        first_name: user_data[:first_name] || 'Apple',
        last_name: user_data[:last_name] || 'User',
        password: SecureRandom.hex(16),
        provider: 'apple',
        uid: params[:state] || SecureRandom.hex(16),
        password_set_manually: false
      )
      
      if user.persisted?
        sign_in(user)
        redirect_to account_path, notice: "Welcome to Whiskey Share Society!"
      else
        redirect_to auth_path, alert: "Unable to create account: #{user.errors.full_messages.join(', ')}"
      end
    end
  rescue => e
    Rails.logger.error "Apple auth error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    redirect_to auth_path, alert: "Authentication error: #{e.message}"
  end
  
  def extract_email_from_apple_response
    # First, try to get email from the user parameter (first time sign in)
    if params[:user].present?
      user_data = JSON.parse(params[:user]) rescue {}
      return user_data['email'] if user_data['email'].present?
    end
    
    # If no user param, try to decode the ID token
    if params[:id_token].present?
      begin
        # Decode JWT without verification for development (Apple's ID token)
        decoded_token = JWT.decode(params[:id_token], nil, false)
        payload = decoded_token[0]
        return payload['email'] if payload['email'].present?
      rescue JWT::DecodeError => e
        Rails.logger.error "JWT decode error: #{e.message}"
      end
    end
    
    # Fallback - this shouldn't happen in a real Apple OAuth flow
    Rails.logger.warn "Could not extract email from Apple response"
    nil
  end
  
  def parse_apple_user_data
    if params[:user].present?
      user_data = JSON.parse(params[:user]) rescue {}
      {
        first_name: user_data.dig('name', 'firstName'),
        last_name: user_data.dig('name', 'lastName')
      }
    else
      { first_name: nil, last_name: nil }
    end
  end
end