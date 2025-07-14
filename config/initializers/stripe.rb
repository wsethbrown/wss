Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', 'sk_test_...')

# Set API version
Stripe.api_version = '2024-06-20'

# Configure Stripe to handle SSL verification properly in development
if Rails.env.development?
  # This allows webhooks to work with ngrok/localtunnel SSL certificates
  Stripe.verify_ssl_certs = false
end

Rails.configuration.stripe = {
  publishable_key: ENV.fetch('STRIPE_PUBLISHABLE_KEY', 'pk_test_...'),
  secret_key: ENV.fetch('STRIPE_SECRET_KEY', 'sk_test_...'),
  webhook_secret: ENV.fetch('STRIPE_WEBHOOK_SECRET', 'whsec_...')
}