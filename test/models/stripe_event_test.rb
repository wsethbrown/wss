require "test_helper"

class StripeEventTest < ActiveSupport::TestCase
  test "claim succeeds once and is rejected for duplicates" do
    assert StripeEvent.claim("evt_123", "invoice.payment_succeeded"),
      "first claim should win"
    assert_not StripeEvent.claim("evt_123", "invoice.payment_succeeded"),
      "duplicate delivery of the same event id should not be reprocessed"
  end

  test "release lets a failed event be retried" do
    assert StripeEvent.claim("evt_456", "customer.subscription.created")
    StripeEvent.release("evt_456")
    assert StripeEvent.claim("evt_456", "customer.subscription.created"),
      "after release, Stripe's retry should be able to reclaim the event"
  end
end
