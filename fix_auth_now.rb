#!/usr/bin/env ruby
# Quick fix script for WSS authentication issues

puts "🔧 Fixing WSS Authentication..."

# 1. Backup current broken config
system("cp config/initializers/omniauth.rb config/initializers/omniauth.rb.broken")

# 2. Create proper OmniAuth config
omniauth_config = <<~RUBY
# Configure OmniAuth to work properly with Rails CSRF protection
Rails.application.config.middleware.use OmniAuth::Builder do
  # Providers are configured in Devise, not here
end

# Enable proper CSRF protection (DO NOT DISABLE!)
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true

# Handle failures properly
OmniAuth.config.on_failure = Proc.new { |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
}

# Use Rails logger
OmniAuth.config.logger = Rails.logger

# IMPORTANT: Do NOT disable CSRF or set state to nil!
RUBY

File.write('config/initializers/omniauth.rb', omniauth_config)
puts "✅ Fixed OmniAuth configuration"

# 3. Add CSRF protection gem to Gemfile if not present
gemfile = File.read('Gemfile')
unless gemfile.include?('omniauth-rails_csrf_protection')
  puts "📦 Adding omniauth-rails_csrf_protection gem..."
  system("bundle add omniauth-rails_csrf_protection")
end

puts "\n🎯 Next steps:"
puts "1. Remove 'skip_csrf: true' from Devise OAuth configs in config/initializers/devise.rb"
puts "2. Remove 'skip_before_action :verify_authenticity_token' from OmniauthCallbacksController"
puts "3. Restart your Rails server"
puts "\n✨ Your authentication should work again!"