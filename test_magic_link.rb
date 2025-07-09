#!/usr/bin/env ruby

# Generate a test magic link for manual testing
require 'securerandom'

# Generate a test token (same format as the real magic link controller)
test_token = SecureRandom.urlsafe_base64(32)

# Create the magic link URL
magic_link_url = "https://dev.whiskeysharesociety.com:3000/magic_links/#{test_token}"

puts "="*80
puts "🔗 TEST MAGIC LINK"
puts "="*80
puts
puts "Email Content Preview:"
puts "-" * 40
puts "Subject: Your Magic Link for Whiskey Share Society"
puts "To: wsethbrown@gmail.com"
puts
puts "Hello!"
puts
puts "You requested a magic link to sign in to your Whiskey Share Society account."
puts "Click the button below to securely sign in:"
puts
puts "🔗 Sign In with Magic Link: #{magic_link_url}"
puts
puts "This link will automatically sign you in - no password required!"
puts
puts "SECURITY INFORMATION:"
puts "• This magic link expires in 15 minutes"
puts "• It can only be used once"
puts "• If you didn't request this link, please ignore this email"
puts
puts "-" * 40
puts
puts "To test the magic link flow:"
puts "1. Copy this URL: #{magic_link_url}"
puts "2. Open it in your browser"
puts "3. You should see an error (expected - token not in database)"
puts
puts "To test with a REAL magic link:"
puts "1. Submit the magic link form with a real email"
puts "2. Check /Users/sethbrown/Documents/wss/tmp/mail/ for the email file"
puts "3. Look for the magic_links URL in the email"
puts "4. Copy that URL and open it in your browser"
puts
puts "="*80