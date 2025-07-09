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
    
    assert_equal 2, products.length
    assert_equal 'monthly', products[0][:id]
    assert_equal 'annual', products[1][:id]
    assert_equal 'Monthly Membership', products[0][:name]
    assert_equal 'Annual Membership', products[1][:name]
  end

  test "fetch_stripe_products returns default products when no Stripe API key" do
    controller = HomeController.new
    
    # Mock missing API key
    Stripe.stubs(:api_key).returns(nil)
    
    products = controller.send(:fetch_stripe_products)
    
    assert_equal 2, products.length
    assert_equal 'monthly', products[0][:id]
    assert_equal 'annual', products[1][:id]
  end

  test "fetch_stripe_products returns default products when environment variables missing" do
    controller = HomeController.new
    
    # Mock missing environment variables
    ENV.stubs(:[]).with('STRIPE_MONTHLY_PRICE_ID').returns(nil)
    ENV.stubs(:[]).with('STRIPE_ANNUAL_PRICE_ID').returns(nil)
    
    products = controller.send(:fetch_stripe_products)
    
    assert_equal 2, products.length
    assert_equal 'monthly', products[0][:id]
    assert_equal 'annual', products[1][:id]
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

  test "fetch_stripe_products marks annual as popular" do
    controller = HomeController.new
    
    products = controller.send(:fetch_stripe_products)
    
    monthly_product = products.find { |p| p[:id] == 'monthly' }
    annual_product = products.find { |p| p[:id] == 'annual' }
    
    assert_equal false, monthly_product[:popular]
    assert_equal true, annual_product[:popular]
  end

  test "fetch_stripe_products includes savings for annual plan" do
    controller = HomeController.new
    
    products = controller.send(:fetch_stripe_products)
    
    monthly_product = products.find { |p| p[:id] == 'monthly' }
    annual_product = products.find { |p| p[:id] == 'annual' }
    
    assert_nil monthly_product[:savings]
    assert_equal '20%', annual_product[:savings]
  end
end