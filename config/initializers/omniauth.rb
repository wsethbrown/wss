# Configure OmniAuth to work properly with Rails CSRF protection
Rails.application.config.middleware.use OmniAuth::Builder do
  # Providers are configured in Devise initializer
end

# Enable proper CSRF protection
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true

# Handle failures properly
OmniAuth.config.on_failure = Proc.new { |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
}

# Use Rails logger
OmniAuth.config.logger = Rails.logger
