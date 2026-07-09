source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  
  # Load environment variables from .env file
  gem "dotenv-rails"
  
  # JWT token decoding for Apple OAuth
  gem "jwt"
  
  # System testing with Capybara
  gem "capybara"
  gem "selenium-webdriver"
end

group :test do
  # assert_select / assigns() / assert_template in controller & integration tests
  gem "rails-controller-testing"
  # `.stubs`/`.expects` mocking used across the Stripe and subscription tests
  gem "mocha"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  gem 'foreman'
  gem 'claude-on-rails'
end

gem "hotwire-rails", "~> 0.1.3"

gem "devise", "~> 4.9"

gem "pundit", "~> 2.5"

gem "tailwindcss-rails", "~> 4.3"

gem "kaminari", "~> 1.2"

# OAuth providers
gem "omniauth-google-oauth2", "~> 1.1"
gem "omniauth-apple", "~> 1.0"
gem "omniauth-rails_csrf_protection", "~> 1.0"

# 2FA support
gem "rotp", "~> 6.3"
gem "rqrcode", "~> 2.2"

# Stripe payment processing
gem "stripe", "~> 10.0"

# Markdown rendering for narrative deck content
gem "redcarpet", "~> 3.6"

# Reading .pptx files for deck import (a .pptx is a zip of XML)
gem "rubyzip", "~> 2.3", require: "zip"

gem "lograge", "~> 0.15.0"
gem "sentry-ruby", "~> 6.6"
gem "sentry-rails", "~> 6.6"

gem "aws-sdk-s3", "~> 1.226", require: false
