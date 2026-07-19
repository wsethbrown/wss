require "test_helper"

class StripeProductsTest < ActiveSupport::TestCase
  setup do
    @original_env = ENV.to_h
    # Mock environment variables
    ENV["STRIPE_MONTHLY_PRICE_ID"] = "price_monthly_test"
    ENV["STRIPE_QUARTERLY_PRICE_ID"] = "price_quarterly_test"
    ENV["STRIPE_YEARLY_PRICE_ID"] = "price_yearly_test"
  end

  teardown do
    ENV.clear
    ENV.update(@original_env)
  end

  test "should fetch all three subscription plans" do
    controller = HomeController.new
    products = controller.send(:fetch_stripe_products)

    assert_equal 3, products.length

    product_ids = products.map { |p| p[:id] }
    assert_includes product_ids, "monthly"
    assert_includes product_ids, "quarterly"
    assert_includes product_ids, "yearly"
  end

  test "should return products in correct order: monthly, quarterly, yearly" do
    controller = HomeController.new
    products = controller.send(:fetch_stripe_products)

    assert_equal "monthly", products[0][:id]
    assert_equal "quarterly", products[1][:id]
    assert_equal "yearly", products[2][:id]
  end

  test "should mark yearly as the best value" do
    controller = HomeController.new
    products = controller.send(:fetch_stripe_products)

    monthly = products.find { |p| p[:id] == "monthly" }
    quarterly = products.find { |p| p[:id] == "quarterly" }
    yearly = products.find { |p| p[:id] == "yearly" }

    assert_equal false, monthly[:popular]
    assert_equal false, quarterly[:popular]
    assert_equal true, yearly[:popular]
  end

  test "should include savings for quarterly and yearly plans" do
    controller = HomeController.new
    products = controller.send(:fetch_stripe_products)

    monthly = products.find { |p| p[:id] == "monthly" }
    quarterly = products.find { |p| p[:id] == "quarterly" }
    yearly = products.find { |p| p[:id] == "yearly" }

    assert_nil monthly[:savings]
    assert_not_nil quarterly[:savings]
    assert_not_nil yearly[:savings]
  end

  test "should use correct price IDs from environment" do
    controller = HomeController.new
    products = controller.send(:fetch_stripe_products)

    monthly = products.find { |p| p[:id] == "monthly" }
    quarterly = products.find { |p| p[:id] == "quarterly" }
    yearly = products.find { |p| p[:id] == "yearly" }

    assert_equal "price_monthly_test", monthly[:price_id]
    assert_equal "price_quarterly_test", quarterly[:price_id]
    assert_equal "price_yearly_test", yearly[:price_id]
  end

  test "should return fallback data when Stripe API fails" do
    controller = HomeController.new

    # Mock Stripe API failure
    Stripe::Price.stubs(:retrieve).raises(Stripe::StripeError.new("API Error"))

    products = controller.send(:fetch_stripe_products)

    assert_equal 3, products.length
    assert products.all? { |p| p[:price_id].present? }
    assert products.all? { |p| p[:features].is_a?(Array) }
  end
end
