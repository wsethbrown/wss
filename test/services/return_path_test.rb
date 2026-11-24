require "test_helper"

# Only same-site paths are ever accepted as a post-sign-in return target.
class ReturnPathTest < ActiveSupport::TestCase
  test "accepts same-site paths, with query and fragment" do
    assert_equal "/societies/1/events/2", ReturnPath.sanitize("/societies/1/events/2")
    assert_equal "/reviews?tab=circle#top", ReturnPath.sanitize("/reviews?tab=circle#top")
    assert_equal "/", ReturnPath.sanitize("/")
  end

  test "rejects anything that could leave the site" do
    [
      nil, "", "   ", "http://evil.example/x", "https://evil.example", "//evil.example/x",
      "/\\evil.example", "\\\\evil.example", "javascript:alert(1)", "evil.example/x",
      "/foo\nLocation: http://evil.example", "/foo\r\nbar", " /societies", "/%0d%0aSet-Cookie:x",
      "///evil.example", "/" + ("a" * 3000)
    ].each do |value|
      assert_nil ReturnPath.sanitize(value), "#{value.inspect} must be rejected"
    end
  end

  test "rejects sign-in pages themselves, so sign-in never loops" do
    %w[/auth /auth?return_to=/x /users/sign_in /magic_links/abc /invitations/abc /users/auth/google_oauth2].each do |value|
      assert_nil ReturnPath.sanitize(value), "#{value} must be rejected"
    end
  end

  test "rejects non-strings" do
    assert_nil ReturnPath.sanitize([ "/x" ])
    assert_nil ReturnPath.sanitize({ "a" => "/x" })
  end
end
