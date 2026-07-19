require "test_helper"

class SubscriptionsPauseTest < ActionDispatch::IntegrationTest
  def setup
    # The pause test's mock expects resumes_at: 1.month.from_now.to_i, and the
    # controller computes the same expression independently. Freeze the clock so
    # both reads agree even when the request crosses a second boundary.
    freeze_time

    @user = users(:seth)
    @user.update!(
      stripe_customer_id: "cus_test123",
      stripe_subscription_id: "sub_test123",
      subscription_status: "active",
      subscription_plan: "monthly",
      subscription_ends_at: 1.month.from_now
    )
    sign_in @user
  end

  test "pause subscription requires authentication" do
    sign_out @user
    post subscriptions_pause_path
    assert_redirected_to new_user_session_path
  end

  test "pause subscription fails without stripe subscription id" do
    @user.update!(stripe_subscription_id: nil)

    post subscriptions_pause_path

    assert_redirected_to account_path(anchor: "subscription")
    assert_match /No active subscription found/, flash[:alert]
  end

  test "pause subscription with valid subscription updates user status" do
    # Mock Stripe API call
    mock_subscription = OpenStruct.new(id: "sub_test123", status: "active")
    Stripe::Subscription.expects(:update).with(
      "sub_test123",
      {
        pause_collection: {
          behavior: "keep_as_draft",
          resumes_at: 1.month.from_now.to_i
        }
      }
    ).returns(mock_subscription)

    post subscriptions_pause_path

    @user.reload
    assert_equal "paused", @user.subscription_status
    assert_not_nil @user.subscription_paused_at
    assert_redirected_to account_path(anchor: "subscription")
    assert_match /paused successfully/, flash[:notice]
  end

  test "resume subscription requires authentication" do
    sign_out @user
    post subscriptions_resume_path
    assert_redirected_to new_user_session_path
  end

  test "resume subscription with valid subscription updates user status" do
    @user.update!(
      subscription_status: "paused",
      subscription_paused_at: Time.current
    )

    # Mock Stripe API call
    mock_subscription = OpenStruct.new(id: "sub_test123", status: "active")
    Stripe::Subscription.expects(:update).with(
      "sub_test123",
      { pause_collection: "" }
    ).returns(mock_subscription)

    post subscriptions_resume_path

    @user.reload
    assert_equal "active", @user.subscription_status
    assert_nil @user.subscription_paused_at
    assert_redirected_to account_path(anchor: "subscription")
    assert_match /resumed successfully/, flash[:notice]
  end

  test "pause subscription handles Stripe errors gracefully" do
    Stripe::Subscription.expects(:update).raises(
      Stripe::InvalidRequestError.new("Invalid subscription", "sub_test123")
    )

    post subscriptions_pause_path

    @user.reload
    assert_equal "active", @user.subscription_status # Status unchanged
    assert_nil @user.subscription_paused_at # Not paused
    assert_redirected_to account_path(anchor: "subscription")
    assert_match /Unable to pause subscription/, flash[:alert]
  end

  test "resume subscription handles Stripe errors gracefully" do
    @user.update!(
      subscription_status: "paused",
      subscription_paused_at: Time.current
    )

    Stripe::Subscription.expects(:update).raises(
      Stripe::InvalidRequestError.new("Invalid subscription", "sub_test123")
    )

    post subscriptions_resume_path

    @user.reload
    assert_equal "paused", @user.subscription_status # Status unchanged
    assert_not_nil @user.subscription_paused_at # Still paused
    assert_redirected_to account_path(anchor: "subscription")
    assert_match /Unable to resume subscription/, flash[:alert]
  end
end
