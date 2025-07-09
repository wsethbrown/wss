class AppleDirectController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:callback]
  
  def auth
    # Generate Apple Sign In URL directly
    client_id = ENV['APPLE_CLIENT_ID']
    # Try different redirect URIs to see which one Apple accepts
    redirect_uri = "#{ENV.fetch('RAILS_HOST', 'https://dev.whiskeysharesociety.com:3000')}/users/auth/apple/callback"
    state = SecureRandom.hex(16)
    
    # Store state in session for verification
    session[:apple_state] = state
    
    # Apple Sign In URL
    apple_auth_url = "https://appleid.apple.com/auth/authorize?" + {
      response_type: 'code id_token',
      response_mode: 'form_post',
      client_id: client_id,
      redirect_uri: redirect_uri,
      state: state,
      scope: 'email name',
      nonce: SecureRandom.hex(16)
    }.to_query
    
    Rails.logger.info "=== APPLE DIRECT AUTH ==="
    Rails.logger.info "Redirect URI: #{redirect_uri}"
    Rails.logger.info "Client ID: #{client_id}"
    Rails.logger.info "Auth URL: #{apple_auth_url}"
    
    redirect_to apple_auth_url, allow_other_host: true
  end
  
  def callback
    Rails.logger.info "=== APPLE DIRECT CALLBACK ==="
    Rails.logger.info "Method: #{request.method}"
    Rails.logger.info "All params: #{params.inspect}"
    Rails.logger.info "Code: #{params[:code]}"
    Rails.logger.info "ID Token present: #{params[:id_token].present?}"
    Rails.logger.info "State: #{params[:state]}"
    Rails.logger.info "User: #{params[:user]}"
    
    if params[:code].present?
      # We have an authorization code from Apple!
      handle_apple_signin
    else
      redirect_to auth_path, alert: "No authorization code received from Apple"
    end
  end
  
  private
  
  def handle_apple_signin
    # For testing, just sign in the user
    user = User.find_or_create_by(email: 'wsethbrown@gmail.com') do |u|
      u.first_name = 'Seth'
      u.last_name = 'Brown'
      u.password = SecureRandom.hex(16)
      u.provider = 'apple'
      u.uid = params[:state] || SecureRandom.hex(8)
    end
    
    if user.persisted?
      sign_in(user)
      redirect_to account_path, notice: "Successfully signed in with Apple!"
    else
      redirect_to auth_path, alert: "Unable to sign in: #{user.errors.full_messages.join(', ')}"
    end
  rescue => e
    Rails.logger.error "Apple signin error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    redirect_to auth_path, alert: "Authentication error: #{e.message}"
  end
end