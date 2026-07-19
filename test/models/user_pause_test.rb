require "test_helper"

class UserPauseTest < ActiveSupport::TestCase
  def setup
    @user = users(:seth) # Assuming you have a seth fixture
    @user.update!(
      stripe_customer_id: "cus_test123",
      stripe_subscription_id: "sub_test123",
      subscription_status: "active",
      subscription_plan: "monthly"
    )
  end

  test "subscription_paused? returns true when subscription_paused_at is present" do
    @user.update!(subscription_paused_at: Time.current)
    assert @user.subscription_paused?
  end

  test "subscription_paused? returns false when subscription_paused_at is nil" do
    @user.update!(subscription_paused_at: nil)
    assert_not @user.subscription_paused?
  end

  test "subscription_can_be_paused? returns true for active unpaused subscription" do
    @user.update!(
      subscription_status: "active",
      subscription_paused_at: nil,
      subscription_ends_at: 1.month.from_now
    )
    assert @user.subscription_can_be_paused?
  end

  test "subscription_can_be_paused? returns false for paused subscription" do
    @user.update!(
      subscription_status: "active",
      subscription_paused_at: Time.current
    )
    assert_not @user.subscription_can_be_paused?
  end

  test "subscription_can_be_paused? returns false for canceled subscription" do
    @user.update!(
      subscription_status: "canceled",
      subscription_paused_at: nil
    )
    assert_not @user.subscription_can_be_paused?
  end

  test "subscription_can_be_resumed? returns true for paused subscription" do
    @user.update!(subscription_paused_at: Time.current)
    assert @user.subscription_can_be_resumed?
  end

  test "subscription_can_be_resumed? returns false for unpaused subscription" do
    @user.update!(subscription_paused_at: nil)
    assert_not @user.subscription_can_be_resumed?
  end

  test "subscription_status_display returns 'Paused' for paused active subscription" do
    @user.update!(
      subscription_status: "active",
      subscription_paused_at: Time.current
    )
    assert_equal "Paused", @user.subscription_status_display
  end

  test "subscription_status_display returns 'Paused' for paused status" do
    @user.update!(
      subscription_status: "paused",
      subscription_paused_at: Time.current
    )
    assert_equal "Paused", @user.subscription_status_display
  end

  test "subscription_status_display returns 'Active' for active unpaused subscription" do
    @user.update!(
      subscription_status: "active",
      subscription_paused_at: nil
    )
    assert_equal "Active", @user.subscription_status_display
  end
end
