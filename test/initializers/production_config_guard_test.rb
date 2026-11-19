require "test_helper"

# I20: production must fail at boot on missing config instead of limping on
# with silent fallbacks. The check lives in a plain module so it is testable.
class ProductionConfigGuardTest < ActiveSupport::TestCase
  FULL = {
    "STRIPE_MONTHLY_PRICE_ID" => "price_1", "STRIPE_QUARTERLY_PRICE_ID" => "price_2",
    "STRIPE_YEARLY_PRICE_ID" => "price_3",
    "AR_ENCRYPTION_PRIMARY_KEY" => "a", "AR_ENCRYPTION_DETERMINISTIC_KEY" => "b",
    "AR_ENCRYPTION_KEY_DERIVATION_SALT" => "c",
    "R2_ENDPOINT" => "e", "R2_ACCESS_KEY_ID" => "i", "R2_SECRET_ACCESS_KEY" => "s", "R2_BUCKET" => "b"
  }.freeze

  test "a complete environment passes" do
    assert_empty ProductionConfigGuard.missing(FULL)
    assert_nothing_raised { ProductionConfigGuard.check!(FULL) }
  end

  test "a missing price id raises a clear error naming it" do
    error = assert_raises(RuntimeError) { ProductionConfigGuard.check!(FULL.except("STRIPE_YEARLY_PRICE_ID")) }
    assert_match "STRIPE_YEARLY_PRICE_ID", error.message
  end

  test "missing encryption keys and R2 settings are reported" do
    missing = ProductionConfigGuard.missing(FULL.except("AR_ENCRYPTION_PRIMARY_KEY", "R2_BUCKET"))
    assert_equal %w[AR_ENCRYPTION_PRIMARY_KEY R2_BUCKET].sort, missing.sort
  end

  test "blank values count as missing" do
    assert_includes ProductionConfigGuard.missing(FULL.merge("R2_ENDPOINT" => "  ")), "R2_ENDPOINT"
  end

  test "the pre-launch Stripe flag skips only the price ids" do
    env = FULL.except("STRIPE_MONTHLY_PRICE_ID", "R2_BUCKET").merge("ALLOW_MISSING_STRIPE" => "1")
    assert_equal [ "R2_BUCKET" ], ProductionConfigGuard.missing(env)
  end

  test "test and development still boot with nothing set" do
    assert_not Rails.env.production?
    assert_not ProductionConfigGuard.enforce?(env: {}, rails_env: "development")
    assert_not ProductionConfigGuard.enforce?(env: {}, rails_env: "test")
    assert ProductionConfigGuard.enforce?(env: {}, rails_env: "production")
    assert_not ProductionConfigGuard.enforce?(env: { "SECRET_KEY_BASE_DUMMY" => "1" }, rails_env: "production")
  end
end
