require "test_helper"

# I14: a Stripe blip must not be cached for an hour as if it were the full price set.
class SubscriptionProductsTest < ActiveSupport::TestCase
  PRICE_ENV = { "STRIPE_MONTHLY_PRICE_ID" => "price_m", "STRIPE_QUARTERLY_PRICE_ID" => "price_q", "STRIPE_YEARLY_PRICE_ID" => "price_y" }.freeze

  setup do
    @store = ActiveSupport::Cache::MemoryStore.new
    Rails.stubs(:cache).returns(@store)
    @saved = PRICE_ENV.keys.to_h { |k| [ k, ENV[k] ] }
    PRICE_ENV.each { |k, v| ENV[k] = v }
    @saved_key = Stripe.api_key
    Stripe.api_key = "sk_test_x"
  end

  teardown do
    @saved.each { |k, v| ENV[k] = v }
    Stripe.api_key = @saved_key
  end

  def price(id, amount, interval, count = 1)
    product = OpenStruct.new(name: "#{id} plan", metadata: {})
    OpenStruct.new(id: id, unit_amount: amount, product: product,
                   recurring: OpenStruct.new(interval: interval, interval_count: count))
  end

  def stub_prices(failing: [])
    Stripe::Price.stubs(:retrieve).with { |args| failing.include?(args[:id]) }.raises(Stripe::APIConnectionError.new("blip"))
    { "price_m" => price("price_m", 1599, "month"), "price_q" => price("price_q", 3900, "month", 3),
      "price_y" => price("price_y", 13200, "year") }.each do |id, p|
      Stripe::Price.stubs(:retrieve).with { |args| args[:id] == id && !failing.include?(id) }.returns(p)
    end
  end

  test "a complete result is cached" do
    stub_prices
    assert_equal 3, SubscriptionProducts.load_all.size
    assert_not_nil @store.read("stripe_products")
  end

  test "a partial result is returned but not cached" do
    stub_prices(failing: [ "price_q" ])
    result = SubscriptionProducts.load_all
    assert_equal %w[monthly yearly], result.map { |p| p[:id] }
    assert_nil @store.read("stripe_products"), "a blip must not hide a plan for an hour"
  end

  test "an empty result falls back and is not cached" do
    stub_prices(failing: %w[price_m price_q price_y])
    assert_equal SubscriptionProducts.fallback, SubscriptionProducts.load_all
    assert_nil @store.read("stripe_products")
  end
end
