require "test_helper"

# Cloudflare's managed robots.txt replaces ours at the edge, so the Disallow
# rules never reach a crawler. These assert the header that does the work, and
# that it stays in step with the file we still ship.
class PrivateFromSearchTest < ActionDispatch::IntegrationTest
  HEADER = "X-Robots-Tag".freeze

  test "private paths are marked noindex even when they redirect to sign-in" do
    # Signed out, these redirect. The header must ride on the redirect too: a
    # crawler follows it, and the destination is what would get indexed.
    %w[/admin /account /notifications].each do |path|
      get path
      assert_includes response.headers[HEADER].to_s, "noindex", "#{path} must not be indexable"
    end
  end

  test "a token-bearing URL is noindex and nofollow" do
    get "/magic_links/some-token"
    assert_includes response.headers[HEADER].to_s, "noindex"
    assert_includes response.headers[HEADER].to_s, "nofollow",
                    "a crawler must not follow on from a token URL"
  end

  test "an admin sees the header on a real admin page, not just the redirect" do
    sign_in users(:admin)
    get admin_root_path
    assert_response :success
    assert_includes response.headers[HEADER].to_s, "noindex"
  end

  # The bug this middleware replaced: as a controller filter it did nothing on
  # Devise-protected pages, because authenticate_user! throws to Warden and the
  # failure app builds a fresh response.
  test "the header survives a Warden sign-in redirect" do
    get "/account"
    assert_response :redirect
    assert_includes response.headers[HEADER].to_s, "noindex",
                    "Warden's failure response must still carry the header"
  end

  test "it applies to a path with no controller at all" do
    get "/admin/definitely-not-a-real-page"
    assert_includes response.headers[HEADER].to_s, "noindex",
                    "a 404 under a private prefix must not be indexable either"
  end

  test "public marketing pages stay indexable" do
    %w[/ /presentations /societies /reviews].each do |path|
      get path
      assert_not_includes response.headers[HEADER].to_s, "noindex",
                          "#{path} is how customers find us; it must stay indexable"
    end
  end

  # The header list and robots.txt describe the same intent. Cloudflare is
  # currently ignoring the file, but it must not quietly become a lie.
  test "every path disallowed in robots.txt is covered by the header list" do
    disallowed = File.readlines(Rails.root.join("public/robots.txt"))
                     .filter_map { |line| line[/^Disallow:\s*(\S+)/, 1] }
    assert disallowed.any?, "robots.txt should still list the private paths"

    disallowed.each do |path|
      covered = Rack::PrivateFromSearch::NOINDEX_PREFIXES.any? do |prefix|
        path.chomp("/").start_with?(prefix)
      end
      assert covered, "robots.txt disallows #{path} but PrivateFromSearch doesn't cover it"
    end
  end
end
