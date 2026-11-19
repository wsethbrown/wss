# Fail at boot in production when required configuration is missing, rather than
# limping along on silent fallbacks (placeholder price ids, no encryption keys,
# uploads pointed at a default bucket). The logic lives in a plain module so it
# can be tested without booting production; development and test never enforce.
module ProductionConfigGuard
  PRICE_IDS = %w[STRIPE_MONTHLY_PRICE_ID STRIPE_QUARTERLY_PRICE_ID STRIPE_YEARLY_PRICE_ID].freeze
  ENCRYPTION_KEYS = %w[AR_ENCRYPTION_PRIMARY_KEY AR_ENCRYPTION_DETERMINISTIC_KEY AR_ENCRYPTION_KEY_DERIVATION_SALT].freeze
  R2_SETTINGS = %w[R2_ENDPOINT R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BUCKET].freeze

  module_function

  # Asset precompile during image builds runs env-less on purpose
  # (SECRET_KEY_BASE_DUMMY), so it is never enforced.
  def enforce?(env: ENV, rails_env: Rails.env)
    rails_env.to_s == "production" && env["SECRET_KEY_BASE_DUMMY"].to_s.strip.empty?
  end

  # ALLOW_MISSING_STRIPE is the deliberate pre-launch window (see stripe.rb);
  # it excuses the price ids only.
  def missing(env = ENV)
    required = ENCRYPTION_KEYS + R2_SETTINGS
    required += PRICE_IDS if env["ALLOW_MISSING_STRIPE"].to_s.strip.empty?
    required.select { |name| env[name].to_s.strip.empty? }
  end

  def check!(env = ENV)
    absent = missing(env)
    return if absent.empty?

    raise "Missing required production configuration: #{absent.join(', ')}"
  end
end

ProductionConfigGuard.check! if ProductionConfigGuard.enforce?
