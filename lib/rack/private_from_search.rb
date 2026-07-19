module Rack
  # Keep private surfaces out of search results, without depending on robots.txt.
  #
  # WHY THIS EXISTS: Cloudflare's managed robots.txt serves in front of the
  # origin and replaces our `User-agent: *` group with `Allow: /`, so the
  # Disallow rules in public/robots.txt never reach a crawler (found by
  # bin/smoke, 2026-07-19). Anything relying on that file alone is unprotected.
  #
  # An `X-Robots-Tag` response header is the stronger control anyway, and one
  # nothing in front of us can strip:
  #   - robots.txt asks a crawler not to FETCH a URL. A disallowed URL can
  #     still be indexed from inbound links, listed by URL alone.
  #   - `noindex` tells it not to INDEX what it fetched, which is what keeps a
  #     page out of results.
  #
  # WHY MIDDLEWARE, not a controller filter: this started as a before_action
  # and silently did nothing on exactly the pages that needed it most. Devise's
  # `authenticate_user!` throws to Warden, whose failure app builds a FRESH
  # response, discarding anything the controller set. At this layer the header
  # survives Warden redirects, 404s, and static files alike.
  #
  # These paths are already behind authentication; this is about not listing
  # them, and about token-bearing URLs (magic links, invitations, RSVP links)
  # never becoming searchable if one leaks into a referrer or a shared link.
  class PrivateFromSearch
    # Path prefixes that must never be indexed. Mirrors public/robots.txt, and
    # a test asserts the two stay in step.
    NOINDEX_PREFIXES = %w[
      /admin
      /account
      /notifications
      /magic_links
      /invitations
      /email_rsvps
    ].freeze

    # noindex: keep it out of results. nofollow: don't crawl on from a
    # token-bearing URL. noarchive: no cached copy of a private page.
    HEADER_VALUE = "noindex, nofollow, noarchive".freeze

    def self.private_path?(path)
      NOINDEX_PREFIXES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      # Decide on the way IN. Warden's failure app re-enters the stack with
      # PATH_INFO rewritten to "/unauthenticated", so by the time the response
      # comes back the path that needed protecting is gone. Deciding here also
      # means a redirect issued on behalf of /account is still stamped.
      private = self.class.private_path?(env["PATH_INFO"].to_s)

      # Remember it on the env too: the re-entrant call gets the same env, so
      # the inner pass can tell it is serving a private request even though its
      # own PATH_INFO no longer says so.
      private ||= env["wss.private_from_search"]
      env["wss.private_from_search"] = private

      status, headers, body = @app.call(env)
      headers["x-robots-tag"] = HEADER_VALUE if private
      [ status, headers, body ]
    end
  end
end
