require "test_helper"

# B18: Stripe retries deliveries. The very same signed event, posted twice
# through the controller, must be handled exactly once: one credit, one trip
# to Stripe, and a 200 both times so Stripe stops retrying.
class WebhooksReplayTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @user.update!(stripe_customer_id: "cus_b18_replay", stripe_subscription_id: "sub_b18",
                  subscription_plan: "monthly", subscription_status: "active",
                  subscription_ends_at: 20.days.from_now)
    @payload = {
      id: "evt_b18_replay", type: "invoice.payment_succeeded",
      data: { object: {
        id: "in_b18", object: "invoice", customer: "cus_b18_replay", billing_reason: "subscription_cycle",
        parent: { subscription_details: { subscription: "sub_b18" } }
      } }
    }.to_json
  end

  test "the same event delivered twice grants one credit and is processed once" do
    retrieved = { "id" => "sub_b18", "status" => "active", "current_period_end" => 30.days.from_now.to_i }
    Stripe::Subscription.expects(:retrieve).once.returns(retrieved)

    2.times do
      post webhooks_stripe_path, params: @payload, headers: signed_headers(@payload)
      assert_response :success
    end

    assert_equal 1, @user.reload.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
    assert_equal 1, StripeEvent.where(stripe_event_id: "evt_b18_replay").count
    assert StripeEvent.processed?("evt_b18_replay")
  end

  test "a bad signature is refused and claims nothing" do
    post webhooks_stripe_path, params: @payload,
         headers: { "Stripe-Signature" => "t=1,v1=bogus", "Content-Type" => "application/json" }
    assert_response :bad_request
    assert_equal 0, StripeEvent.where(stripe_event_id: "evt_b18_replay").count
    assert_equal 0, @user.reload.credits
  end

  private

  def signed_headers(payload)
    secret = Rails.configuration.stripe[:webhook_secret]
    timestamp = Time.now.to_i
    signature = Stripe::Webhook::Signature.compute_signature(Time.at(timestamp), payload, secret)
    { "Stripe-Signature" => "t=#{timestamp},v1=#{signature}", "Content-Type" => "application/json" }
  end
end
