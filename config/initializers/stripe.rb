# Fail loudly in production if Stripe isn't configured, rather than silently booting
# with placeholder keys that break payments and webhook verification. Two carve-outs:
# - SECRET_KEY_BASE_DUMMY: asset precompile during image builds runs env-less by
#   design; without this skip the image can never be built at all.
# - ALLOW_MISSING_STRIPE=1: the deliberate pre-launch window (site live before
#   Stripe activation completes). Payment attempts raise until real keys land.
#   REMOVE the flag from config/deploy.yml the moment live keys are in secrets.
if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank? && ENV["ALLOW_MISSING_STRIPE"].blank?
  %w[STRIPE_SECRET_KEY STRIPE_PUBLISHABLE_KEY STRIPE_WEBHOOK_SECRET].each do |var|
    raise "Missing required env var #{var}" if ENV[var].blank?
  end
end

Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY", "sk_test_placeholder")
Stripe.api_version = "2024-06-20"

# In development we allow self-signed certs so local webhook tunnels (ngrok/stripe CLI)
# work. Never relax this outside development.
Stripe.verify_ssl_certs = false if Rails.env.development?

Rails.configuration.stripe = {
  publishable_key: ENV.fetch("STRIPE_PUBLISHABLE_KEY", "pk_test_placeholder"),
  secret_key: ENV.fetch("STRIPE_SECRET_KEY", "sk_test_placeholder"),
  webhook_secret: ENV.fetch("STRIPE_WEBHOOK_SECRET", "whsec_placeholder")
}
