require "test_helper"

class StripeCheckoutFlowTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @user.update!(stripe_subscription_id: nil)
    sign_in @user
  end

  test "monthly subscription checkout redirects to Stripe" do
    # Mock Stripe customer creation
    mock_customer = mock('customer')
    mock_customer.stubs(:id).returns('cus_test123')
    Stripe::Customer.stubs(:create).returns(mock_customer)
    
    # Mock Stripe checkout session creation
    mock_session = mock('session')
    mock_session.stubs(:url).returns('https://checkout.stripe.com/session123')
    Stripe::Checkout::Session.stubs(:create).returns(mock_session)
    
    post subscriptions_checkout_path, params: { price_id: 'monthly' }
    
    assert_response :redirect
    assert_redirected_to 'https://checkout.stripe.com/session123'
  end

  test "quarterly subscription checkout redirects to Stripe" do
    # Mock Stripe customer creation
    mock_customer = mock('customer')
    mock_customer.stubs(:id).returns('cus_test123')
    Stripe::Customer.stubs(:create).returns(mock_customer)
    
    # Mock Stripe checkout session creation
    mock_session = mock('session')
    mock_session.stubs(:url).returns('https://checkout.stripe.com/session456')
    Stripe::Checkout::Session.stubs(:create).returns(mock_session)
    
    post subscriptions_checkout_path, params: { price_id: 'quarterly' }
    
    assert_response :redirect
    assert_redirected_to 'https://checkout.stripe.com/session456'
  end

  test "yearly subscription checkout redirects to Stripe" do
    # Mock Stripe customer creation
    mock_customer = mock('customer')
    mock_customer.stubs(:id).returns('cus_test123')
    Stripe::Customer.stubs(:create).returns(mock_customer)
    
    # Mock Stripe checkout session creation
    mock_session = mock('session')
    mock_session.stubs(:url).returns('https://checkout.stripe.com/session789')
    Stripe::Checkout::Session.stubs(:create).returns(mock_session)
    
    post subscriptions_checkout_path, params: { price_id: 'yearly' }
    
    assert_response :redirect
    assert_redirected_to 'https://checkout.stripe.com/session789'
  end

  test "invalid price_id returns error" do
    post subscriptions_checkout_path, params: { price_id: 'invalid' }
    
    assert_response :redirect
    assert_redirected_to account_path(anchor: 'subscription')
    assert_equal 'Invalid subscription plan', flash[:alert]
  end

  test "Stripe error handling returns graceful error" do
    # Mock Stripe error
    Stripe::Customer.stubs(:create).raises(Stripe::StripeError.new("API Error"))
    
    post subscriptions_checkout_path, params: { price_id: 'monthly' }
    
    assert_response :redirect
    assert_redirected_to account_path(anchor: 'subscription')
    assert_equal 'Payment processing error. Please try again.', flash[:alert]
  end

  test "checkout session includes correct metadata" do
    # Mock Stripe customer
    mock_customer = mock('customer')
    mock_customer.stubs(:id).returns('cus_test123')
    Stripe::Customer.stubs(:create).returns(mock_customer)
    
    # Mock and capture checkout session creation
    mock_session = mock('session')
    mock_session.stubs(:url).returns('https://checkout.stripe.com/test')
    
    Stripe::Checkout::Session.expects(:create).with(
      has_entry(:metadata, has_entries(
        user_id: @user.id.to_s,
        plan: 'monthly'
      ))
    ).returns(mock_session)
    
    post subscriptions_checkout_path, params: { price_id: 'monthly' }
    
    assert_response :redirect
  end

  test "checkout session includes correct success and cancel URLs" do
    # Mock Stripe customer
    mock_customer = mock('customer')
    mock_customer.stubs(:id).returns('cus_test123')
    Stripe::Customer.stubs(:create).returns(mock_customer)
    
    # Mock and capture checkout session creation
    mock_session = mock('session')
    mock_session.stubs(:url).returns('https://checkout.stripe.com/test')
    
    Stripe::Checkout::Session.expects(:create).with(
      has_entries(
        success_url: account_url + '?subscription=success#subscription',
        cancel_url: account_url + '?subscription=cancelled#subscription'
      )
    ).returns(mock_session)
    
    post subscriptions_checkout_path, params: { price_id: 'monthly' }
    
    assert_response :redirect
  end

  test "checkout creates or retrieves Stripe customer" do
    # Test creating new customer
    mock_customer = mock('customer')
    mock_customer.stubs(:id).returns('cus_new123')
    
    Stripe::Customer.expects(:create).with(
      has_entries(
        email: @user.email,
        name: @user.full_name,
        metadata: has_entry(:user_id, @user.id.to_s)
      )
    ).returns(mock_customer)
    
    mock_session = mock('session')
    mock_session.stubs(:url).returns('https://checkout.stripe.com/test')
    Stripe::Checkout::Session.stubs(:create).returns(mock_session)
    
    post subscriptions_checkout_path, params: { price_id: 'monthly' }
    
    # Check that user's stripe_customer_id was updated
    assert_equal 'cus_new123', @user.reload.stripe_customer_id
  end

  test "checkout uses existing Stripe customer if available" do
    # Set existing customer ID
    @user.update!(stripe_customer_id: 'cus_existing123')
    
    # Mock retrieving existing customer
    mock_customer = mock('customer')
    mock_customer.stubs(:id).returns('cus_existing123')
    Stripe::Customer.expects(:retrieve).with('cus_existing123').returns(mock_customer)
    
    # Should not create new customer
    Stripe::Customer.expects(:create).never
    
    mock_session = mock('session')
    mock_session.stubs(:url).returns('https://checkout.stripe.com/test')
    Stripe::Checkout::Session.stubs(:create).returns(mock_session)
    
    post subscriptions_checkout_path, params: { price_id: 'monthly' }
    
    assert_response :redirect
  end

  test "checkout session uses correct price IDs from environment" do
    # Mock environment variables
    ENV.stubs(:[]).with('STRIPE_MONTHLY_PRICE_ID').returns('price_monthly_real')
    ENV.stubs(:[]).with('STRIPE_QUARTERLY_PRICE_ID').returns('price_quarterly_real')
    ENV.stubs(:[]).with('STRIPE_YEARLY_PRICE_ID').returns('price_yearly_real')
    
    # Mock Stripe customer
    mock_customer = mock('customer')
    mock_customer.stubs(:id).returns('cus_test123')
    Stripe::Customer.stubs(:create).returns(mock_customer)
    
    # Mock and capture checkout session creation for monthly
    mock_session = mock('session')
    mock_session.stubs(:url).returns('https://checkout.stripe.com/test')
    
    Stripe::Checkout::Session.expects(:create).with(
      has_entry(:line_items, [{
        price: 'price_monthly_real',
        quantity: 1
      }])
    ).returns(mock_session)
    
    post subscriptions_checkout_path, params: { price_id: 'monthly' }
    
    assert_response :redirect
  end

  private

  def sign_in(user)
    post '/users/sign_in', params: {
      user: {
        email: user.email,
        password: 'password'
      }
    }
  end
end