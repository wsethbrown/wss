require "test_helper"

class DeckSlidePreviewTest < ActionDispatch::IntegrationTest
  def build_deck(preview_count:, slides: 5)
    deck = Presentation.create!(author: users(:admin), title: "Islay Deck", content: "Smoke.", price: 10, preview_slide_count: preview_count)
    slides.times do |n|
      deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "slide#{n}.png", content_type: "image/png")
    end
    deck.update_column(:published, true) # skip the deck-file publish guard
    deck
  end

  test "a non-buyer sees the admin-set number of slides, then a paywall fade with a buy CTA" do
    deck = build_deck(preview_count: 2, slides: 5)

    get presentation_path(deck) # logged out — a non-buyer
    assert_response :success

    # Exactly the preview count of slides shown, then the fade + CTA.
    assert_select "p", text: "3 more slides in the full deck."
    assert_select "a", text: /Sign in to get this deck/
    # The fade overlay sits on the last previewed slide.
    assert_select "div.bg-gradient-to-b.to-white"
  end

  test "the preview count is admin-controlled per deck" do
    deck = build_deck(preview_count: 4, slides: 5)

    get presentation_path(deck)
    assert_response :success
    assert_select "p", text: "1 more slides in the full deck."
  end

  test "an owner or admin sees the whole deck with no paywall fade" do
    deck = build_deck(preview_count: 2, slides: 5)
    sign_in users(:admin)

    get presentation_path(deck)
    assert_response :success
    assert_select "p", text: /more slides in the full deck/, count: 0
  end

  private

  def sign_in(user)
    post "/users/sign_in", params: { user: { email: user.email, password: "password" } }
  end
end
