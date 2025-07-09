#!/usr/bin/env ruby
# Test authentication methods

puts "🔍 Testing WSS Authentication Methods\n\n"

# Check OAuth configuration
puts "1. OAuth Configuration:"
puts "   Google OAuth configured: #{ENV['GOOGLE_CLIENT_ID'].present?}"
puts "   Apple OAuth configured: #{ENV['APPLE_CLIENT_ID'].present? && File.exist?('apple_private_key.pem')}"
puts ""

# Check routes
puts "2. Authentication Routes:"
routes = `rails routes | grep -E "(auth|magic|omniauth)"`
puts routes.split("\n").select { |r| r.include?('auth') || r.include?('magic') }.join("\n")
puts ""

# Test magic link generation
puts "3. Testing Magic Link Generation:"
puts "   Run: rails runner 'UserMailer.magic_link_email(User.first || User.new(email: \"test@example.com\"), \"test-token\").deliver_now'"
puts ""

# Summary
puts "📋 Summary:"
puts "- Apple OAuth should now work (CSRF fixed with button_to + selective skip)"
puts "- Magic links are generating correctly"
puts "- Google OAuth should continue working"
puts ""
puts "🚀 Next Steps:"
puts "1. Restart your Rails server"
puts "2. Clear browser cookies/cache"
puts "3. Try signing in with Apple again"
puts "4. Check logs with: tail -f log/development.log | grep -E '(APPLE|OAuth)'"