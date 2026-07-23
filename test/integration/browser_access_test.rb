require "test_helper"

# Regression: `allow_browser versions: :modern` 406'd real Safari 17 users on
# Mac and iPhone — the whole site, and link previews with it (iMessage's
# fetcher is Safari-based). No browser floor should turn these away.
class BrowserAccessTest < ActionDispatch::IntegrationTest
  IPHONE_SAFARI = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) " \
                  "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1".freeze
  MAC_SAFARI = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " \
               "(KHTML, like Gecko) Version/17.0 Safari/605.1.15".freeze

  test "current Safari on iPhone and Mac is not turned away" do
    [ IPHONE_SAFARI, MAC_SAFARI ].each do |ua|
      get root_path, headers: { "User-Agent" => ua }
      assert_response :success, "Safari must not get a 'browser not supported' page"
      assert_no_match(/browser is not supported/i, response.body)
    end
  end

  test "a link-preview fetcher gets real OG metadata, not a browser gate" do
    society = Society.create!(name: "Preview Club", description: "x",
                              creator: users(:john), is_private: false)
    society.regenerate_invite_token!

    get society_invite_path(society.invite_token), headers: { "User-Agent" => MAC_SAFARI }
    assert_response :success
    assert_select "meta[property='og:image']"
  end
end
