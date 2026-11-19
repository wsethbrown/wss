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

  # --- B5: one monthly grant per (user, calendar month) ----------------------
  test "grant_monthly_credit grants once per calendar month and reports why it no-ops" do
    @user.update!(subscription_ends_at: nil) # open-ended, so the 2027 dates stay active
    travel_to Time.utc(2027, 3, 14, 11) do
      assert_equal :granted, CreditTransaction.grant_monthly_credit(@user)
      assert_equal :already_granted, CreditTransaction.grant_monthly_credit(@user)
      assert_equal "monthly:#{@user.id}:2027-03", CreditTransaction.where(user: @user).last.grant_key
    end
    travel_to Time.utc(2027, 4, 1, 11) do
      assert_equal :granted, CreditTransaction.grant_monthly_credit(@user)
    end
    assert_equal 2, @user.reload.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
  end

  test "grant_monthly_credit no-ops for inactive and paused members" do
    @user.update!(subscription_status: "past_due")
    assert_equal :inactive, CreditTransaction.grant_monthly_credit(@user)
    @user.update!(subscription_status: "active", subscription_paused_at: 1.day.ago)
    assert_equal :paused, CreditTransaction.grant_monthly_credit(@user)
    assert_equal 0, @user.reload.credits
  end

  test "a welcome credit right after this month's monthly credit does not double" do
    @user.update!(subscription_ends_at: nil) # open-ended, so the 2027 dates stay active
    travel_to Time.utc(2027, 5, 10, 9) do
      CreditTransaction.grant_monthly_credit(@user)
    end
    travel_to Time.utc(2027, 5, 10, 15) do
      assert_not CreditTransaction.grant_welcome_credit(@user)
    end
    assert_equal 1, @user.reload.credits
  end

  test "a re-subscriber later in the same month still earns a welcome credit" do
    @user.update!(subscription_ends_at: nil) # open-ended, so the 2027 dates stay active
    travel_to Time.utc(2027, 5, 2, 9) do
      CreditTransaction.grant_monthly_credit(@user)
      CreditTransaction.expire_all_credits(@user, "Subscription cancelled")
    end
    travel_to Time.utc(2027, 5, 25, 9) do
      assert CreditTransaction.grant_welcome_credit(@user)
    end
    assert_equal 1, @user.reload.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
  end

  test "a renewal that settles just after midnight on the 1st counts for the billing month it pays" do
    @user.update!(subscription_ends_at: Time.utc(2027, 2, 28, 23, 30))
    travel_to Time.utc(2027, 2, 28, 23, 29) do
      assert_equal :granted, CreditTransaction.grant_monthly_credit(@user)
    end
    # Stripe renewed the Feb 28 period; the invoice is paid on Mar 1 UTC.
    @user.update!(subscription_ends_at: Time.utc(2027, 3, 28, 23, 30))
    travel_to Time.utc(2027, 3, 1, 0, 40) do
      assert_equal "monthly:#{@user.id}:2027-02", CreditTransaction.monthly_grant_key(@user)
      assert_equal :already_granted, CreditTransaction.grant_monthly_credit(@user, "Monthly subscription renewal")
    end
    travel_to Time.utc(2027, 3, 28, 23, 0) do
      assert_equal :granted, CreditTransaction.grant_monthly_credit(@user)
    end
    assert_equal 2, @user.reload.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
  end
end
