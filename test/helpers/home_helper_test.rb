require "test_helper"

class HomeHelperTest < ActionView::TestCase
  include HomeHelper

  def products(monthly: 1599, quarterly: 1299, yearly: 1099)
    [
      { id: "monthly", price: monthly },
      { id: "quarterly", price: quarterly, savings: "19%" },
      { id: "yearly", price: yearly, savings: "31%" }
    ]
  end

  test "savings are computed against the monthly plan's per-month price" do
    list = products
    assert_nil plan_savings_percent(list[0], list)
    assert_equal 19, plan_savings_percent(list[1], list)
    assert_equal 31, plan_savings_percent(list[2], list)
  end

  test "savings follow the live prices, not a stored label" do
    list = products(monthly: 2000, quarterly: 1800, yearly: 1500)
    assert_equal 10, plan_savings_percent(list[1], list)
    assert_equal 25, plan_savings_percent(list[2], list)
  end

  test "no savings without a monthly plan to compare against, or when a plan is not cheaper" do
    without_monthly = products.reject { |p| p[:id] == "monthly" }
    assert_nil plan_savings_percent(without_monthly.first, without_monthly)

    list = products(monthly: 1000, quarterly: 1000, yearly: 1200)
    assert_nil plan_savings_percent(list[1], list)
    assert_nil plan_savings_percent(list[2], list)
  end

  test "billing lines match the membership page's wording" do
    assert_equal "billed monthly", plan_billing_line({ id: "monthly" })
    assert_equal "billed quarterly", plan_billing_line({ id: "quarterly" })
    assert_equal "billed annually", plan_billing_line({ id: "yearly" })
    assert_equal "billed monthly", plan_billing_line({ id: "other" })
  end
end
