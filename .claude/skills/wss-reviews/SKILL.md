---
name: wss-reviews
description: The review system — bottle catalog, solo + event reviews, event pours with the secret toggle, provenance veiling, society review boards, and the Phase 3 roadmap (deck ties)
---

# WSS Reviews

Spec: `docs/superpowers/specs/2026-07-06-review-system-design.md` (owner-approved;
read it before extending anything here). Plans:
`docs/superpowers/plans/2026-07-06-review-system-phase-1.md`,
`docs/superpowers/plans/2026-07-07-review-system-phase-2.md`.

## What exists (Phase 1 — the public bottle database)

- **Public section is `/reviews`** (`ReviewsController#index`) — the bottle
  library: search bar + result rows (name, style/region, distillery, average
  rating, reviewer count) plus a "Latest tastings" feed of recent reviews.
  A sort control sits beside the search box (`Bottle::SORTS`: top rated,
  most reviewed, A–Z, recently added; `Bottle.with_score` backs it, default
  `"top"`).
- **Bottle detail/new/create stay under `/bottles`**: `bottle_path`
  (`/bottles/<slug>`), slug URLs via `to_param`. No hard uniqueness; creation
  shows a near-match warning (`confirmed_duplicate=1` bypasses).
- **Autocomplete**: `GET /bottles/search?q=` returns JSON
  `[{ id, name, display_name, url, review_url }]`, consumed by
  `bottle_search_controller.js`.
- **Every review has its own public page** (`review_path`,
  `ReviewsController#show`) — the drill-down target from bottle pages, the
  /reviews feed, and profile tastings. Feed cards on /reviews are whole-card
  `<a>` links to the review page, equal-height and line-clamped so ragged
  note lengths don't break the grid.
- `Review` — user + bottle + **nullable event_id** + rating (decimal 2,1;
  half-steps 0.5–5.0, `Review::VALID_RATINGS`) + `notes` (free text — NOT
  `body`) + nose/palate/finish/body_notes. Two unique indexes:
  `(user_id, bottle_id, event_id)` and a partial `(user_id, bottle_id) WHERE
  event_id IS NULL` — one review per tasting context, one solo per bottle.
- Aggregation: `Bottle#average_rating` = mean of each user's LATEST review
  across contexts. `Bottle.with_score` computes the same thing in SQL for
  whole pages (`avg_rating`/`reviewers` columns; feeds `Bottle::SORTS`).
- `bottles/_rating` partial: displayed stars snap to the nearest 0.5, but the
  `aria-label` carries the true value; numerals render via
  `number_with_precision(precision: 2, strip_insignificant_zeros: true)`.
- Solo review CRUD: create nested under bottle (`Bottles::ReviewsController`),
  edit/delete top-level (`ReviewsController`, scoped `current_user.reviews` →
  404 for non-authors).

## What exists (Phase 2 — events and societies)

- `event_bottles` (`event`, `bottle`, `position`, `label`; unique per
  event+bottle; `EventBottle.ordered`). Managed on the EVENT PAGE by
  `policy(event).update?` holders (`app/views/events/_pours.html.erb`) —
  the events/edit view is an unstyled stub, so management lives on show.
- **Secret toggle**: `events.pours_hidden_until_complete`.
  `Event#pours_revealed?` (off-toggle OR past end_time),
  `Event#pours_visible_to?(user)` (revealed OR `Event#managed_by?` —
  organizer / society admin / global admin). Review buttons AND the review
  gate use `pours_revealed?` — even the organizer can't review early
  (`EventReviewTest#"organizer cannot review a secret pour before reveal"`
  pins this; organizers get NO early-review bypass).
- **Event reviews**: created only via
  `POST /events/:event_id/reviews?bottle_id=<slug>`
  (`Events::ReviewsController`). Create-time model gates, enforced in
  `Review#event_review_gates` (`on: :create`): bottle on the pour list,
  pours revealed, reviewer has a `status: "yes"` RSVP. Gates run once, at
  creation — edits (shared `ReviewsController`) never re-check and can never
  move a review between events (strong params omit event_id).
- **Event page "The pours"**: ordered rows, per-pour group mean (event-tagged
  reviews ONLY — computed in-view from `@pour_reviews`), expandable
  individual reviews, Review-this-pour / Edit-your-review buttons.
- **Provenance veiling** (`app/views/reviews/_event_card.html.erb`, rendered
  on bottle pages, profile tastings, and the review's own page): public
  society → clickable event card (title, date, society name, pour count →
  `society_event_path`). **Private society → the event title and date show,
  UNLINKED — no society name, no link, and no pour count. The line reads
  "A private society."** The rule is `society.public?`, NOT per-viewer:
  members and the review's own author see the veil too. A second partial,
  `reviews/_event_line`, exists ONLY because /reviews feed cards are
  themselves `<a>`-wrapped (whole-card links to the review page) — a nested
  `<a>` to the event would be invalid HTML, so `_event_line` renders the
  same veiled information as plain text with a calendar glyph instead of a
  link. Both partials share the exact veiling rule; don't let them drift.
- **Society review board** (`SocietiesController#show` → `@review_board`):
  bottles ranked by plain AVG of reviews joined through the society's
  events, with `COUNT(DISTINCT user_id)` reviewer counts and a member-review
  drill-down. This is an unweighted average over event reviews — a bottle
  re-tasted across two events counts each event's reviews equally, so a
  two-event re-taster's opinion is double-weighted relative to a one-event
  taster's. **Open question (owner decision pending): should the board
  weight by event, or by reviewer, instead of by raw review row?** Until
  decided, leave the plain AVG as-is. Inherits the society page's Pundit
  gate; no separate policy.
- Events/pours with reviews refuse destroy (`dependent: :restrict_with_error`
  on `Event#reviews`; `before_destroy` guard on `EventBottle`) — the night is
  on the record.

## What's next (do NOT improvise — the spec decides)

- Phase 3: `events.presentation_id`, deck pour-list ↔ bottle links, deck
  names on provenance cards, "search by chapter," review badges on deck pages.

## Traps

- The event review, not the user's solo review, feeds event/society
  aggregates — regardless of creation date (owner decision, in the spec).
- Bottle public score uses latest-per-user ACROSS contexts.
- Never store society/deck on a review; always derive through the event.
- `BottlesController#create` skips the near-match check for blank names so
  validation renders (see `@bottle.name.blank?` short-circuit) — don't
  "fix" this into always running the search.
- Adding a migration requires committing the regenerated `db/schema.rb` —
  parallel test workers build their databases from the schema dump, not by
  replaying migrations. A missing/stale dump makes every parallel test
  worker error out while a single-file run still passes (false green).
- Fixture landmines: eagle_rare must keep exactly one review (john, 4.0),
  lagavulin zero; whiskey_lovers must gain no membership fixtures
  (society_test pins its counts). The Phase-2 demo chain therefore lives on
  `societies(:single_malt)` with three dedicated bottles.
- `event_rsvps` fixtures must QUOTE `status: "yes"` — bare `yes` is YAML
  boolean true.
- `EventRsvp` validates "no RSVP after the event" — seeds for completed
  demo events bypass it with `save!(validate: false)` (documented dev
  shortcut, same spirit as the presentation publish bypass). The dev-only
  demo chain in `db/seeds.rb` (search "Review demo chain") builds on
  `societies[0]` (Athens Whiskey Society) with `find_or_create_by!`
  throughout — safe to re-run; verified idempotent by running
  `bin/rails db:seed` twice.
- The canonical event URL is `society_event_path(event.society, event)`;
  bare `event_path` is a legacy alias.
- Don't confuse the two veiling partials: `_event_card` is a standalone link
  (bottle pages, profile tastings, the review show page); `_event_line` is
  plain text for contexts where the enclosing element is already an `<a>`
  (the /reviews feed cards). Both veil private societies identically.

## Section search scope

/reviews search covers bottles AND societies: `policy_scope(Society).search(q)`
renders a "Societies" result group (private societies stay invisible to
non-members — the policy scope, not the view, enforces it; same scope backs
the grouped JSON at GET /reviews/search).

Three dropdown modes in bottle_search_controller.js:
- grouped (the /reviews page): entity-grouped Bottles/Societies results, NO
  add-a-bottle row — a society name or typo must never become a catalog entry.
- picker (GET /reviews/start, authed "Add a review" flow): bottle rows link
  straight to that bottle's review form (review_url in /bottles/search JSON);
  the "+ Add … as a new bottle" escape lives HERE, where intent is explicit.
- fill (the event pour form — a hidden `bottleId` target is present): rows
  fill the hidden bottle_id instead of navigating; the add-new escape carries
  `return_to` (internal paths only) so organizers land back on the event.
