require "test_helper"

class CreditTransactionTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @user.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
    @presentation = Presentation.create!(
      author: users(:admin),
      title: "Peated Islay Journey",
      content: "A narrative through Islay's smoky drams.",
      price: 10
    )
  end

  # The core invariant: users.credits always equals the ledger sum.
  test "cached balance always equals the ledger sum" do
    CreditTransaction.record!(user: @user, amount: 3, transaction_type: "granted")
    assert_equal 3, @user.reload.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits

    CreditTransaction.record!(user: @user, amount: -1, transaction_type: "used")
    assert_equal 2, @user.reload.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
  end

  test "grant_monthly_credit adds one credit for active subscribers only" do
    assert_difference -> { @user.reload.credits }, 1 do
      CreditTransaction.grant_monthly_credit(@user)
    end

    @user.update!(subscription_status: "cancelled")
    assert_no_difference -> { @user.reload.credits } do
      CreditTransaction.grant_monthly_credit(@user)
    end
  end

  test "use_credit spends a credit and grants access atomically" do
    CreditTransaction.record!(user: @user, amount: 1, transaction_type: "granted")

    assert CreditTransaction.use_credit(@user, @presentation)
    assert_equal 0, @user.reload.credits
    assert @user.user_presentations.exists?(presentation: @presentation, purchase_type: "credit")
  end

  test "use_credit fails and grants nothing when balance is zero" do
    assert_equal 0, @user.credits
    assert_not CreditTransaction.use_credit(@user, @presentation)
    assert_equal 0, @user.reload.credits
    assert_not @user.user_presentations.exists?(presentation: @presentation)
  end

  test "expire_all_credits zeroes the balance" do
    CreditTransaction.record!(user: @user, amount: 5, transaction_type: "granted")
    CreditTransaction.expire_all_credits(@user)
    assert_equal 0, @user.reload.credits
  end

  test "admin_adjustment is a valid transaction type" do
    assert_difference -> { @user.reload.credits }, -2 do
      CreditTransaction.record!(user: @user, amount: -2, transaction_type: "admin_adjustment", description: "correction")
    end
  end

  test "rejects unknown transaction types" do
    assert_raises(ActiveRecord::RecordInvalid) do
      CreditTransaction.record!(user: @user, amount: 1, transaction_type: "bogus")
    end
  end
end
