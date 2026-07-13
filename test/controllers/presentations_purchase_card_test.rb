require "test_helper"

# The deck-show purchase CTAs are a single "Purchase" button that routes to the
# checkout screen; the credit-vs-card choice is made there. A member who holds a
# credit sees a subtle hint on the deck page; everyone else just sees Purchase.
class PresentationsPurchaseCardTest < ActionDispatch::IntegrationTest
  def paid_published_deck
    deck = Presentation.create!(author: users(:admin), title: "Islay Journey", content: "Smoky.", price: 17.99)
    deck.update_column(:published, true)
    deck
  end

  def make_member_with_credit(user, credits: 1)
    user.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
    CreditTransaction.record!(user: user, amount: credits, transaction_type: "granted") if credits.positive?
    user
  end

  test "a signed-in buyer sees a single Purchase button routing to checkout" do
    deck = paid_published_deck
    sign_in users(:jane) # no subscription, no credits

    get presentation_path(deck)
    assert_response :success

    assert_select "a[href=?]", new_presentation_purchase_path(deck), text: /Purchase/
    assert_match(/\$17\.99/, @response.body)
    # No split credit/cash buttons on the deck page anymore.
    assert_no_match(/Use 1 credit/, @response.body)
    assert_no_match(/Buy outright/, @response.body)
    # A non-member gets no credit hint.
    assert_no_match(/Members can use a credit/, @response.body)
  end

  test "a member with a credit sees the Purchase button plus a credit hint" do
    deck = paid_published_deck
    sign_in make_member_with_credit(users(:john))

    get presentation_path(deck)
    assert_response :success

    assert_select "a[href=?]", new_presentation_purchase_path(deck), text: /Purchase/
    assert_match(/Members can use a credit at checkout/, @response.body)
    assert_no_match(/Use 1 credit/, @response.body)
  end

  test "a member with no credits sees Purchase and no credit hint" do
    deck = paid_published_deck
    sign_in make_member_with_credit(users(:john), credits: 0)

    get presentation_path(deck)
    assert_response :success

    assert_select "a[href=?]", new_presentation_purchase_path(deck), text: /Purchase/
    assert_no_match(/Members can use a credit/, @response.body)
  end

  test "a signed-out visitor is prompted to sign in" do
    deck = paid_published_deck

    get presentation_path(deck)
    assert_response :success
    # The sidebar card and story gate prompt sign-in for signed-out visitors.
    assert_select "a[href=?]", auth_path, text: /Sign in to get this deck/
  end

  test "the checkout screen offers a credit choice to a member who has one" do
    deck = paid_published_deck
    sign_in make_member_with_credit(users(:john))

    get new_presentation_purchase_path(deck)
    assert_response :success
    # Credit is the default; buying outright is offered too.
    assert_select "input[name=purchase_method][value=credit][checked]"
    assert_select "input[name=purchase_method][value=direct]"
  end

  test "the checkout screen offers only card payment when the buyer has no credit" do
    deck = paid_published_deck
    sign_in users(:jane) # no subscription, no credits

    get new_presentation_purchase_path(deck)
    assert_response :success
    assert_select "input[name=purchase_method][value=direct][checked]"
    assert_select "input[name=purchase_method][value=credit]", count: 0
  end
end
