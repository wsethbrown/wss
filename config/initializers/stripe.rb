Stripe.api_key = ENV.fetch('STRIPE_SECRET_KEY', 'sk_test_...')

# Set API version
Stripe.api_version = '2024-06-20'

Rails.configuration.stripe = {
  publishable_key: ENV.fetch('STRIPE_PUBLISHABLE_KEY', 'pk_test_...'),
  secret_key: ENV.fetch('STRIPE_SECRET_KEY', 'sk_test_...'),
  webhook_secret: ENV.fetch('STRIPE_WEBHOOK_SECRET', 'whsec_...')
}