#!/usr/bin/env ruby

# Add Rails environment
require_relative 'config/environment'

user = User.find_by(email: 'wsethbrown@gmail.com')
if user
  token = SecureRandom.urlsafe_base64(16)
  digest = Devise.token_generator.digest(User, :reset_password_token, token)
  user.update!(reset_password_token: digest, reset_password_sent_at: Time.current)
  
  puts "=" * 60
  puts "🔗 FRESH MAGIC LINK CREATED"
  puts "=" * 60
  puts
  puts "Copy this URL and paste it into your browser:"
  puts "https://dev.whiskeysharesociety.com:3000/magic_links/#{token}"
  puts
  puts "User: #{user.email}"
  puts "Created: #{Time.current.strftime('%H:%M:%S')}"
  puts "Expires: #{(Time.current + 15.minutes).strftime('%H:%M:%S')}"
  puts "Token length: #{token.length} characters"
  puts
  puts "=" * 60
else
  puts "❌ User not found: wsethbrown@gmail.com"
end