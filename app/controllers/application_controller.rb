class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include Pundit::Authorization
  include ActivityLogger

  # before_action :authenticate_user!
  before_action :set_timezone

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  # Invite-link peek: whoever signs up or in after viewing /invite/:token
  # joins that society on their first signed-in page load.
  before_action :consume_pending_invite

  # Add CSRF protection logging
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_csrf_error

  def health
    render json: { status: "ok", timestamp: Time.current }
  end

  private

  # If a signed-out visitor viewed an invite-link peek, the society's token
  # waits in the session; the first signed-in GET joins them and sends them
  # to their new society. Runs everywhere, exits in one comparison when idle.
  def consume_pending_invite
    return unless request.get? && user_signed_in? && session[:pending_invite_token].present?

    token = session.delete(:pending_invite_token)
    society = Society.find_by(invite_token: token)
    unless society
      # Token was regenerated or the society is gone; the invite dies here.
      Rails.logger.warn "Pending invite for user #{current_user.id} dropped: no society matches the stored token"
      return
    end

    if society.has_member?(current_user)
      return
    end

    society.society_memberships.create!(user: current_user, role: :member, status: :active)
    Rails.logger.info "Pending invite consumed: user #{current_user.id} joined society #{society.id} via invite link"
    log_activity(:society_joined, society)
    notify_society_admins_of_join(society, current_user)
    redirect_to society_path(society), notice: "Welcome to #{society.name}!"
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Pending invite failed for user #{current_user.id}, society #{society&.id}: #{e.message}"
  end

  # Invite-link joins ring the admins' bells (owner rule: routine public
  # join/leave churn stays OFF the bell; it lands on the society Activity
  # page instead).
  def notify_society_admins_of_join(society, joiner)
    admins = [ society.creator ] + society.society_memberships.where(role: "admin", status: "active").includes(:user).map(&:user)
    admins.uniq.each do |admin|
      Notification.notify!(user: admin, actor: joiner, notifiable: society, action: "member_joined")
    end
  end

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

  # Redirect to the dashboard after sign in / sign up.
  def after_sign_in_path_for(resource)
    dashboard_path
  end
end
