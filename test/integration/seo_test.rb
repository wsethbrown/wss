require "test_helper"

# SEO surfaces (owner-approved, July 2026): sitemap, canonical, JSON-LD.
# The sitemap honors the veil: private societies and unpublished decks
# never appear.
class SeoTest < ActionDispatch::IntegrationTest
  test "the sitemap lists public content only" do
    public_society = Society.create!(name: "Sitemap Public", description: "x",
                                     creator: users(:john), is_private: false)
    private_society = Society.create!(name: "Sitemap Private", description: "x",
                                      creator: users(:john), is_private: true)
    get "/sitemap.xml"
    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type
    assert_match "https://whiskeysharesociety.com/membership", response.body
    assert_match society_path(public_society), response.body
    assert_no_match society_path(private_society), response.body
  end

  test "unpublished decks stay out of the sitemap" do
    published = Presentation.published.first
    unpublished = Presentation.unpublished.first
    get "/sitemap.xml"
    assert_match presentation_path(published), response.body if published
    assert_no_match "#{presentation_path(unpublished)}<", response.body if unpublished
  end

  test "pages carry a canonical tag without query strings" do
    get "/reviews?tags=smoke"
    assert_select 'link[rel="canonical"][href="https://whiskeysharesociety.com/reviews"]'
  end

  test "every page carries Organization JSON-LD" do
    get root_path
    assert_match '"@type":"Organization"', response.body
    assert_match '"name":"Whiskey Share Society"', response.body
  end

  test "deck pages add Product JSON-LD" do
    deck = Presentation.published.first
    skip "no published deck fixture" unless deck
    get presentation_path(deck)
    assert_match '"@type":"Product"', response.body
    assert_match '"priceCurrency":"USD"', response.body
  end

  test "robots.txt points at the sitemap" do
    text = File.read(Rails.public_path.join("robots.txt"))
    assert_match "Sitemap: https://whiskeysharesociety.com/sitemap.xml", text
  end
end
