# WSS Authentication Fix Guide

## Problem Summary

The authentication system is broken due to:
1. CSRF protection being completely disabled in OmniAuth
2. Duplicate OAuth configurations causing conflicts
3. Improper security handling in controllers

## Immediate Fixes Required

### 1. Fix OmniAuth Configuration

Replace `/config/initializers/omniauth.rb` with:

```ruby
# Configure OmniAuth to work properly with Rails CSRF protection
Rails.application.config.middleware.use OmniAuth::Builder do
  # Only configure providers here if NOT using Devise
  # Since we're using Devise, this file should only contain general OmniAuth settings
end

# Enable proper CSRF protection
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true

# Handle failures properly
OmniAuth.config.on_failure = Proc.new { |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
}

# Use Rails logger
OmniAuth.config.logger = Rails.logger
```

### 2. Fix Devise Configuration

Update `/config/initializers/devise.rb` OAuth section:

```ruby
# Remove skip_csrf: true from OAuth configurations
config.omniauth :google_oauth2, 
  ENV['GOOGLE_CLIENT_ID'], 
  ENV['GOOGLE_CLIENT_SECRET'],
  {
    scope: 'email,profile',
    prompt: 'select_account',
    name: 'google_oauth2'
  }
  
# Apple OAuth configuration
if ENV['APPLE_CLIENT_ID'].present? && File.exist?('apple_private_key.pem')
  config.omniauth :apple,
    ENV['APPLE_CLIENT_ID'],
    '',
    {
      scope: 'email name',
      team_id: ENV['APPLE_TEAM_ID'],
      key_id: ENV['APPLE_KEY_ID'], 
      pem: File.read('apple_private_key.pem'),
      name: 'apple',
      redirect_uri: "#{ENV.fetch('RAILS_HOST', 'https://dev.whiskeysharesociety.com:3000')}/users/auth/apple/callback"
    }
end
```

### 3. Fix Controllers

Update `app/controllers/users/omniauth_callbacks_controller.rb`:

```ruby
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Remove skip_before_action :verify_authenticity_token
  # Remove protect_from_forgery with: :null_session
  
  def google_oauth2
    handle_auth("Google")
  end

  def apple
    handle_auth("Apple")
  end

  def failure
    Rails.logger.error "OAuth failure: #{params[:message]}"
    redirect_to auth_path, alert: "Authentication failed: #{params[:message] || 'Unknown error'}. Please try again."
  end

  private

  def handle_auth(provider)
    auth = request.env["omniauth.auth"]
    
    if auth.nil?
      redirect_to auth_path, alert: "Authentication data not received. Please try again."
      return
    end
    
    @user = User.from_omniauth(auth)

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: provider) if is_navigational_format?
    else
      session["devise.oauth_data"] = auth.except(:extra)
      redirect_to auth_path, alert: @user.errors.full_messages.join("\n")
    end
  rescue => e
    Rails.logger.error "OAuth error: #{e.message}"
    redirect_to auth_path, alert: "Authentication failed. Please try again."
  end
end
```

## Recommended Open Source Solutions

### 1. **Devise Token Auth** (for API authentication)
```ruby
gem 'devise_token_auth'
```
- Handles token-based authentication
- Works well with OAuth providers
- Great for API/mobile apps

### 2. **Devise-Two-Factor**
```ruby
gem 'devise-two-factor'
gem 'rqrcode' # For QR code generation
```
- Adds proper 2FA support
- TOTP/HOTP authentication
- Backup codes

### 3. **OmniAuth Apple** (Updated Strategy)
```ruby
gem 'omniauth-apple'
gem 'omniauth-rails_csrf_protection' # Critical for security
```

### 4. **Passwordless** (Alternative to Magic Links)
```ruby
gem 'passwordless'
```
- Well-maintained magic link implementation
- Handles session management properly
- Better security practices

### 5. **Rodauth** (Complete Auth Replacement)
If Devise becomes too problematic:
```ruby
gem 'rodauth-rails'
```
- More secure by default
- Better OAuth integration
- Built-in magic link support

## Testing the Fixes

After implementing fixes:

1. **Test Apple OAuth**:
   ```bash
   # Clear browser cookies first
   # Navigate to /users/auth/apple
   # Check logs for CSRF errors
   ```

2. **Test Magic Links**:
   ```bash
   rails console
   user = User.first
   UserMailer.magic_link_email(user, SecureRandom.urlsafe_base64(16)).deliver_now
   # Click link in email
   ```

3. **Verify CSRF Protection**:
   ```bash
   # In console
   curl -X POST http://localhost:3000/users/auth/apple/callback
   # Should get CSRF error (good!)
   ```

## Security Best Practices

1. **Never disable CSRF protection globally**
2. **Use proper OAuth state parameter**
3. **Implement rate limiting on auth endpoints**
4. **Log all authentication attempts**
5. **Use secure session configuration**

## Quick Rollback Plan

If issues persist:
1. Restore original omniauth.rb.backup
2. Remove skip_csrf from Devise config
3. Use standard Devise controllers
4. Test with minimal configuration first

## Monitoring

Add to application.rb:
```ruby
# Log all OAuth requests for debugging
config.middleware.insert_before OmniAuth::Builder, Rack::Logger
```

## Next Steps

1. Implement fixes in order
2. Test each auth method individually
3. Monitor logs for errors
4. Consider implementing Passwordless gem for better magic links
5. Add proper error tracking (Sentry/Rollbar)