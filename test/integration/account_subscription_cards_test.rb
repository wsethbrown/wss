require "test_helper"

class AccountSubscriptionCardsTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in @user
  end

  test "account page displays subscription cards for users without active subscription" do
    @user.update!(stripe_subscription_id: nil)

    get account_path
    assert_response :success

    assert_select "h2", text: "Subscription"
    assert_select "h4", text: "Start your membership"

    # All three plans (cards show the short name, e.g. "Monthly").
    assert_select "#plan-cards h3", text: /Monthly/
    assert_select "#plan-cards h3", text: /Quarterly/
    assert_select "#plan-cards h3", text: /Yearly/
  end

  test "account page shows current plan for users with active subscription" do
    @user.update!(stripe_subscription_id: "sub_test123", subscription_status: "active", subscription_ends_at: 1.month.from_now)

    get account_path
    assert_response :success

    assert_select "h3", text: "Current Plan"
    assert_select "h3", text: "Subscription Management"
    # The chooser is not shown to active subscribers.
    assert_select "h4", text: "Start your membership", count: 0
  end

  test "account subscription cards submit to checkout with a price_id each" do
    @user.update!(stripe_subscription_id: nil)

    get account_path
    assert_response :success

    assert_select "#plan-cards form[action='#{subscriptions_checkout_path}']", count: 3
    assert_select "#plan-cards form[method='post']", count: 3
    assert_select "input[name='price_id'][value='monthly']"
    assert_select "input[name='price_id'][value='quarterly']"
    assert_select "input[name='price_id'][value='yearly']"
  end

  test "account subscription cards display correct pricing" do
    @user.update!(stripe_subscription_id: nil)

    get account_path
    assert_response :success

    assert_select "span", text: "$15.99"  # Monthly
    assert_select "span", text: "$12.99"  # Quarterly
    assert_select "span", text: "$10.99"  # Yearly
  end

  test "account subscription cards highlight a best-value plan" do
    @user.update!(stripe_subscription_id: nil)

    get account_path
    assert_response :success

    assert_select "span", text: /Best Value/
  end

  test "account subscription cards have Get Started buttons" do
    @user.update!(stripe_subscription_id: nil)

    get account_path
    assert_response :success

    assert_select "#plan-cards input[type='submit'][value='Get Started']", count: 3
  end

  test "account chooser shows the shared membership benefits once, not per card" do
    @user.update!(stripe_subscription_id: nil)

    get account_path
    assert_response :success

    # No per-card feature lists; one shared benefits panel with the paid perks.
    assert_select "#plan-cards ul", count: 0
    assert_select "h4", text: "Every membership includes"
    assert_select "li", text: /One deck credit every month/
    assert_select "li", text: /Create and run your own society/
  end

  test "account subscription cards use 3-column grid" do
    @user.update!(stripe_subscription_id: nil)

    get account_path
    assert_response :success

    assert_select "div.grid.grid-cols-1.md\\:grid-cols-3", count: 1
  end

  test "account subscription cards show commitment-based plan descriptions" do
    @user.update!(stripe_subscription_id: nil)

    get account_path
    assert_response :success

    assert_select "p", text: "Pay as you go, cancel anytime"
    assert_select "p", text: "Billed every three months"
    assert_select "p", text: "Billed once a year"
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
