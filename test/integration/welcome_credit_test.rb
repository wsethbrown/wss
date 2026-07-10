require "test_helper"
require "minitest/mock"
require "ostruct"

# The welcome credit must be visible the moment a new subscriber lands back
# on the account page — granted synchronously on the success redirect, with
# the invoice.payment_succeeded webhook as fallback, deduped between them.
class WelcomeCreditTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @user.update!(stripe_customer_id: "cus_welcome_test")
    sign_in @user
  end

  test "landing on the success page grants the credit immediately" do
    fresh_sub = OpenStruct.new(created: 2.minutes.ago.to_i)
    stub_subscription_list(fresh_sub) do
      get account_path(subscription: "success")
    end

    # Redirects to strip the param — the banner is flash-driven (one-shot),
    # so a refresh can't resurrect it.
    assert_redirected_to account_path(anchor: "subscription")
    assert_equal 1, @user.reload.credits.to_i

    follow_redirect!
    assert_match "one deck credit added", response.body

    get account_path
    assert_no_match "one deck credit added", response.body, "banner must not survive a refresh"
  end

  test "the webhook arriving after the redirect does not double-grant" do
    fresh_sub = OpenStruct.new(created: 2.minutes.ago.to_i)
    stub_subscription_list(fresh_sub) do
      get account_path(subscription: "success")
    end
    assert_redirected_to account_path(anchor: "subscription")
    assert_equal 1, @user.reload.credits.to_i

    # Webhook fallback fires seconds later — deduped.
    assert_no_difference -> { @user.reload.credits.to_i } do
      CreditTransaction.grant_welcome_credit(@user)
    end
  end

  test "a forged success param with an old subscription grants nothing" do
    stale_sub = OpenStruct.new(created: 3.days.ago.to_i)
    stub_subscription_list(stale_sub) do
      get account_path(subscription: "success")
    end

    assert_redirected_to account_path(anchor: "subscription")
    assert_equal 0, @user.reload.credits.to_i
  end

  test "a Stripe outage on the redirect leaves the webhook fallback intact" do
    raiser = ->(*) { raise Stripe::APIConnectionError.new("down") }
    Stripe::Subscription.stub(:list, raiser) do
      get account_path(subscription: "success")
    end
    assert_redirected_to account_path(anchor: "subscription")
    assert_equal 0, @user.reload.credits.to_i

    # Webhook path still grants.
    assert CreditTransaction.grant_welcome_credit(@user)
    assert_equal 1, @user.reload.credits.to_i
  end

  test "an admin-granted welcome variant blocks the automatic grant" do
    CreditTransaction.record!(user: @user, amount: 1,
      transaction_type: CreditTransaction::TRANSACTION_TYPES[:granted],
      description: "Welcome credit - new subscription (backfill)")

    assert_not CreditTransaction.grant_welcome_credit(@user)
    assert_equal 1, @user.reload.credits.to_i
  end

  private

  def stub_subscription_list(subscription, &block)
    Stripe::Subscription.stub(:list, OpenStruct.new(data: [ subscription ]), &block)
  end

  def sign_in(user)
    post "/users/sign_in", params: { user: { email: user.email, password: "password" } }
  end
end
