require "test_helper"

# Scorecards are now file downloads, gated like the other owner files:
#   - a custom uploaded scorecard (optional, per deck)
#   - a static blank scorecard, always included as a fallback
# The old auto-generated HTML scorecard page has been retired.
class PresentationsScorecardTest < ActionDispatch::IntegrationTest
  def published_deck
    deck = Presentation.create!(author: users(:admin), title: "Islay Journey", content: "Smoky.", price: 10)
    deck.update_column(:published, true)
    deck
  end

  def owned_by(deck, user, purchase_type: "direct")
    UserPresentation.create!(user: user, presentation: deck, purchase_type: purchase_type, purchased_at: Time.current)
    deck
  end

  def sample_pdf
    fixture_file_upload("sample_scorecard.pdf", "application/pdf")
  end

  test "the retired generated-scorecard route no longer exists" do
    deck = published_deck
    get "/presentations/#{deck.id}/scorecard"
    assert_response :not_found
  end

  test "owner can download the always-present blank scorecard" do
    owner = users(:john)
    deck  = owned_by(published_deck, owner)
    sign_in owner

    get blank_scorecard_presentation_downloads_path(deck)
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "the owner downloads box lists the blank scorecard" do
    owner = users(:john)
    deck  = owned_by(published_deck, owner)
    sign_in owner

    get presentation_path(deck)
    assert_response :success
    assert_select "a[href=?]", blank_scorecard_presentation_downloads_path(deck), text: /Blank scorecard/
  end

  test "owner gets the custom scorecard when one is attached" do
    owner = users(:john)
    deck  = owned_by(published_deck, owner)
    deck.scorecard.attach(sample_pdf)
    sign_in owner

    get scorecard_presentation_downloads_path(deck)
    assert_response :redirect # redirects to the attached blob
  end

  test "custom scorecard falls back to the blank when none is attached" do
    owner = users(:john)
    deck  = owned_by(published_deck, owner)
    sign_in owner

    get scorecard_presentation_downloads_path(deck)
    assert_redirected_to blank_scorecard_presentation_downloads_path(deck)
  end

  test "anonymous visitors cannot download either scorecard" do
    deck = published_deck

    get blank_scorecard_presentation_downloads_path(deck)
    assert_redirected_to auth_path
    get scorecard_presentation_downloads_path(deck)
    assert_redirected_to auth_path
  end

  test "a signed-in non-owner cannot download the scorecards" do
    deck = published_deck
    sign_in users(:jane) # no purchase

    get blank_scorecard_presentation_downloads_path(deck)
    assert_response :redirect
    assert_no_match(/scorecard/, @response.body)
    get scorecard_presentation_downloads_path(deck)
    assert_response :redirect
  end

  test "a credit purchase without an active membership cannot download" do
    owner = users(:john)
    deck  = owned_by(published_deck, owner, purchase_type: "credit")
    # no active subscription -> credit access is revoked
    sign_in owner

    get blank_scorecard_presentation_downloads_path(deck)
    assert_response :redirect
    assert_no_match(/application\/pdf/, response.media_type.to_s)
  end
end
