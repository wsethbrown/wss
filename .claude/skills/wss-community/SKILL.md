---
name: wss-community
description: WSS social layer — favorites-as-follows, follower counts, the Century badge, review upvotes, the Latest/Circle/Hot review feeds, the /contact page + Cloudflare email routing, and link-preview/favicon metadata. Use for anything touching following, feeds, badges, vote buttons, contact addresses, or OG/Twitter/favicon tags.
---

# WSS Community / Social Layer

The follow graph, feeds, and public-facing metadata. Reviews mechanics live in
wss-reviews; society privacy in wss-societies; paid tiers in wss-membership-model.

## Favorites ARE follows (`app/models/favorite.rb`)
- Polymorphic bookmark: `belongs_to :favoritable, polymorphic: true` on
  `Society | User`. There is NO separate Follow model — favoriting a person/society
  IS following it. "Favorite" and "follow" are the same row.
- `counter_cache: true` → `favoritable`'s `favorites_count` column. Both models
  expose it as the follow count:
  - `user.rb:160`   `def followers_count = favorites_count`
  - `society.rb:99` `def followers_count = favorites_count`
- Constraints: uniqueness on `[favoritable_id, user_id, favoritable_type]`;
  `not_yourself` blocks self-favoriting a User; `society_must_be_visible` runs
  `SocietyPolicy.new(user, favoritable).show?` — you cannot favorite a private
  society you can't see (validation error, not a crash).
- Privacy: WHO follows whom is private (favorites are only ever listed on the
  owner's own profile). The COUNT is public. Comment: `user.rb:157-159`.
- `FavoritesController` create is idempotent via `find_or_initialize_by` +
  `persisted? || save` (not literally `find_or_create_by`, same effect). Button
  flips in place via turbo_stream replace of `dom_id(favoritable, :favorite)`;
  success carries no flash — the filled/empty star IS the feedback. `destroy` is
  scoped to `current_user.favorites.find` → 404s on someone else's row.

## Century badge (`app/views/shared/_century_badge.html.erb`)
- 100+ followers. Threshold: `User::CENTURY_THRESHOLD = 100` (`user.rb:163`);
  society reuses it — `society.rb:102 def century? = followers_count >= User::CENTURY_THRESHOLD`.
  Applies to BOTH users and societies.
- Amber star inside a small circle coin. Sized in `em` (`h-[1.15em] w-[1.15em]`,
  star `0.7em`) so it tracks the adjacent text size at every call site.
- The WORD "Century" appears only in the `title=` tooltip and an `sr-only` span —
  plus the homepage FAQ (`home/index.html.erb:282` "What's the Century badge?").
  The full star+label pill was tried and rejected down to the bare coin.
- Renders nothing below threshold — call sites need no guard. Locals: `record`
  (responds to `#century?`), `tone` (`:light` paper / `:dark` char surfaces).
- Rendered next to author/society names in: profiles/show, societies/show,
  bottles `_tasting_card` / `_society_verdict_card`, events `_pours`, reviews
  `_review_card` / `_circle_row` / `_night_card` / show.

## Review upvotes (`app/models/review_vote.rb`)
- Thumbs-up ONLY, no downvotes. One per `[review_id, user_id]`; `not_own_review`
  blocks voting your own review.
- `counter_cache: :votes_count` on `reviews.votes_count` — LIFETIME total, used for
  bottle-page ordering. The Hot feed's 30-day window needs a real join, NOT this
  cache (see `Review.hot_ranked`).
- `ReviewVotesController` create/destroy swap `dom_id(review, :vote)` inline via
  turbo_stream + `review.reload`; idempotent create (`find_or_initialize_by`).

## The three /reviews feeds (`reviews_controller.rb#index`)
Tabs: **Latest** (default), **Circle**, **Hot** (also **Nights** = society verdicts,
see wss-reviews).
- Latest = `@recent_reviews`, `Review.recent_first`.
- Circle = `Review.for_circle(current_user)` (`review.rb:53`) — latest reviews by
  favorited users + reviews on favorited societies' events, deduped. `@in_circle`
  distinguishes "followed nobody" from "followed, no pours yet".
- Hot = `Review.hot_ranked` (`review.rb:42`) — LEFT JOIN counting `review_votes` in
  a 30-day window, `ORDER BY recent_votes_count DESC, created_at DESC`.
- `for_circle`/`hot_ranked` are class methods, not `scope`s (the braindump's
  "circle_reviews" scope does not exist — use `for_circle`).

### TRAP — filters apply to Latest ONLY
`params[:q]` (search), `params[:tags]`, and `params[:distillery]` filter the bottle
grid and `@recent_reviews` (Latest). **Circle and Hot silently ignore them** —
`@circle_feed_reviews`/`@hot_reviews` are built with no filter args
(`reviews_controller.rb:36-37`). A user who searches then clicks Circle/Hot sees the
UNfiltered feed. Don't "fix" this by wiring filters in without a design decision;
it's current behavior, not a bug in scope.

## Follower counts on profiles
- Profile: `profiles/show.html.erb:44` `pluralize(@user.followers_count, "follower")`.
- Society show renders only the Century badge next to the name, no numeric count.

## /contact + email routing
- `app/views/home/contact.html.erb` lists three addresses (all
  `@whiskeysharesociety.com`): **hello@**, **support@**, **partners@**.
  (Not seth@ — page wins over any older brief.)
- Delivery is **Cloudflare Email Routing**, configured in the Cloudflare dashboard,
  NOT in the repo. The three addresses forward to the owner's inbox. No outbound
  SMTP provider is chosen yet — replies come from the owner's own mail client, and
  the missing SMTP config also blocks magic links in prod (see wss-production-launch).
- If you change the addresses on /contact, update the Cloudflare routes to match
  (and vice-versa) — there is nothing in-repo to keep them in sync.

## Link previews + favicon (`app/views/layouts/application.html.erb`)
- OG + Twitter Card tags (commit be59e41): `og:site_name/type/title/description/
  image/url` (layout:23-28) + `twitter:card = summary_large_image` (:29). Per-page
  overrides via `content_for(:og_title/:og_description/:og_image)`; defaults fall
  back to the brand tagline and `{base_url}/og-image.png`. `base_url` = the runtime
  `request.base_url` (layout:21) — there is NO base_url constant. The canonical prod
  host is `whiskeysharesociety.com` (production.rb `default_url_options` + allowed
  hosts); anything needing absolute URLs off-request (sitemap, mailers) uses that.
- Favicons (layout:31-33): `rel="icon"` → `/icon.png` and `/icon.svg`;
  `apple-touch-icon` → `/icon.png`.
- `public/favicon.ico` is ALSO served as a static file (commits d0e3cb2/e8add33)
  because legacy browsers and crawlers request `/favicon.ico` blindly even though
  the layout points at icon.png/icon.svg. Keep all three files
  (`public/{favicon.ico,icon.png,icon.svg}`) in sync when rebranding.

## Gotchas / Traps
- Search/tags/distillery filters affect Latest only — Circle and Hot ignore them.
- `votes_count` is lifetime; never use it for the Hot feed's recency window.
- Favoriting a private society validates against `SocietyPolicy#show?` — a hidden
  society returns a validation error, not a 500.
- Self-favorite (User) and self-vote are model-validated; don't re-check in the
  controller, but don't assume the DB blocks them either.
- Century threshold is the single constant `User::CENTURY_THRESHOLD`; society
  references it — don't hardcode 100 elsewhere.
- The Century word lives only in the tooltip/sr-only/FAQ. Don't add a visible
  label pill — that direction was already rejected.
- Contact addresses and Cloudflare routes are two separate systems that must be
  hand-kept in sync; the routing config is not in git.
