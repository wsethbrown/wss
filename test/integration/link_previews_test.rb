require "test_helper"

# Open Graph / Twitter Card tags drive link previews in iMessage, Slack, X, etc.
class LinkPreviewsTest < ActionDispatch::IntegrationTest
  test "every page carries default OG tags and the brand card" do
    get root_path
    assert_response :success

    assert_select "meta[property='og:site_name'][content='Whiskey Share Society']"
    assert_select "meta[property='og:title'][content='Whiskey Share Society']"
    assert_select "meta[property='og:image'][content=?]", "http://www.example.com/og-card-2026.png"
    assert_select "meta[name='twitter:image'][content=?]", "http://www.example.com/og-card-2026.png"
    assert_select "meta[property='og:image:width'][content='1200']"
    assert_select "meta[property='og:image:height'][content='630']"
    assert_select "meta[property='og:description']"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    assert_select "meta[name='description']"
  end

  # The default card is a static file under a versioned name (Cloudflare holds
  # the old /og-image.png). It must exist and match the size the tags promise,
  # or iMessage falls back to the bare-domain chip. Sources: tools/og-card/.
  test "the default brand card is a 1200x630 PNG in public" do
    path = Rails.root.join("public", "og-card-2026.png")
    assert File.exist?(path), "public/og-card-2026.png is missing; render it with tools/og-card/render.sh"

    header = File.binread(path, 24)
    assert_equal "\x89PNG\r\n\x1A\n".b, header[0, 8], "not a PNG"
    width, height = header[16, 8].unpack("NN")
    assert_equal [ 1200, 630 ], [ width, height ]
  end

  test "deck pages preview as the deck" do
    deck = Presentation.create!(author: users(:admin), title: "OG Test Deck",
      content: "Smoke.", description: "A deck about link previews.", price: 10)
    deck.update_column(:published, true) # skip the deck-file publish guard

    get presentation_path(deck)
    assert_response :success

    assert_select "meta[property='og:title'][content=?]", "OG Test Deck - Whiskey Share Society"
    assert_select "meta[property='og:description'][content=?]", "A deck about link previews."
  end

  test "private societies are invisible to anonymous crawlers, OG tags included" do
    society = societies(:whiskey_lovers)
    society.update!(is_private: true, description: "Secret whiskey business")

    get society_path(society)

    # Anonymous visitors (crawlers included) get bounced before any page renders.
    assert_response :redirect
    assert_no_match(/Secret whiskey business/, response.body.to_s)
  end
end
