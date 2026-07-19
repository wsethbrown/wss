class MagicLinksController < ApplicationController
  include ActivityLogger

  # Sending and consuming links are public; both are rate-limited by the token expiry.
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
