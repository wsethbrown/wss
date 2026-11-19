require "test_helper"

# B6 / M5: on the webhook path a fulfilment error must propagate, so the
# webhook returns 5xx, releases its claim and Stripe retries. The return path
# (the buyer's browser) keeps the old behaviour: log and carry on.
class Presentations::CheckoutFulfillmentServiceTest < ActiveSupport::TestCase
  setup do
    @buyer = users(:john)
    @deck = Presentation.create!(author: users(:admin), title: "Fulfilment Service Deck",
                                 content: "A story.", price: 12.00)
  end

  def session
    Stripe::Checkout::Session.construct_from(
      id: "cs_service", payment_status: "paid", mode: "payment", payment_intent: nil,
      metadata: { "user_id" => @buyer.id.to_s, "presentation_id" => @deck.id.to_s }
    )
  end

  test "raise_errors re-raises a fulfilment error" do
    UserPresentation.stubs(:create!).raises(ActiveRecord::ConnectionNotEstablished, "db blip")
    assert_raises(ActiveRecord::ConnectionNotEstablished) do
      Presentations::CheckoutFulfillment.fulfill!(session, raise_errors: true)
    end
  end

  test "without raise_errors the error is logged and nil returned" do
    UserPresentation.stubs(:create!).raises(ActiveRecord::ConnectionNotEstablished, "db blip")
    assert_nil Presentations::CheckoutFulfillment.fulfill!(session)
  end

  test "a lost race is not an error even with raise_errors" do
    UserPresentation.stubs(:create!).raises(ActiveRecord::RecordNotUnique, "dup")
    assert_nothing_raised do
      Presentations::CheckoutFulfillment.fulfill!(session, raise_errors: true)
    end
  end
end
