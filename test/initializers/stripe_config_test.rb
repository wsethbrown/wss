require "test_helper"

# I14: Stripe calls must not be able to hang a page request for the SDK default of 30s/80s.
class StripeConfigTest < ActiveSupport::TestCase
  test "network timeouts are short and retries are bounded" do
    assert_operator Stripe.open_timeout, :<=, 5
    assert_operator Stripe.read_timeout, :<=, 15
    assert_includes 1..3, Stripe.max_network_retries
  end
end
