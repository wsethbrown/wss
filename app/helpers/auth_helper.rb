module AuthHelper
  # True when "Sign in with Apple" is fully configured (see config/initializers/devise.rb).
  # Used to conditionally render the Apple button so we never link to an unconfigured provider.
  def apple_sign_in_available?
    User.omniauth_providers.include?(:apple) && Devise.omniauth_configs.key?(:apple)
  end

  # True when Google OAuth is usable: real credentials are configured, or we're in
  # test mode where OmniAuth intercepts the flow before Google is ever contacted.
  # In development the button hides until GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET
  # are set in .env, instead of sending users to a guaranteed Google error page.
  def google_sign_in_available?
    return true if Rails.env.test?

    ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present? &&
      Devise.omniauth_configs.key?(:google_oauth2)
  end
end
