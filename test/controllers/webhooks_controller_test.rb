require "test_helper"
require "minitest/mock"

# B5 / M1, M4: the renewal webhook (invoice.payment_succeeded with
# billing_reason subscription_cycle) grants through the same per-month ledger
# key as the daily job, and refreshes the member's status from Stripe first so
# a recovered past-due payment still earns that month's credit.
class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @user.update!(stripe_customer_id: "cus_b5_webhook", stripe_subscription_id: "sub_b5",
                  subscription_plan: "monthly", subscription_status: "active",
                  subscription_ends_at: 20.days.from_now)
    @period_end = 30.days.from_now.to_i
  end

  test "a past-due member whose retry succeeds receives that month's credit" do
    @user.update!(subscription_status: "past_due")
    MonthlyCreditJob.perform_now
    assert_equal 0, @user.reload.credits, "no credit while past due"

    post_cycle_invoice("evt_b5_retry", retrieved_status: "active")

    assert_response :success
    assert_equal "active", @user.reload.subscription_status
    assert_equal 1, @user.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
  end

  test "renewal webhook and daily job in one month grant once" do
    post_cycle_invoice("evt_b5_cycle_1", retrieved_status: "active")
    assert_equal 1, @user.reload.credits

    @user.update!(subscription_ends_at: Time.current.change(day: [ Time.current.day, 28 ].min) + 1.month)
    MonthlyCreditJob.perform_now
    post_cycle_invoice("evt_b5_cycle_2", retrieved_status: "active")
    assert_equal 1, @user.reload.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
  end

  test "a cycle invoice for a subscription Stripe reports as canceled grants nothing" do
    post_cycle_invoice("evt_b5_canceled", retrieved_status: "canceled")
    assert_equal 0, @user.reload.credits
  end

  private

  def post_cycle_invoice(event_id, retrieved_status:)
    payload = {
      id: event_id,
      type: "invoice.payment_succeeded",
      data: { object: {
        id: "in_#{event_id}", object: "invoice", customer: "cus_b5_webhook",
        billing_reason: "subscription_cycle",
        parent: { subscription_details: { subscription: "sub_b5" } }
      } }
    }.to_json
    retrieved = { "id" => "sub_b5", "status" => retrieved_status, "current_period_end" => @period_end }
    Stripe::Subscription.stub(:retrieve, retrieved) do
      post webhooks_stripe_path, params: payload, headers: signed_headers(payload)
    end
  end

  def signed_headers(payload)
    secret = Rails.configuration.stripe[:webhook_secret]
    timestamp = Time.now.to_i
    signature = Stripe::Webhook::Signature.compute_signature(Time.at(timestamp), payload, secret)
    { "Stripe-Signature" => "t=#{timestamp},v1=#{signature}", "Content-Type" => "application/json" }
  end
end
