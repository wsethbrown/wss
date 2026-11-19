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

  # --- B7 / M13: a paid checkout over a credit unlock upgrades the row --------
  test "a paid checkout over a credit unlock upgrades it to a direct purchase" do
    credit = UserPresentation.create!(user: @buyer, presentation: @deck, purchase_type: "credit", purchased_at: 2.days.ago)
    assert_no_difference [ "UserPresentation.count", "CreditTransaction.count" ] do
      result = Presentations::CheckoutFulfillment.fulfill!(session, raise_errors: true)
      assert_equal credit.id, result.id
    end
    row = credit.reload
    assert_equal "direct", row.purchase_type
    assert_equal 12.0, row.purchase_price.to_f
    assert row.direct_purchase?
  end

  test "an upgraded purchase survives the membership lapsing" do
    @buyer.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
    UserPresentation.create!(user: @buyer, presentation: @deck, purchase_type: "credit", purchased_at: 2.days.ago)
    Presentations::CheckoutFulfillment.fulfill!(session)
    @buyer.update!(subscription_status: "canceled", subscription_ends_at: 1.day.ago)
    assert @buyer.reload.can_access_presentation?(@deck.id)
  end

  test "a paid checkout for an already direct deck changes nothing" do
    direct = UserPresentation.create!(user: @buyer, presentation: @deck, purchase_type: "direct",
                                      purchase_price: 5, purchased_at: 2.days.ago)
    Presentations::CheckoutFulfillment.fulfill!(session)
    assert_equal 5.0, direct.reload.purchase_price.to_f
  end

  test "losing the creation race to a credit row still upgrades it" do
    credit = UserPresentation.create!(user: @buyer, presentation: @deck, purchase_type: "credit", purchased_at: 2.days.ago)
    # The locked lookup saw nothing (the credit row committed a moment later),
    # so creation hits the unique index.
    UserPresentation.stubs(:lock).returns(stub(find_by: nil))
    UserPresentation.stubs(:create!).raises(ActiveRecord::RecordNotUnique, "dup")
    Presentations::CheckoutFulfillment.fulfill!(session, raise_errors: true)
    assert_equal "direct", credit.reload.purchase_type
  end
end
