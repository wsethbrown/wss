require "test_helper"

# B8 (S4): sign-in and invite tokens travel as URL path segments, and lograge
# logs the path, so production logs carried live credentials. The scrubber
# replaces the token segment (and any token query value) with [FILTERED].
class LogPathScrubberTest < ActiveSupport::TestCase
  TOKEN = "Xy9_abc-DEF123ghiJKL456mnoPQR789stuVWX0yz12"

  test "scrubs the token segment of every token-bearing path" do
    {
      "/magic_links/#{TOKEN}" => "/magic_links/[FILTERED]",
      "/invitations/#{TOKEN}" => "/invitations/[FILTERED]",
      "/invite/#{TOKEN}" => "/invite/[FILTERED]",
      "/invite/#{TOKEN}/card" => "/invite/[FILTERED]/card",
      "/account/verify_email/#{TOKEN}" => "/account/verify_email/[FILTERED]",
      "/deck_news/confirm/#{TOKEN}" => "/deck_news/confirm/[FILTERED]"
    }.each do |raw, expected|
      assert_equal expected, LogPathScrubber.scrub(raw), raw
      refute_includes LogPathScrubber.scrub(raw), TOKEN
    end
  end

  test "keeps a format extension" do
    assert_equal "/invite/[FILTERED]/card.png", LogPathScrubber.scrub("/invite/#{TOKEN}/card.png")
    assert_equal "/magic_links/[FILTERED].json", LogPathScrubber.scrub("/magic_links/#{TOKEN}.json")
  end

  test "scrubs with a query string, and filters token values in the query" do
    assert_equal "/magic_links/[FILTERED]?utm_source=email",
                 LogPathScrubber.scrub("/magic_links/#{TOKEN}?utm_source=email")
    assert_equal "/email_rsvps/yes?token=[FILTERED]",
                 LogPathScrubber.scrub("/email_rsvps/yes?token=#{TOKEN}")
    assert_equal "/email_rsvps/maybe?a=1&token=[FILTERED]&b=2",
                 LogPathScrubber.scrub("/email_rsvps/maybe?a=1&token=#{TOKEN}&b=2")
  end

  test "the email RSVP path itself carries no token and is unchanged" do
    assert_equal "/email_rsvps/yes", LogPathScrubber.scrub("/email_rsvps/yes")
  end

  test "the deck-news unsubscribe link's token is a query value and is filtered" do
    assert_equal "/deck_news/unsubscribe?token=[FILTERED]",
                 LogPathScrubber.scrub("/deck_news/unsubscribe?token=#{TOKEN}")
  end

  test "leaves ordinary paths alone" do
    %w[/ /societies/12 /account /presentations/4/downloads/sneak_peek /invitations /magic_links /deck_news /deck_news/confirm
       /deck_news/unsubscribe].each do |path|
      assert_equal path, LogPathScrubber.scrub(path)
    end
  end

  test "handles nil" do
    assert_nil LogPathScrubber.scrub(nil)
  end

  test "is what the production lograge config applies" do
    data = { path: "/invite/#{TOKEN}", location: "https://x.test/magic_links/#{TOKEN}" }
    out = LogPathScrubber.lograge_before_format(data, {})
    assert_equal "/invite/[FILTERED]", out[:path]
    assert_equal "https://x.test/magic_links/[FILTERED]", out[:location]
    refute_includes out.to_s, TOKEN
  end
end
