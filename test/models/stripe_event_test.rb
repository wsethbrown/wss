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

  # B6 / M8: a claim is "in flight" until marked processed. One that never
  # finished (deploy or kill mid-handler) can be re-claimed after 10 minutes.
  test "an unfinished claim is re-claimable only after it goes stale" do
    assert StripeEvent.claim("evt_stale", "invoice.payment_succeeded")
    assert_not StripeEvent.claim("evt_stale", "invoice.payment_succeeded"), "still in flight"

    travel 11.minutes do
      assert StripeEvent.claim("evt_stale", "invoice.payment_succeeded"), "stale claim is re-claimed"
      assert_not StripeEvent.claim("evt_stale", "invoice.payment_succeeded"), "the re-claim is in flight again"
    end
  end

  test "a processed event is never re-claimed" do
    assert StripeEvent.claim("evt_done", "invoice.payment_succeeded")
    StripeEvent.mark_processed("evt_done")
    assert StripeEvent.find_by(stripe_event_id: "evt_done").processed_at.present?

    travel 1.day do
      assert_not StripeEvent.claim("evt_done", "invoice.payment_succeeded")
    end
  end
end
