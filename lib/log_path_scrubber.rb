# Removes credentials from request paths before they are logged (B8, S4).
#
# Magic-link, admin-invitation, society-invite, email-change and deck-news
# confirm tokens are URL path segments, and lograge logs the path, so without this every sign-in link
# would sit in production logs. Query-string token values (the email-RSVP and
# deck-news unsubscribe links) are filtered too, in case a path ever arrives with its query attached.
#
# Used by config.lograge.before_format in config/environments/production.rb.
module LogPathScrubber
  FILTERED = "[FILTERED]".freeze

  # The token is the segment after each prefix; a trailing /card or .png stays.
  TOKEN_SEGMENT = %r{(/(?:magic_links|invitations|invite|account/verify_email|deck_news/confirm)/)[^/?#.]+}
  TOKEN_QUERY = /([?&]token=)[^&#]*/

  module_function

  def scrub(path)
    return path if path.nil?

    path.to_s.gsub(TOKEN_SEGMENT) { "#{Regexp.last_match(1)}#{FILTERED}" }
             .gsub(TOKEN_QUERY) { "#{Regexp.last_match(1)}#{FILTERED}" }
  end

  # lograge before_format hook: scrub the logged path and any redirect location.
  def lograge_before_format(data, _payload)
    data[:path] = scrub(data[:path]) if data.key?(:path)
    data[:location] = scrub(data[:location]) if data.key?(:location)
    data
  end
end
