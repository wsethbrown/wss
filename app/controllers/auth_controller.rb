class AuthController < ApplicationController
  include ActivityLogger
  include RateLimitedResponses

  # Limits are constants so they are easy to find and tune.
  # Per-IP limits are a backstop only (shared NATs, offices, a tasting night on
  # one wifi); the per-email limit is the real guard on any one account.
  SIGN_IN_LIMIT = 50          # password attempts per IP per window
  SIGN_IN_EMAIL_LIMIT = 10    # password attempts per target email per window
  SIGN_IN_WINDOW = 3.minutes
  EMAIL_CHECK_LIMIT = 60      # account-existence lookups per IP per minute
  EMAIL_CHECK_WINDOW = 1.minute

  rate_limit to: SIGN_IN_LIMIT, within: SIGN_IN_WINDOW, only: :sign_in, store: RateLimitStore,
             name: "sign-in-ip", with: -> { rate_limit_response("ip") }
  rate_limit to: SIGN_IN_EMAIL_LIMIT, within: SIGN_IN_WINDOW, only: :sign_in, store: RateLimitStore,
             name: "sign-in-email", by: -> { rate_limit_email_key(params.dig(:user, :email)) },
             with: -> { rate_limit_response("email") }
  rate_limit to: EMAIL_CHECK_LIMIT, within: EMAIL_CHECK_WINDOW, only: :email_check, store: RateLimitStore,
             with: -> { rate_limit_response("ip") }

  def unified
    redirect_to root_path if user_signed_in?
  end

  # The password path asks for the email first (it reuses the magic-link
  # field), then branches: existing account -> password box, new account ->
  # name + password. This endpoint answers "does this email have an account?"
  # for that branch. Membership disclosure is accepted for this product; the
  # magic-link flow is the primary path either way.
  def email_check
    email = params[:email].to_s.strip.downcase
    exists = email.match?(URI::MailTo::EMAIL_REGEXP) && User.exists?(email: email)
    render json: { exists: exists }
  end

  def sign_in
    creds = params.require(:user).permit(:email, :password, :remember_me)
    # Devise normalizes the email (case, whitespace) the same way it does at sign-up.
    user = User.find_for_authentication(email: creds[:email].to_s)

    if user && user.valid_password?(creds[:password])
      warden.set_user(user, scope: :user)
      user.remember_me! if creds[:remember_me] == "1"
      log_activity(:login, nil, { method: "password" })
      Rails.logger.info "Password sign-in for user #{user.id}"
      redirect_to dashboard_path, notice: "Signed in successfully"
    else
      # Security guideline: authentication failures are logged for monitoring.
      # The attempted address is not logged: it is often a typo of someone else's.
      Rails.logger.warn "Failed password sign-in attempt (#{user ? "user #{user.id}" : 'no matching account'}) from #{request.remote_ip}"
      # Re-render the auth page with a 422 so Turbo swaps in the error state
      # instead of following a redirect (which loses the entered email).
      flash.now[:alert] = "Invalid Email or password"
      render :unified, status: :unprocessable_entity
    end
  end

  def logout
    log_activity(:logout) if current_user
    sign_out(current_user) if user_signed_in?
    redirect_to root_path
  end
end
