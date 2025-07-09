class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Apple OAuth requires special handling
  protect_from_forgery except: [:apple]
  
  def google_oauth2
    handle_auth("Google")
  end

  def apple
    Rails.logger.info "=== APPLE OAUTH CALLBACK ==="
    Rails.logger.info "Request Method: #{request.method}"
    Rails.logger.info "Params: #{params.inspect}"
    Rails.logger.info "OmniAuth Auth: #{request.env['omniauth.auth'].present?}"
    
    # Check if we have Apple OAuth response in session (from middleware)
    if session['apple_oauth_response'].present?
      Rails.logger.info "Found Apple OAuth response in session"
    end
    
    handle_auth("Apple")
  end

  def failure
    Rails.logger.error "=== OAUTH FAILURE ==="
    Rails.logger.error "Message: #{params[:message]}"
    Rails.logger.error "Strategy: #{params[:strategy]}"
    Rails.logger.error "Origin: #{request.env['omniauth.origin']}"
    Rails.logger.error "Full params: #{params.inspect}"
    
    error_message = case params[:message]
    when 'csrf_detected'
      "Security validation failed. Please try again."
    when 'invalid_credentials'
      "Invalid credentials. Please try again."
    else
      params[:message] || 'Authentication failed'
    end
    
    redirect_to auth_path, alert: "Authentication failed: #{error_message}"
  end

  private

  def handle_auth(provider)
    Rails.logger.info "=== HANDLE AUTH FOR #{provider.upcase} ==="
    
    auth = request.env["omniauth.auth"]
    
    if auth.nil?
      Rails.logger.error "No omniauth.auth data received"
      Rails.logger.error "Request env keys: #{request.env.keys.select { |k| k.start_with?('omniauth') }}"
      redirect_to auth_path, alert: "Authentication data not received. Please try again."
      return
    end
    
    Rails.logger.info "Auth info: email=#{auth.info.email}, provider=#{auth.provider}"
    
    @user = User.from_omniauth(auth)

    if @user.persisted?
      Rails.logger.info "User #{@user.email} successfully authenticated via #{provider}"
      sign_in @user, event: :authentication
      redirect_to after_sign_in_path_for(@user), notice: "Successfully signed in with #{provider}!"
    else
      Rails.logger.error "User creation/update failed: #{@user.errors.full_messages}"
      session["devise.oauth_data"] = auth.except(:extra)
      redirect_to auth_path, alert: @user.errors.full_messages.join("\n")
    end
  rescue => e
    Rails.logger.error "OAuth error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    redirect_to auth_path, alert: "Authentication error. Please try again."
  end
  
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || account_path
  end
end