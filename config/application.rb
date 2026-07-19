require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "../lib/rack/private_from_search"

module Wss
  class Application < Rails::Application
    # Private paths announce themselves as noindex at the Rack layer, because
    # Cloudflare replaces our robots.txt at the edge and a controller filter is
    # discarded by Warden's failure app (see the middleware).
    #
    # OUTERMOST on purpose (insert_before 0): Warden sits above the app, so a
    # middleware added with `use` never sees the sign-in redirect it generates,
    # which is exactly the response that must carry the header. From the top it
    # stamps whatever comes back, including 404s and static files.
    config.middleware.insert_before 0, Rack::PrivateFromSearch

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Ghost-edit corrections: how many DISTINCT users proposing the identical
    # field+value auto-applies it. 3 while the community is small — the
    # eventual-scale intent is much higher, tune via ENV/environment config
    # later, never hardcode a "final" number here.
    config.x.bottle_edits.auto_apply_threshold = 3
  end
end
