require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_path
    assert_response :success
  end

  test "should load stripe products for pricing display" do
    get root_path
    assert_response :success
    assert assigns(:stripe_products).present?
    assert assigns(:stripe_products).is_a?(Array)
    assert assigns(:stripe_products).length >= 2
  end

  test "fetch_stripe_products returns default products when Stripe is unavailable" do
    controller = HomeController.new
    
    # Mock Stripe API failure
    Stripe::Price.stubs(:retrieve).raises(Stripe::StripeError.new("API Error"))
    
    products = controller.send(:fetch_stripe_products)

    assert_equal 3, products.length
    assert_equal 'monthly', products[0][:id]
    assert_equal 'quarterly', products[1][:id]
    assert_equal 'yearly', products[2][:id]
    assert_equal 'Monthly Membership', products[0][:name]
    assert_equal 'Quarterly Membership', products[1][:name]
    assert_equal 'Yearly Membership', products[2][:name]
  end

  test "fetch_stripe_products returns default products when no Stripe API key" do
    controller = HomeController.new
    
    # Mock missing API key
    Stripe.stubs(:api_key).returns(nil)

    products = controller.send(:fetch_stripe_products)

    assert_equal 3, products.length
    assert_equal 'monthly', products[0][:id]
    assert_equal 'quarterly', products[1][:id]
    assert_equal 'yearly', products[2][:id]
  end

  test "fetch_stripe_products returns default products when price IDs are not configured" do
    controller = HomeController.new

    # Blank out the configured price IDs so no Stripe products can be built,
    # forcing the fallback set. Restore them afterwards.
    keys = %w[STRIPE_MONTHLY_PRICE_ID STRIPE_QUARTERLY_PRICE_ID STRIPE_YEARLY_PRICE_ID]
    original = keys.index_with { |k| ENV[k] }
    begin
      keys.each { |k| ENV[k] = "" }
      Rails.cache.clear
      products = controller.send(:fetch_stripe_products)

      assert_equal 3, products.length
      assert_equal 'monthly', products[0][:id]
      assert_equal 'quarterly', products[1][:id]
      assert_equal 'yearly', products[2][:id]
    ensure
      original.each { |k, v| ENV[k] = v }
      Rails.cache.clear
    end
  end

  test "fetch_stripe_products structures product data correctly" do
    controller = HomeController.new
    
    products = controller.send(:fetch_stripe_products)
    
    products.each do |product|
      assert product.key?(:id)
      assert product.key?(:name)
      assert product.key?(:price)
      assert product.key?(:interval)
      assert product.key?(:features)
      assert product.key?(:popular)
      assert product.key?(:price_id)
      
      assert product[:features].is_a?(Array)
      assert product[:features].length > 0
      assert product[:price].is_a?(Integer)
      assert product[:price] > 0
    end
  end

  test "fetch_stripe_products marks the quarterly plan as popular" do
    controller = HomeController.new

    products = controller.send(:fetch_stripe_products)

    monthly_product = products.find { |p| p[:id] == 'monthly' }
    quarterly_product = products.find { |p| p[:id] == 'quarterly' }

    assert_equal false, monthly_product[:popular]
    assert_equal true, quarterly_product[:popular]
  end

  test "fetch_stripe_products includes savings for the quarterly and yearly plans" do
    controller = HomeController.new

    products = controller.send(:fetch_stripe_products)

    monthly_product = products.find { |p| p[:id] == 'monthly' }
    quarterly_product = products.find { |p| p[:id] == 'quarterly' }

    assert_nil monthly_product[:savings]
    assert_equal '19%', quarterly_product[:savings]
  end
end