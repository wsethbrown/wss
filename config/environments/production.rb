require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Uploads live in Cloudflare R2 (see config/storage.yml) so the server is
  # disposable — review photos and deck files survive rebuilds and resizes.
  config.active_storage.service = :cloudflare_r2

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # One structured line per request (method, path, status, duration, db time,
  # who) instead of Rails' multi-line chatter — greppable from `kamal app logs`
  # and parseable by any log service we ship to later.
  config.lograge.enabled = true
  config.lograge.custom_payload do |controller|
    {
      request_id: controller.request.request_id,
      user_id: controller.respond_to?(:current_user, true) ? controller.send(:current_user)&.id : nil,
      ip: controller.request.remote_ip
    }
  end

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "whiskeysharesociety.com", protocol: "https" }

  # Transactional email (Devise resets, verifications) via any SMTP provider —
  # wired from env so switching providers is a secrets change, not a deploy.
  # With SMTP_ADDRESS unset, deliveries are silently dropped (test adapter);
  # the launch checklist treats picking a provider as a pre-launch item.
  if ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV["SMTP_ADDRESS"],
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: :plain,
      enable_starttls_auto: true
    }
  else
    config.action_mailer.delivery_method = :test
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Host-header protection: only our domains are served.
  config.hosts = [
    "whiskeysharesociety.com",
    "www.whiskeysharesociety.com"
  ]
  # kamal-proxy healthchecks hit /up without a public Host header.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
