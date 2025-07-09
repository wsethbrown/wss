#!/usr/bin/env ruby

require_relative 'config/environment'

puts "🔍 TESTING TAB FUNCTIONALITY"
puts "=" * 30

# Clean up existing test user first
User.where(email: 'tabtest@example.com').destroy_all

# Create test user
user = User.create!(
  email: 'tabtest@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Tab',
  last_name: 'Test'
)

puts "✅ Created test user: #{user.email}"
puts "🎯 Now test the account page in your browser:"
puts "   1. Sign in with: #{user.email} / password123"
puts "   2. Go to /account"
puts "   3. Open browser console (F12)"
puts "   4. Click on 'Account Details' tab"
puts "   5. Look for console logs starting with 🔧, 🖱️, 🎯"
puts ""
puts "Expected behavior:"
puts "   - Console should show tab initialization logs"
puts "   - Clicking should show 'Tab clicked: account-details'"
puts "   - Content should switch to Account Details section"
puts ""
puts "If you see errors, the JavaScript tab navigation has issues."
puts "If no logs appear, the JavaScript isn't loading."

# Keep user for testing
puts "🔄 User will be available for testing until you run this script again"

# Clean up previous test users
User.where(email: 'tabtest@example.com').where.not(id: user.id).destroy_all

puts "=" * 30