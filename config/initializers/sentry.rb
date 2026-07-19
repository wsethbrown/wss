# Error alerting: exceptions email you and collect in one dashboard instead of
# dying silently in the request log. Completely inert until SENTRY_DSN is set
# (create a free Sentry project, put its DSN in production env) — so dev, test,
# and CI never phone home.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
    # Never send request bodies/params that could carry personal data.
    config.send_default_pii = false
    config.environment = Rails.env
    # Errors only at launch; enable performance tracing later if wanted.
    config.traces_sample_rate = 0.0
  end
end
