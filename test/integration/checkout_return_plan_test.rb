require "test_helper"
require "minitest/mock"
require "ostruct"

# B6b (M10): the checkout return redirect can beat both webhooks. The plan must
# come from the subscription's price id, not the (possibly unset) local column.
class CheckoutReturnPlanTest < ActionDispatch::IntegrationTest
  PRICES = {
    "STRIPE_MONTHLY_PRICE_ID" => "price_test_monthly",
    "STRIPE_FOUNDING_SOCIETY_PRICE_ID" => "price_test_founding_society"
  }.freeze

  setup do
    @user = users(:john)
    @user.update!(stripe_customer_id: "cus_return_plan", subscription_plan: nil)
    @old_env = PRICES.keys.index_with { |k| ENV[k] }
    PRICES.each { |k, v| ENV[k] = v }
    post "/users/sign_in", params: { user: { email: @user.email, password: "password" } }
  end

  teardown do
    @old_env.each { |k, v| ENV[k] = v }
  end

  test "plan_for_price_id maps known ids and never matches blank against unset env" do
    assert_equal "monthly", User.plan_for_price_id("price_test_monthly")
    assert_equal "unknown", User.plan_for_price_id("price_nope")
    assert_equal "unknown", User.plan_for_price_id(nil)
    assert_equal "unknown", User.plan_for_price_id("")
    ENV["STRIPE_YEARLY_PRICE_ID"] = nil
    assert_equal "unknown", User.plan_for_price_id("")
  end

  test "founding society return before any webhook sets the plan and grants no credit" do
    with_subscription("price_test_founding_society") { get account_path(subscription: "success") }

    assert_equal "founding_society", @user.reload.subscription_plan
    assert_equal 0, @user.credits.to_i
    assert_equal 0, CreditTransaction.where(user: @user).count
  end

  test "regular plan gets exactly one welcome credit, none extra when the webhook follows" do
    with_subscription("price_test_monthly") { get account_path(subscription: "success") }

    assert_equal "monthly", @user.reload.subscription_plan
    assert_equal 1, @user.credits.to_i

    assert_no_difference -> { @user.reload.credits.to_i } do
      CreditTransaction.grant_welcome_credit(@user)
    end
    assert_equal @user.credits.to_i, CreditTransaction.where(user: @user).sum(:amount)
  end

  private

  def with_subscription(price_id, &block)
    sub = OpenStruct.new(created: 2.minutes.ago.to_i,
      items: OpenStruct.new(data: [ OpenStruct.new(price: OpenStruct.new(id: price_id)) ]))
    Stripe::Subscription.stub(:list, OpenStruct.new(data: [ sub ]), &block)
  end
end
