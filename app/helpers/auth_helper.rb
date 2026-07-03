module AuthHelper
  # True when "Sign in with Apple" is fully configured (see config/initializers/devise.rb).
  # Used to conditionally render the Apple button so we never link to an unconfigured provider.
  def apple_sign_in_available?
    User.omniauth_providers.include?(:apple) && Devise.omniauth_configs.key?(:apple)
  end
end
