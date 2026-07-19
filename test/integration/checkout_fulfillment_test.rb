require "test_helper"
require "minitest/mock"

# Post-checkout fulfillment (bug found in dev, July 2026): access used to be
# granted ONLY by the Stripe webhook, so the buyer could land back on the
# deck page — greeted by a banner promising access — while the page still
# showed the Purchase button. The return path now verifies with Stripe and
# grants on the spot; the webhook stays the backstop. Both idempotent.
class CheckoutFulfillmentTest < ActionDispatch::IntegrationTest
  setup do
    @buyer = users(:john)
    @deck = Presentation.create!(author: users(:admin), title: "Fulfillment Deck",
                                 content: "A story.", price: 12.00)
    @deck.update_column(:published, true)
  end

  # A Stripe::Checkout::Session responds to the fields we read.
  def stripe_session(user: @buyer, presentation: @deck, payment_status: "paid", id: "cs_test_123")
    Stripe::Checkout::Session.construct_from(
      id: id, payment_status: payment_status, mode: "payment", payment_intent: nil,
      metadata: { "user_id" => user.id.to_s, "presentation_id" => presentation.id.to_s }
    )
  end

  test "a paid session grants the deck" do
    assert_difference "UserPresentation.count", 1 do
      Presentations::CheckoutFulfillment.fulfill!(stripe_session)
    end
    assert @deck.purchased_by?(@buyer)
    assert_equal "direct", UserPresentation.last.purchase_type
  end

  test "fulfilling twice grants once (webhook + return race)" do
    Presentations::CheckoutFulfillment.fulfill!(stripe_session)
    assert_no_difference "UserPresentation.count" do
      Presentations::CheckoutFulfillment.fulfill!(stripe_session)
    end
  end

  test "an unpaid session grants nothing" do
    assert_no_difference "UserPresentation.count" do
      Presentations::CheckoutFulfillment.fulfill!(stripe_session(payment_status: "unpaid"))
    end
  end

  test "a session belonging to someone else is refused" do
    assert_no_difference "UserPresentation.count" do
      Presentations::CheckoutFulfillment.fulfill!(stripe_session, expected_user: users(:jane))
    end
  end

  test "a session without deck metadata is ignored" do
    bare = Stripe::Checkout::Session.construct_from(id: "cs_x", payment_status: "paid", mode: "subscription", metadata: {})
    assert_nil Presentations::CheckoutFulfillment.fulfill!(bare)
  end

  test "the return page confirms ownership and redirects clean" do
    UserPresentation.create!(user: @buyer, presentation: @deck, purchase_type: "direct", purchased_at: Time.current)
    sign_in @buyer
    get presentation_path(@deck, purchase: "success", session_id: "cs_test_123")
    assert_redirected_to presentation_path(@deck)
    follow_redirect!
    assert_match "Purchase complete", response.body
    # The message must not survive the next plain visit.
    get presentation_path(@deck)
    assert_no_match "Purchase complete", response.body
  end

  test "purchase=success without a real purchase never claims access" do
    sign_in @buyer
    get presentation_path(@deck, purchase: "success")
    assert_redirected_to presentation_path(@deck)
    follow_redirect!
    assert_no_match "Purchase complete", response.body
    assert_match "still unlocking", response.body
  end

  # Regression: the placeholder went through the URL helper once, which
  # percent-encoded the braces; Stripe returned the literal placeholder and
  # the session could never be looked up. It must stay unencoded.
  test "the checkout success_url carries a literal session placeholder" do
    captured = nil
    creator = ->(args) { captured = args; OpenStruct.new(url: "https://checkout.stripe.com/x") }
    sign_in @buyer
    Stripe::Checkout::Session.stub(:create, creator) do
      Stripe::Customer.stub(:create, OpenStruct.new(id: "cus_test")) do
        post presentation_purchases_path(@deck), params: { purchase_method: "direct" }
      end
    end
    assert captured, "checkout session was not created"
    assert_includes captured[:success_url], "session_id={CHECKOUT_SESSION_ID}"
    assert_not_includes captured[:success_url], "%7B"
  end

  test "a cancelled return says so and clears the param" do
    sign_in @buyer
    get presentation_path(@deck, purchase: "cancelled")
    assert_redirected_to presentation_path(@deck)
    follow_redirect!
    assert_match "Purchase cancelled", response.body
  end
end
