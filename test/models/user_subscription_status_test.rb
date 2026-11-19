require "test_helper"

# B6 / M19, M18: subscription status uses Stripe's spellings only, and a Stripe
# customer id belongs to at most one user.
class UserSubscriptionStatusTest < ActiveSupport::TestCase
  setup { @user = users(:john) }

  test "statuses are Stripe's set" do
    assert_equal %w[incomplete incomplete_expired trialing active past_due canceled unpaid paused].sort,
                 User.subscription_statuses.keys.sort
  end

  test "the British spelling is normalised to Stripe's on write" do
    @user.update!(subscription_status: "cancelled")
    assert_equal "canceled", @user.reload.subscription_status
    assert_equal "canceled", User.where(id: @user.id).pick(:subscription_status)
  end

  test "an unknown status is a validation error, not an exception" do
    @user.subscription_status = "bogus"
    assert_not @user.valid?
    assert @user.errors[:subscription_status].any?
  end

  test "nil is allowed" do
    @user.subscription_status = nil
    assert @user.valid?
  end

  test "a canceled member's status displays as cancelled" do
    @user.update!(subscription_status: "canceled")
    assert_equal "Cancelled", @user.subscription_status_display
  end

  test "a Stripe customer id is unique across users" do
    users(:john).update_column(:stripe_customer_id, "cus_dup")
    assert_raises(ActiveRecord::RecordNotUnique) do
      users(:jane).update_column(:stripe_customer_id, "cus_dup")
    end
  end

  test "many users may have no Stripe customer id" do
    users(:john).update_column(:stripe_customer_id, nil)
    assert_nothing_raised { users(:jane).update_column(:stripe_customer_id, nil) }
  end
end
