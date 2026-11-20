class MagicLinksController < ApplicationController
  include ActivityLogger
  include RateLimitedResponses

  # Per-IP is a backstop only (shared NATs, one wifi); per-email is the real guard.
  IP_LIMIT = 50      # link requests per IP per window
  EMAIL_LIMIT = 3    # link requests per target email per window
  WINDOW = 15.minutes

  # Requesting a link sends real email, so cap it per IP and per target address.
  rate_limit to: IP_LIMIT, within: WINDOW, only: :create, store: RateLimitStore,
             name: "magic-link-ip", with: -> { rate_limit_response("ip") }
  rate_limit to: EMAIL_LIMIT, within: WINDOW, only: :create, store: RateLimitStore,
             name: "magic-link-email", by: -> { rate_limit_email_key(params[:email]) },
             with: -> { rate_limit_response("email") }

  # Sending and consuming links are public; consuming is bounded by the token expiry, requesting by the limits below.
  skip_before_action :verify_authenticity_token, only: [ :create ]

  def create
    result = Auth::MagicLinkService.deliver(params[:email], return_to: params[:return_to])

    if result.success?
      redirect_to auth_path, notice: result.message
    else
      redirect_to auth_path, alert: result.message
    end
  end

  def show
    redemption = Auth::MagicLinkService.redeem(params[:token])

    if redemption
      user = redemption.user
      sign_in(user)
      log_activity(:login, nil, { method: "magic_link" })
      # The path stored with the token wins (the link may be opened in another
      # browser); otherwise this browser's stored location, then the dashboard.
      destination = redemption.return_to || after_sign_in_path_for(user)
      stored_location_for(:user) if redemption.return_to # don't leave a stale one behind
      Rails.logger.info "Magic-link sign-in for user #{user.id}; #{redemption.return_to ? 'returning to the page it was requested from' : 'no stored return path on the token'}"
      redirect_to destination, notice: "You're signed in. Welcome back!"
    else
      Rails.logger.warn "Magic-link sign-in refused: invalid or expired token"
      redirect_to auth_path, alert: "That magic link is invalid or has expired. Please request a new one."
    end
  end
end
