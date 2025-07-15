class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include Pundit::Authorization
  include ActivityLogger

  # before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  
  # Add CSRF protection logging
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_csrf_error

  def health
    render json: { status: 'ok', timestamp: Time.current }
  end

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
  
  def handle_csrf_error
    # Apple OAuth callbacks come as POST and need special handling
    if request.path == '/users/auth/apple/callback' && request.post?
      Rails.logger.info "=== APPLE OAUTH CSRF - BYPASSING ==="
      # Don't handle the error, let it bubble up to be handled by the controller
      return
    end
    
    Rails.logger.error "=== CSRF ERROR DETECTED ==="
    Rails.logger.error "Controller: #{self.class.name}"
    Rails.logger.error "Action: #{action_name}"
    Rails.logger.error "Request method: #{request.method}"
    Rails.logger.error "Request path: #{request.path}"
    Rails.logger.error "Request params: #{params.inspect}"
    Rails.logger.error "Session: #{session.inspect}"
    Rails.logger.error "CSRF token from session: #{session[:_csrf_token]}"
    Rails.logger.error "CSRF token from params: #{params[:authenticity_token]}"
    Rails.logger.error "CSRF token from headers: #{request.headers['X-CSRF-Token']}"
    Rails.logger.error "Form authenticity token: #{form_authenticity_token}"
    
    redirect_to auth_path, alert: "Authentication failed: csrf_detected. Please try again."
  end

  # Redirect to account after sign in
  def after_sign_in_path_for(resource)
    account_path
  end
end
