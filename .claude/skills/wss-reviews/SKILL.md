---
name: wss-reviews
description: The review system — bottle catalog, solo reviews, aggregation rules, and the Phase 2/3 roadmap (event pours, society boards, deck ties)
---

# WSS Reviews

Spec: `docs/superpowers/specs/2026-07-06-review-system-design.md` (owner-approved;
read it before extending anything here).

## What exists (Phase 1)

- **Public section is `/reviews`** (`ReviewsController#index`) — the bottle
  library: search bar + result rows (Distiller-style: name, style/region,
  distillery, average rating, reviewer count) plus a "Latest tastings" feed
  of recent reviews. View: `app/views/reviews/index.html.erb`.
- **Bottle detail/new/create stay under `/bottles`**: `bottle_path`
  (`/bottles/<slug>`), `new_bottle_path`, `BottlesController#create`. Slug
  URLs via `to_param`. No hard uniqueness; creation shows a near-match
  warning (`confirmed_duplicate=1` bypasses). `Bottle.search` is the one
  search used by the index, the JSON autocomplete, and the dedup warning.
- **Autocomplete**: `GET /bottles/search?q=` (`search_bottles_path`,
  `BottlesController#search`) returns JSON
  `[{ name, display_name, url }]`, consumed by `bottle_search_controller.js`.
- `Review` — user + bottle + **nullable event_id** + rating (decimal 2,1;
  half-steps 0.5–5.0, `Review::VALID_RATINGS`) + `notes` (free text — NOT
  `body`) + nose/palate/finish/body_notes. Two unique indexes:
  `(user_id, bottle_id, event_id)` and a partial `(user_id, bottle_id) WHERE
  event_id IS NULL` — one review per tasting context, one solo per bottle.
- Aggregation: `Bottle#average_rating` = mean of each user's LATEST review
  (`DISTINCT ON (user_id) ... ORDER BY user_id, created_at DESC`). Computed,
  never stored.
- `app/views/bottles/_rating.html.erb` (the `_rating` partial): snaps the
  *displayed* stars to the nearest 0.5, clamped to 0.5–5.0 — but the
  `aria-label` always carries the true, unrounded value. Bottle show/index
  pages render the numeric average separately at
  `number_with_precision(precision: 2, strip_insignificant_zeros: true)`
  (e.g. `4.25`, or `4` for an exact 4.0).
- Solo review CRUD: create nested under bottle (`Bottles::ReviewsController`),
  edit/delete top-level (`ReviewsController`, scoped `current_user.reviews` →
  404 for non-authors).
- Profile tastings: `ProfilesController#show` loads
  `@user.reviews.includes(:bottle).recent_first.limit(20)` as `@tastings`,
  rendered in a "Tastings" section on `app/views/profiles/show.html.erb`.

## What's next (do NOT improvise — the spec decides)

- Phase 2: `event_bottles` join + `events.pours_hidden_until_complete`
  (reveal at `end_time`), RSVP-gated event reviews, provenance badges with
  privacy veiling (private society → generic badge, no link), society board.
- Phase 3: `events.presentation_id`, deck pour-list ↔ bottle links, search by
  chapter, deck-page badges.

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
  worker error out while a single-file run (which doesn't reload the test
  DB) still passes, which is a confusing false-green signal.

## Section search scope

/reviews search covers bottles AND societies: `policy_scope(Society).search(q)`
renders a "Societies" result group (private societies stay invisible to
non-members — the policy scope, not the view, enforces it). The JSON
autocomplete remains bottle-only on purpose: its job is feeding the
review/add-bottle flow.
