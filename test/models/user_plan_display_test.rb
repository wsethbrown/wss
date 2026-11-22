require "test_helper"

# The admin user page's plan label is derived from SubscriptionProducts, the one
# source of truth for plan prices, so it can never drift from what members pay.
# It once read "Monthly ($19.99/month)" and "Yearly ($119.88/year)", matching
# nothing live.
class UserPlanDisplayTest < ActiveSupport::TestCase
  setup { @user = users(:john) }

  def label_for(plan)
    @user.subscription_plan = plan
    @user.subscription_plan_display
  end

  test "every plan a member can be on shows the price they are billed" do
    assert_equal "Monthly ($15.99/month)", label_for("monthly")
    assert_equal "Quarterly ($38.97/quarter)", label_for("quarterly")
    assert_equal "Yearly ($131.88/year)", label_for("yearly")
    assert_equal "Founding Monthly ($10.99/month)", label_for("founding_monthly")
    assert_equal "Founding Society ($5.00/month)", label_for("founding_society")
  end

  test "every plan the price map knows has a label with a price" do
    User::PLAN_PRICE_ENV.each_key do |plan|
      assert_match(/\(\$\d+\.\d{2}\/(month|quarter|year)\)\z/, label_for(plan), plan)
    end
  end

  test "the label follows the source of truth when a price changes" do
    products = SubscriptionProducts.fallback.map do |p|
      p[:id] == "yearly" ? p.merge(price: 1250, billed_price: 15_000) : p
    end
    SubscriptionProducts.stubs(:all).returns(products)
    assert_equal "Yearly ($150.00/year)", label_for("yearly")
  end

  test "a plan missing from the live products falls back to its name, without a stale price" do
    SubscriptionProducts.stubs(:all).returns(SubscriptionProducts.fallback.reject { |p| p[:id] == "quarterly" })
    assert_equal "Quarterly", label_for("quarterly")
  end

  test "no plan or an unknown plan shows No Plan" do
    assert_equal "No Plan", label_for(nil)
    assert_equal "No Plan", label_for("unknown")
  end
end
