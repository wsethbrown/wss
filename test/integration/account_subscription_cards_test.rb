require "test_helper"

class AccountSubscriptionCardsTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in @user
  end

  test "account page displays subscription cards for users without active subscription" do
    # Ensure user has no active subscription
    @user.update!(stripe_subscription_id: nil)
    
    get account_path
    assert_response :success
    
    # Check that subscription section is visible
    assert_select "h2", text: "Subscription"
    assert_select "h4", text: "Choose Your Plan"
    
    # Check that all three subscription plans are displayed (account cards show
    # the full plan name, e.g. "Monthly Membership").
    assert_select "#plan-cards h3", text: /Monthly/
    assert_select "#plan-cards h3", text: /Quarterly/
    assert_select "#plan-cards h3", text: /Yearly/
  end

  test "account page shows current plan for users with active subscription" do
    # A subscription is "active" only when the status says so — having a Stripe
    # subscription id alone is not enough.
    @user.update!(stripe_subscription_id: "sub_test123", subscription_status: "active", subscription_ends_at: 1.month.from_now)
    
    get account_path
    assert_response :success
    
    # Check that current plan section is visible instead of cards
    assert_select "h3", text: "Current Plan"
    assert_select "p", text: "Premium Membership"
    
    # Subscription cards should not be visible
    assert_select "h4", text: "Choose Your Plan", count: 0
  end

  test "account subscription cards have proper form submission" do
    @user.update!(stripe_subscription_id: nil)
    
    get account_path
    assert_response :success
    
    # Check for forms that submit to checkout (scoped: the account page has
    # several other POST forms — profile, email, password, billing).
    assert_select "form[action='#{subscriptions_checkout_path}']", count: 3
    assert_select "#plan-cards form[method='post']", count: 3
    
    # Check for hidden price_id fields
    assert_select "input[name='price_id'][value='monthly']"
    assert_select "input[name='price_id'][value='quarterly']"
    assert_select "input[name='price_id'][value='yearly']"
  end

  test "account subscription cards display correct pricing" do
    @user.update!(stripe_subscription_id: nil)
    
    get account_path
    assert_response :success
    
    # Check pricing display (fallback prices)
    assert_select "span", text: "$15.99"  # Monthly
    assert_select "span", text: "$12.99"  # Quarterly
    assert_select "span", text: "$10.99"  # Yearly
  end

  test "account subscription cards show quarterly as popular" do
    @user.update!(stripe_subscription_id: nil)
    
    get account_path
    assert_response :success
    
    # Check for "Best Value" badge on quarterly plan
    assert_select "span", text: /Best Value/
  end

  test "account subscription cards have Get Started buttons" do
    @user.update!(stripe_subscription_id: nil)
    
    get account_path
    assert_response :success
    
    # Each plan card submits via its own "Get Started" button.
    assert_select "#plan-cards button[type='submit']", count: 3
    assert_select "#plan-cards button", text: /Get Started/, count: 3
  end

  test "account subscription cards display feature lists" do
    @user.update!(stripe_subscription_id: nil)
    
    get account_path
    assert_response :success
    
    # Check that feature lists are present (scoped to the pricing grid)
    assert_select "#plan-cards ul.space-y-3", count: 3
    assert_select "#plan-cards li.flex.items-center", minimum: 9  # At least 3 features per plan
    
    # Check specific features
    assert_select "li", text: /1 credit per month/
    assert_select "li", text: /Everything in Monthly/
    assert_select "li", text: /Everything in Quarterly/
  end

  test "account subscription cards use 3-column grid" do
    @user.update!(stripe_subscription_id: nil)
    
    get account_path
    assert_response :success
    
    # Check for responsive grid classes
    assert_select "div.grid.grid-cols-1.md\\:grid-cols-3", count: 1
  end

  test "account subscription cards show trust indicators" do
    @user.update!(stripe_subscription_id: nil)
    
    get account_path
    assert_response :success
    
    # Check for trust indicators
    assert_select "span", text: /30-day guarantee/
    assert_select "span", text: /Cancel anytime/
    assert_select "span", text: /Secure checkout/
  end

  test "account subscription cards display presentation credits info" do
    @user.update!(stripe_subscription_id: nil)
    
    get account_path
    assert_response :success
    
    # Check for credits explanation
    assert_select "h4", text: /What are presentation credits?/
    assert_select "p", text: /Each month, you'll receive 1 credit/
  end

  test "account subscription cards show proper plan descriptions" do
    @user.update!(stripe_subscription_id: nil)
    
    get account_path
    assert_response :success
    
    # Check plan descriptions
    assert_select "p", text: "Perfect for regular whiskey enthusiasts"
    assert_select "p", text: "Great value"
    assert_select "p", text: "Save 31%"
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