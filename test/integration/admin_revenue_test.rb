require "test_helper"

# Revenue must reflect subscriptions, not only a-la-carte deck sales. In test env
# SubscriptionProducts falls back to fixed monthly-equivalent prices:
# monthly $15.99, quarterly $12.99, yearly $10.99.
class AdminRevenueTest < ActionDispatch::IntegrationTest
  def subscriber(plan:, status: "active", email:)
    User.create!(email: email, password: "password123", first_name: "Sub", last_name: "Scriber",
                 subscription_status: status, subscription_plan: plan)
  end

  test "monthly_recurring sums active subscribers by plan at plan prices" do
    subscriber(plan: "monthly",   email: "m@example.com")
    subscriber(plan: "quarterly", email: "q@example.com")
    subscriber(plan: "monthly", status: "canceled", email: "c@example.com")

    assert_in_delta (15.99 + 12.99), SubscriptionRevenue.monthly_recurring, 0.001
  end

  test "monthly_recurring is zero with no active subscribers" do
    assert_equal 0.0, SubscriptionRevenue.monthly_recurring
  end

  test "the dashboard shows MRR from a subscription even with no deck sales" do
    subscriber(plan: "monthly", email: "solo@example.com")
    sign_in users(:admin)

    get admin_dashboard_path
    assert_response :success
    assert_match(/Monthly recurring revenue/, @response.body)
    assert_match(/15\.99/, @response.body)
  end

  test "the subscriptions page shows recurring revenue for all plan types" do
    subscriber(plan: "yearly", email: "y@example.com")
    sign_in users(:admin)

    get admin_subscriptions_path
    assert_response :success
    # yearly monthly-equivalent is $10.99, not $0 (the old calc ignored yearly)
    assert_match(/10\.99/, @response.body)
  end
end
