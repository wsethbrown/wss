require "test_helper"

# The link-preview card for a society invite (Og::SocietyCard + the token-gated
# endpoint). A shared invite unfurls into a branded card with the chapter name
# and logo instead of a bare domain chip.
class InviteCardTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:john)
    @society = Society.create!(name: "Cask Strength Chapter", description: "Neat, always.",
                               creator: @owner, is_private: false)
    @society.regenerate_invite_token!
  end

  test "a valid token serves a PNG card" do
    get society_invite_card_path(@society.invite_token)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert response.body.start_with?("\x89PNG".b), "not a PNG"
  end

  test "an unknown token is a 404 and never echoes the token" do
    get society_invite_card_path("definitely-not-a-real-token")
    assert_response :not_found
  end

  # The card is served WITHOUT authentication: link-preview scrapers have no
  # session. Possessing the token is the authorisation, same as the peek.
  test "the card needs no login, because the token is the key" do
    get society_invite_card_path(@society.invite_token)
    assert_response :success
  end

  test "the invite page advertises the card as its og:image, with a cache stamp" do
    get society_invite_path(@society.invite_token)
    assert_response :success

    stamp = SocietiesController.invite_card_cache_key(@society).split("/").last
    assert_select "meta[property='og:image'][content=?]",
                  society_invite_card_url(@society.invite_token, v: stamp)
    assert_select "meta[property='og:title'][content=?]",
                  "You're invited to Cask Strength Chapter - Whiskey Share Society"
    assert_select "meta[property='og:description'][content=?]", "Neat, always."
  end

  # A private chapter can be previewed BECAUSE the token authorises it — the
  # same rule that lets the peek page show a private society at all.
  test "a private society still gets a card through its invite token" do
    private_society = Society.create!(name: "The Vault", description: "Members only.",
                                      creator: @owner, is_private: true)
    private_society.regenerate_invite_token!

    get society_invite_card_path(private_society.invite_token)
    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "the cache stamp changes when the name changes, so scrapers refetch" do
    before = SocietiesController.invite_card_cache_key(@society)
    @society.update!(name: "Barrel Proof Chapter")
    assert_not_equal before, SocietiesController.invite_card_cache_key(@society.reload)
  end

  # The service must not crash on the shapes real data takes.
  test "the card renders for a plain name and a very long one" do
    png = Og::SocietyCard.new(@society).png
    assert png.start_with?("\x89PNG".b)

    @society.update!(name: "The Greater Metropolitan Rare Cask and Single Barrel Appreciation Chapter")
    long = Og::SocietyCard.new(@society).png
    assert long.start_with?("\x89PNG".b), "a long name must still produce a valid PNG"
  end
end
