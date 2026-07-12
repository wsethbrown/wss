require "test_helper"

# The purchase card in the deck-show sidebar adapts to whether the viewer can
# spend a credit: credit is the primary option when they have one, otherwise the
# card offers only the cash purchase.
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

  test "member with a credit sees credit as the primary option and outright as secondary" do
    deck = paid_published_deck
    sign_in make_member_with_credit(users(:john))

    get presentation_path(deck)
    assert_response :success

    # Credit is the primary call to action.
    assert_select "a[href=?]", new_presentation_purchase_path(deck), text: /Use 1 credit/
    # Buying outright is still offered, as the secondary option, at the cash price.
    assert_select "a[href=?]", new_presentation_purchase_path(deck, method: "direct"), text: /Buy outright/
    assert_match(/\$17\.99/, @response.body)
    # No CTA on the page shouts the cash price when the viewer holds a credit —
    # the hero and story-gate CTAs became credit-first too.
    assert_no_match(/Get this deck — \$/, @response.body)
  end

  test "member with no credits sees only the cash option" do
    deck = paid_published_deck
    sign_in make_member_with_credit(users(:john), credits: 0)

    get presentation_path(deck)
    assert_response :success

    assert_select "a[href=?]", new_presentation_purchase_path(deck), text: /Get this deck/
    assert_no_match(/Use 1 credit/, @response.body)
  end

  test "a signed-in non-member sees only the cash option" do
    deck = paid_published_deck
    sign_in users(:jane) # no subscription, no credits

    get presentation_path(deck)
    assert_response :success

    assert_select "a[href=?]", new_presentation_purchase_path(deck), text: /Get this deck/
    assert_no_match(/Use 1 credit/, @response.body)
  end

  test "a signed-out visitor is prompted to sign in" do
    deck = paid_published_deck

    get presentation_path(deck)
    assert_response :success
    assert_select "a[href=?]", auth_path, text: /Sign in to get this deck/
    assert_no_match(/Use 1 credit/, @response.body)
  end

  test "the confirm page preselects credit by default for a member with a credit" do
    deck = paid_published_deck
    sign_in make_member_with_credit(users(:john))

    get new_presentation_purchase_path(deck)
    assert_response :success
    assert_select "input[name=purchase_method][value=credit][checked]"
    assert_select "input[name=purchase_method][value=direct]:not([checked])"
  end

  test "the outright link preselects the direct method on the confirm page" do
    deck = paid_published_deck
    sign_in make_member_with_credit(users(:john))

    get new_presentation_purchase_path(deck, method: "direct")
    assert_response :success
    assert_select "input[name=purchase_method][value=direct][checked]"
    assert_select "input[name=purchase_method][value=credit]:not([checked])"
  end
end
