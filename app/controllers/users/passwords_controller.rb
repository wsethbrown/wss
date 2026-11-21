# Devise's password reset, with rate limits: requesting a reset emails the
# address a signed-out visitor typed (when it has an account), so cap it per
# IP and per target address like the magic-link request.
class Users::PasswordsController < Devise::PasswordsController
  include RateLimitedResponses

  IP_LIMIT = 20     # reset requests per IP per window (backstop: shared NATs)
  EMAIL_LIMIT = 3   # reset requests per target email per window
  WINDOW = 15.minutes

  rate_limit to: IP_LIMIT, within: WINDOW, only: :create, store: RateLimitStore,
             name: "password-reset-ip", with: -> { rate_limit_response("ip") }
  rate_limit to: EMAIL_LIMIT, within: WINDOW, only: :create, store: RateLimitStore,
             name: "password-reset-email", by: -> { rate_limit_email_key(params.dig(:user, :email)) },
             with: -> { rate_limit_response("email") }
end
