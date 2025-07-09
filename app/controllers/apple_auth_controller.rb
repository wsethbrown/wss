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
    
    # For now, just sign in the user to test the flow
    user = User.find_by(email: 'wsethbrown@gmail.com')
    
    if user
      user.update(provider: 'apple', uid: params[:state] || SecureRandom.hex(8)) if user.provider.blank?
      sign_in(user)
      redirect_to account_path, notice: "Successfully signed in with Apple!"
    else
      # Create a new user
      user = User.create!(
        email: 'wsethbrown@gmail.com',
        first_name: 'Seth',
        last_name: 'Brown',
        password: SecureRandom.hex(16),
        provider: 'apple',
        uid: params[:state] || SecureRandom.hex(16)
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
end