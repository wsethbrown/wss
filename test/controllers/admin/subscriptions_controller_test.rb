require "test_helper"

# B2 / M7, M16: the admin subscriptions page must never write users.credits
# directly, and an admin-created subscription grants its welcome credit
# through the ledger.
class Admin::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "posting user[credits] to the subscriptions update leaves credits and ledger untouched" do
    john = users(:john)
    CreditTransaction.record!(user: john, amount: 2, transaction_type: "admin_adjustment", description: "setup")
    before_balance = john.reload.credits
    before_rows = CreditTransaction.where(user: john).count

    sign_in users(:admin)
    patch admin_subscription_path(john), params: { user: { credits: 99, subscription_plan: "monthly" } }

    john.reload
    assert_equal before_balance, john.credits
    assert_equal before_rows, CreditTransaction.where(user: john).count
    assert_equal CreditTransaction.balance_for(john), john.credits
    assert_equal "monthly", john.subscription_plan
  end

  test "the edit page has no set-balance field" do
    sign_in users(:admin)
    get edit_admin_subscription_path(users(:john))
    assert_response :success
    assert_select "input[name='user[credits]']", 0
  end

  test "an admin-created subscription grants the welcome credit through the ledger" do
    john = users(:john)
    john.update_columns(stripe_customer_id: "cus_admin_test")
    empty = Struct.new(:data).new([])
    Stripe::Subscription.stubs(:list).returns(empty)
    Stripe::Subscription.stubs(:create).returns(
      Struct.new(:id, :status, :current_period_end).new("sub_admin_test", "trialing", nil)
    )

    sign_in users(:admin)
    assert_difference -> { CreditTransaction.where(user: john).count }, 1 do
      post admin_create_subscription_path, params: { user_id: john.id, plan: "monthly" }
    end

    john.reload
    assert_equal 1, CreditTransaction.where(user: john, description: CreditTransaction::WELCOME_DESCRIPTION).count
    assert_equal CreditTransaction.balance_for(john), john.credits
  end
end
