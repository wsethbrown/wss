class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include Pundit::Authorization
  include ActivityLogger

  # before_action :authenticate_user!
  before_action :set_timezone

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Add CSRF protection logging
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_csrf_error

  def health
    render json: { status: 'ok', timestamp: Time.current }
  end

  private

  def set_timezone
    Time.zone = browser_timezone if browser_timezone.present?
  end

  def browser_timezone
    @browser_timezone ||= begin
      tz = cookies[:browser_timezone]
      return nil if tz.blank?
      ActiveSupport::TimeZone[tz] ? tz : nil
    end
  end
  helper_method :browser_timezone

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
  
  def handle_csrf_error
    # Log the fact of the failure without leaking tokens, session contents, or params.
    Rails.logger.warn "CSRF verification failed for #{self.class.name}##{action_name} (#{request.method} #{request.path})"
    redirect_to auth_path, alert: "Your session expired. Please try again."
  end

  # Redirect to account after sign in
  def after_sign_in_path_for(resource)
    account_path
  end
end
