require "test_helper"

# The production webhook endpoint is pinned to Stripe API 2025-05-28.basil,
# which removed subscription.current_period_end (moved to subscription items)
# and invoice.subscription (moved to invoice.parent.subscription_details).
# These tests feed the controller both the legacy and basil payload shapes.
class WebhooksBasilCompatTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @user.update!(stripe_customer_id: "cus_basil_test")
    @period_end = 30.days.from_now.to_i
  end

  test "subscription.created with basil payload (period end on items) sets subscription_ends_at" do
    payload = {
      id: "evt_basil_sub_created",
      type: "customer.subscription.created",
      data: {
        object: {
          id: "sub_basil_1",
          object: "subscription",
          customer: "cus_basil_test",
          status: "active",
          items: {
            data: [
              { id: "si_1", current_period_end: @period_end, price: { id: ENV["STRIPE_MONTHLY_PRICE_ID"] } }
            ]
          }
        }
      }
    }.to_json

    post webhooks_stripe_path, params: payload, headers: signed_headers(payload)

    assert_response :success
    @user.reload
    assert_equal "sub_basil_1", @user.stripe_subscription_id
    assert_equal "active", @user.subscription_status
    assert_in_delta @period_end, @user.subscription_ends_at.to_i, 1
  end

  test "subscription.created with legacy payload (top-level period end) still works" do
    payload = {
      id: "evt_legacy_sub_created",
      type: "customer.subscription.created",
      data: {
        object: {
          id: "sub_legacy_1",
          object: "subscription",
          customer: "cus_basil_test",
          status: "active",
          current_period_end: @period_end,
          items: { data: [{ id: "si_1", price: { id: ENV["STRIPE_MONTHLY_PRICE_ID"] } }] }
        }
      }
    }.to_json

    post webhooks_stripe_path, params: payload, headers: signed_headers(payload)

    assert_response :success
    @user.reload
    assert_equal "sub_legacy_1", @user.stripe_subscription_id
    assert_in_delta @period_end, @user.subscription_ends_at.to_i, 1
  end

  test "subscription_period_end picks the max across multiple items" do
    controller = WebhooksController.new
    sub = {
      "items" => {
        "data" => [
          { "current_period_end" => 100 },
          { "current_period_end" => 200 }
        ]
      }
    }
    assert_equal 200, controller.send(:subscription_period_end, sub)
  end

  test "invoice_subscription_id reads basil parent.subscription_details shape" do
    controller = WebhooksController.new
    legacy = { "subscription" => "sub_legacy" }
    basil = { "parent" => { "subscription_details" => { "subscription" => "sub_basil" } } }
    neither = { "parent" => nil }

    assert_equal "sub_legacy", controller.send(:invoice_subscription_id, legacy)
    assert_equal "sub_basil", controller.send(:invoice_subscription_id, basil)
    assert_nil controller.send(:invoice_subscription_id, neither)
  end

  test "line_subscription_id reads basil parent.subscription_item_details shape" do
    controller = WebhooksController.new
    legacy = { "subscription" => "sub_legacy" }
    basil = { "parent" => { "subscription_item_details" => { "subscription" => "sub_basil" } } }

    assert_equal "sub_legacy", controller.send(:line_subscription_id, legacy)
    assert_equal "sub_basil", controller.send(:line_subscription_id, basil)
  end

  private

  def signed_headers(payload)
    secret = Rails.configuration.stripe[:webhook_secret]
    timestamp = Time.now.to_i
    signature = Stripe::Webhook::Signature.compute_signature(
      Time.at(timestamp), payload, secret
    )
    {
      "Stripe-Signature" => "t=#{timestamp},v1=#{signature}",
      "Content-Type" => "application/json"
    }
  end
end
