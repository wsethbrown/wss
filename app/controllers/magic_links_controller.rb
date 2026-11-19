class MagicLinksController < ApplicationController
  include ActivityLogger
  include RateLimitedResponses

  IP_LIMIT = 10      # link requests per IP per window
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
    result = Auth::MagicLinkService.deliver(params[:email])

    if result.success?
      redirect_to auth_path, notice: result.message
    else
      redirect_to auth_path, alert: result.message
    end
  end

  def show
    user = Auth::MagicLinkService.consume(params[:token])

    if user
      sign_in(user)
      log_activity(:login, nil, { method: "magic_link" })
      redirect_to account_path, notice: "You're signed in. Welcome back!"
    else
      redirect_to auth_path, alert: "That magic link is invalid or has expired. Please request a new one."
    end
  end
end
