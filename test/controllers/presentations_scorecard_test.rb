require "test_helper"

class PresentationsScorecardTest < ActionDispatch::IntegrationTest
  test "scorecard renders a printable card pre-filled from the pour list, plus a blank one" do
    deck = Presentation.create!(
      author: users(:admin),
      title: "Islay Journey",
      content: "Smoky drams.",
      price: 10,
      whiskey_recommendations_json: [
        { "name" => "Lagavulin 16", "region" => "Islay", "style" => "Peaty", "price" => "$90", "notes" => "smoke" }
      ]
    )
    deck.update_column(:published, true) # skip the deck-file-required publish guard

    get scorecard_presentation_path(deck)
    assert_response :success

    # Filled card carries the deck's pour and its 1–5 criteria.
    assert_select "h1", text: /Islay Journey/
    assert_select "td", text: /Lagavulin 16/
    assert_select "th", text: "Nose"
    assert_select "th", text: "Overall"
    # A blank card is always offered too, for a group pouring their own.
    assert_select "h1", text: /Your tasting night/
  end

  test "scorecard renders a blank card when the deck has no pour list" do
    deck = Presentation.create!(author: users(:admin), title: "No Pours", content: "x", price: 5)
    deck.update_column(:published, true)

    get scorecard_presentation_path(deck)
    assert_response :success
    assert_select "h1", text: /Your tasting night/
  end
end
