---
name: wss-reviews
description: The review system — bottle catalog, solo + event reviews, event pours with the secret toggle, provenance veiling, society review boards, society verdict cards, and the flavor lexicon/palate wheel. Use for anything touching bottles, reviews, tastings, or verdicts. Social layer (favorites/votes/feeds/Century) lives in wss-community.
---

# WSS Reviews

Spec: `docs/superpowers/specs/2026-07-06-review-system-design.md` (owner-approved;
read before extending). Plans in `docs/superpowers/plans/2026-07-06-*` and `-07-*`.

## Phase 1 — the public bottle database

- **Public section is `/reviews`** (`ReviewsController#index`) — the bottle
  library: search + result rows (name, style/region, distillery, avg rating,
  reviewer count) plus a "Latest tastings" feed. Sort control uses `Bottle::SORTS`
  (top rated, most reviewed, A–Z, recently added; `Bottle.with_score`, default `top`).
- **Bottle detail/new/create under `/bottles`**: `bottle_path` (`/bottles/<slug>`,
  slug via `to_param`). No hard uniqueness; creation shows a near-match warning
  (`confirmed_duplicate=1` bypasses).
- **Autocomplete**: `GET /bottles/search?q=` → JSON `[{id,name,display_name,url,review_url}]`,
  consumed by `bottle_search_controller.js`.
- **Every review has a public page** (`review_path`, `ReviewsController#show`) — the
  drill-down from bottle pages, the feed, and profile tastings. Feed cards are
  whole-card `<a>` links, equal-height and line-clamped.
- `Review` — user + bottle + **nullable event_id** + rating (decimal 2,1; half-steps
  0.5–5.0, `Review::VALID_RATINGS`) + `notes` (free text, NOT `body`) +
  nose/palate/finish/body_notes. Two unique indexes: `(user_id, bottle_id, event_id)`
  and partial `(user_id, bottle_id) WHERE event_id IS NULL` — one per tasting context,
  one solo per bottle.
- Aggregation: `Bottle#average_rating` = mean of each user's LATEST review across
  contexts. `Bottle.with_score` computes the same in SQL (`avg_rating`/`reviewers`).
- `bottles/_rating`: stars snap to nearest 0.5; `aria-label` carries the true value.
- Solo CRUD: create nested under bottle (`Bottles::ReviewsController`); edit/delete
  top-level (`ReviewsController`, scoped `current_user.reviews` → 404 for non-authors).

## Phase 2 — events and societies

- `event_bottles` (`event`, `bottle`, `position`, `label`; unique per event+bottle;
  `EventBottle.ordered`). Managed on the EVENT SHOW page by `policy(event).update?`
  holders (`events/_pours.html.erb`) — events/edit is an unstyled stub.
- **Secret toggle**: `events.pours_hidden_until_complete`. `Event#pours_revealed?`
  (off-toggle OR past end_time); `Event#pours_visible_to?(user)` (revealed OR
  `managed_by?` — organizer/society admin/global admin). Review buttons AND the gate
  use `pours_revealed?` — even the organizer can't review a secret pour early
  (pinned by `EventReviewTest`; NO organizer bypass).
- **Event reviews**: created via `POST /events/:event_id/reviews?bottle_id=<slug>`
  (`Events::ReviewsController`). `Review#event_review_gates` (`on: :create`): bottle on
  the pour list, pours revealed, reviewer has a `status:"yes"` RSVP. Gates run once at
  creation — edits never re-check and can't move a review between events (strong params
  omit event_id).
- **Event adoption (owner rule, July 2026)**: a SOLO review created within 7 days of an
  attended event (RSVP yes) that poured that bottle is auto-linked to that event
  (`Bottles::ReviewsController#recent_attended_event_for`; most recent qualifying night
  wins; skips events whose (user,bottle) slot is already reviewed; past events are always
  revealed, so the gates hold by construction). The flash tells the reviewer it linked.
  Event provenance now has TWO entry points; don't "fix" the solo path back to solo-only.
- **Event page "The pours"**: ordered rows, per-pour group mean (event-tagged reviews
  ONLY, from `@pour_reviews`), expandable reviews, Review/Edit buttons.
- **Provenance veiling** (`reviews/_event_card.html.erb`, on bottle pages, profile
  tastings, review show): public society → clickable event card (title, date, society
  name, pour count → `society_event_path`). **Private society → title + date show,
  UNLINKED, no society name/link/pour count, line reads "A private society."** Rule is
  `society.public?`, NOT per-viewer — members and the author see the veil too. Second
  partial `reviews/_event_line` exists ONLY because feed cards are already `<a>`-wrapped
  (nested `<a>` is invalid HTML): same veiled info as plain text with a calendar glyph.
  Both partials share the exact rule; don't let them drift.
- **Society review board** (`SocietiesController#show` → `@review_board`,
  societies_controller.rb:57): bottles ranked by AVG of THIS society's event reviews,
  latest-per-member (`DISTINCT ON (user_id, bottle_id)` newest-first) so a re-taster
  refreshes rather than double-votes; `COUNT(DISTINCT user_id)` reviewers. Inherits the
  page's Pundit gate. **Open question (owner pending): weight by event or reviewer
  instead of raw row? Leave plain latest-per-member AVG until decided.**
- Events/pours with reviews refuse destroy (`dependent: :restrict_with_error` on
  `Event#reviews`; `before_destroy` guard on `EventBottle`) — the night is on the record.

## Society verdicts (bottle pages)

- `Bottle#society_verdicts` (bottle.rb:99): each PUBLIC society's collective take on the
  bottle from its event reviews — same latest-per-member math (`DISTINCT ON (user_id,
  society_id)`) as the board. Rows expose `verdict_avg` / `verdict_reviewers`. These
  cards LEAD the Tastings list on `bottles#show` (`_society_verdict_card.html.erb`).
- Card body: aggregate stars + `Review.common_descriptors(reviews)` (review.rb:95 — most
  common lexicon words per tasting section, each review counts a word once so one wordy
  taster can't dominate) and `Review.blended_wheel(reviews)` (review.rb:144 — mean of
  each member's wheel profile per family, renormalized).
- **Drill-in**: `GET /bottles/:id/verdicts/:society_id` (`bottles#verdict`, route
  `verdict`, `bottles/verdict.html.erb`) — aggregate up top, every individual tasting
  card below. **Private societies 404 there** (`Society.public_societies.find` +
  `find { }` guard raises `RecordNotFound`) — same veil as everywhere.
- **Tasting-nights feed** (`/reviews?feed=nights`, reviews_controller.rb:38): one card
  per NIGHT (the events, newest first, per-bottle room scores from `@night_pours`), built
  from `Event.joins(:society).where(societies: { is_private: false })`. A private society id in
  `?society=` silently falls back to unfiltered (same veil). NOTE: the
  `Review.from_tasting_nights` scope (review.rb:32) is defined but the controller does NOT
  call it — it queries Events directly; the scope is currently used only in tests.

## What's next (do NOT improvise — the spec decides)

- Phase 3 (deck ties): `events.presentation_id`, deck pour-list ↔ bottle links, deck
  names on provenance cards, "search by chapter," review badges on deck pages.

## Section search + three search modes

/reviews search covers bottles AND societies: `policy_scope(Society).search(q)` renders a
"Societies" group (private societies invisible to non-members — the policy scope, not the
view, enforces it; same scope backs `GET /reviews/search`).

Four dropdown modes in `bottle_search_controller.js`:
- **grouped** (/reviews): entity-grouped Bottles/Societies, NO add-a-bottle row — a name
  or typo must never become a catalog entry.
- **picker** (`GET /reviews/start`, authed "Add a review"): bottle rows link to that
  bottle's review form; the "+ Add … as a new bottle" escape lives HERE (explicit intent).
- **fill** (event pour form — hidden `bottleId` target present): rows fill the hidden
  bottle_id instead of navigating; add-new escape carries `return_to` (internal paths only).
- **chip** (account shelf editor — fill + `submitOnSelect` + `customName` target): picking
  a row submits the form immediately; the add-row fills `custom_name` (label via
  `addLabel`, `%s` = query) and submits WITHOUT creating a Bottle — the shelf must never
  become a side door into the catalog (shelf entries live in `shelf_items`, see
  wss-societies/profile notes and SECTION_NOTES §8).

## Flavor descriptors, tags, and the palate wheel

`Review::DESCRIPTOR_LEXICON` (9 families × curated words) lifts descriptors from the FOUR
TASTING FIELDS ONLY (never notes): `descriptor_tags` (word→family), `flavor_profile`
(family→strength), `Review.tagged(tags)` (AND semantics; family name matches any word;
Postgres `~*` with `\m` boundary). /reviews?tags=a,b filters bottles+feed with removable
chips. Review pages render clickable chips (tag_picker_controller → one combined tags URL)
and the palate wheel (`reviews/_palate_wheel` — server SVG, segments = families, opacity =
strength). Hand-set `flavor_wheel` values win over word counts. Tags are computed from
text, never stored — edit the lexicon freely.

## Social layer

Favorites (follows), review votes, Latest/Circle/Hot feeds, and the Century badge live in
**wss-community**. The veiled partials above are reused across all three feeds unchanged.

## Traps

- The event review, not the solo review, feeds event/society aggregates — regardless of
  creation date (owner decision, in the spec).
- Bottle public score uses latest-per-user ACROSS contexts.
- Never store society/deck on a review; always derive through the event.
- `BottlesController#create` skips the near-match check for blank names so validation
  renders (`@bottle.name.blank?` short-circuit) — don't "fix" it to always search.
- Adding a migration (review tables first hit this) requires committing the regenerated
  `db/schema.rb` or parallel workers error while single-file runs pass — full trap in wss-testing.
- Fixture landmines: `eagle_rare` must keep exactly one review (john, 4.0), `lagavulin`
  zero; `whiskey_lovers` must gain no membership fixtures (society_test pins counts). The
  Phase-2 demo chain lives on `societies(:single_malt)` with three dedicated bottles.
- `event_rsvps` fixtures must QUOTE `status: "yes"` — bare `yes` is YAML boolean true.
- `EventRsvp` validates "no RSVP after the event" — seeds for completed demo events bypass
  it with `save!(validate: false)`. The dev-only demo chain in `db/seeds.rb` (search
  "Review demo chain") builds on `societies[0]` (Athens Whiskey Society) with
  `find_or_create_by!` — idempotent, safe to re-run.
- Canonical event URL is `society_event_path(event.society, event)`; bare `event_path` is
  a legacy alias.
- Don't confuse the two veiling partials: `_event_card` is a standalone link; `_event_line`
  is plain text for `<a>`-wrapped feed cards. Both veil private societies identically.
