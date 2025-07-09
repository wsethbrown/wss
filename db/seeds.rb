# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create default tags
Tag.create_default_tags
puts "Created default tags"

# Create test user for development
if Rails.env.development?
  test_user = User.find_or_create_by!(email: 'test@example.com') do |user|
    user.password = 'password'
    user.password_confirmation = 'password'
    user.first_name = 'Test'
    user.last_name = 'User'
    user.bio = 'A passionate whiskey enthusiast exploring the world of fine spirits.'
  end
  
  # Add some tags to the test user
  test_user.add_tag('Bourbon')
  test_user.add_tag('Scotch')
  test_user.add_tag('Collector')
  test_user.add_tag('Tasting')
  test_user.add_tag('Blogger')
  
  puts "Created test user: test@example.com / password"
end
