require "test_helper"

# Owner-approved membership wording (2026-11). Pinned so it is not reworded by
# accident.
class MembershipWordingTest < ActionDispatch::IntegrationTest
  INCLUDED = "Selected decks are included with your membership.".freeze
  CREDIT_DECKS = "Decks you open with a credit stay open while you're a member. If you cancel, " \
                 "they lock until you rejoin or buy them, and your unused credits are kept for when you come back.".freeze

  test "the benefits list names included decks and keeps credit decks honest" do
    assert_includes Membership::BENEFITS, INCLUDED
    assert_includes Membership::BENEFITS, CREDIT_DECKS
    assert_not Membership::BENEFITS.any? { |b| b.include?("Keep your credit-unlocked decks") }
    assert_not Membership::BENEFITS.any? { |b| b.downcase.include?("short deck") }
  end

  test "the membership page lists both lines" do
    get membership_path
    assert_response :success
    assert_select "li", text: /#{Regexp.escape(INCLUDED)}/
    assert_select "li", text: /#{Regexp.escape(CREDIT_DECKS)}/
  end

  test "the purchase page tells a non-member what membership gives" do
    deck = Presentation.create!(author: users(:admin), title: "Wording Deck", content: "Story.", price: 15)
    deck.update_column(:published, true)
    sign_in users(:john)
    get new_presentation_purchase_path(deck)
    assert_response :success
    assert_select "p", text: /Members get one deck a month with their membership\./
    assert_no_match(/most months|cheaper than one deck/, response.body)
  end
end
