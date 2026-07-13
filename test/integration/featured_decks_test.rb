require "test_helper"

class FeaturedDecksTest < ActionDispatch::IntegrationTest
  def published_deck(title:, featured: false)
    deck = Presentation.create!(author: users(:admin), title: title, content: "A story.", price: 9.99, featured: featured)
    deck.update_column(:published, true)
    deck
  end

  test "featured scope returns only featured decks" do
    a = published_deck(title: "Featured One", featured: true)
    published_deck(title: "Plain One")
    assert_includes Presentation.featured, a
    assert_equal 1, Presentation.featured.count
  end

  test "homepage spotlights a featured deck" do
    deck = published_deck(title: "Derby Mint Julep", featured: true)

    get root_path
    assert_response :success
    assert_match(/In the spotlight/, @response.body)
    assert_match(/Derby Mint Julep/, @response.body)
    assert_select "a[href=?]", presentation_path(deck), text: /See the deck/
  end

  test "homepage has no spotlight when no deck is featured" do
    published_deck(title: "Plain One")

    get root_path
    assert_response :success
    assert_no_match(/In the spotlight/, @response.body)
  end

  test "the spotlight is the most recently featured deck" do
    published_deck(title: "Older Feature", featured: true)
    newer = published_deck(title: "Newer Feature", featured: true)

    get root_path
    assert_select "a[href=?]", presentation_path(newer), text: /See the deck/
  end

  test "the library shows a Featured badge and pins featured decks first" do
    published_deck(title: "Plain Deck")
    featured = published_deck(title: "Featured Deck", featured: true)

    get presentations_path
    assert_response :success
    assert_match(/Featured/, @response.body)
    # Featured deck appears before the plain one in the default view.
    assert_operator @response.body.index("Featured Deck"), :<, @response.body.index("Plain Deck")
  end

  test "an admin can toggle featured from the deck form" do
    deck = published_deck(title: "Toggle Me")
    sign_in users(:admin)

    patch admin_presentation_path(deck), params: { presentation: { featured: "1" } }
    assert deck.reload.featured?, "expected the deck to be featured after the update"

    patch admin_presentation_path(deck), params: { presentation: { featured: "0" } }
    assert_not deck.reload.featured?, "expected the deck to be un-featured"
  end
end
