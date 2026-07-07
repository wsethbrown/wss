# Review System — Design

**Date:** 2026-07-06
**Status:** Approved by owner (brainstorm 2026-07-06); awaiting implementation plan.

## Purpose and positioning

WSS grows a review system serving three jobs, in this order of arrival:

1. **Public whiskey database (the wedge).** Anyone can look up a bottle and read
   reviews. Competes with distiller.com.
2. **Society tasting ritual.** Events list their pours; attendees review them;
   societies accumulate a review board.
3. **Deck sales support.** Reviews eventually surface on deck pages.

The differentiator against Distiller is **provenance**: a WSS review can carry
"tasted at a society event, as part of a guided deck" — structured tastings,
not drive-by ratings. A review seeded from an event is visibly different from
a solo review.

## Decisions made (owner-approved)

| Question | Decision |
|---|---|
| Wedge | Public bottle database first |
| Bottle creation | Any user, via autocomplete-first search; "add a new bottle" only when no match |
| Privacy | Reviews are always public; private-society context is veiled (generic badge), public-society context is linked |
| Review shape | Rating 1–5 in half steps + free-text notes + optional nose/palate/finish/body fields |
| Re-tastes | One review per user per bottle **per context** (an event, or solo); profiles show full history |
| Event reviews | Created only via the event's review button; RSVP "going" required; the event-tagged review is what feeds event and society aggregates, regardless of when it's written |
| Solo reviews | Started from bottle search; never tied to an event; never count toward event/society aggregates |
| Event pours | Events list presented bottles (ordered); optional **secret toggle** hides the list until the event ends, then reveals to the society |

## Data model

Three new tables. Society and deck are always **derived through the event**,
never stored on a review.

### `bottles`
- `name` (required), `distillery`, `region`, `style`, `abv` (all optional strings; abv decimal)
- `created_by_id` → users (who added it; informational)
- `slug` for public URLs
- Case-insensitive index on `(name, distillery)` for autocomplete and soft dedup
  (warn on near-match at creation; hard uniqueness is NOT enforced — an admin
  merge tool is deliberately deferred until duplicates justify it)

### `event_bottles`
- `event_id` → events, `bottle_id` → bottles, `position` (integer, ordered)
- `label` (optional string: "the blind", "pour #3")
- Unique on `(event_id, bottle_id)`
- Managed by the event organizer or society admins, same autocomplete +
  add-new flow as reviews
- **Secrecy:** `events.pours_hidden_until_complete` (boolean, default false).
  While true and the event hasn't ended, the pour list is hidden from
  everyone except the organizer/society admins. Once the event's end time
  passes, the list is visible to whoever can see the event (society members;
  public if the society is public). Review buttons appear only once visible.

### `reviews`
- `user_id` → users, `bottle_id` → bottles, `event_id` → events (**nullable**)
- `rating` decimal, required, 0.5–5.0 in 0.5 steps
- `notes` text (free-form review text)
- `nose`, `palate`, `finish`, `body_notes` (optional strings — the same
  tasting vocabulary the decks use; the free-form column is `notes`, NOT
  `body`, precisely to avoid colliding with `body_notes`)
- Uniqueness (PostgreSQL):
  - unique index on `(user_id, bottle_id, event_id)` — one review per tasting context
  - partial unique index on `(user_id, bottle_id) WHERE event_id IS NULL` —
    one solo review per user per bottle
- Reviews are editable and deletable by their author. Editing an event review
  does not change its event tie.
- Validation for event reviews: the bottle must be on the event's pour list,
  the pour list must be visible (not still secret), and the user must have
  an RSVP in state "going" for that event.

## Flows

**Add a bottle.** Every entry point (solo review, event pour list) starts with
autocomplete search over `bottles`. No match → "add a new bottle" form,
pre-filled from the query. Near-match warning shown before create.

**Solo review.** From the review section or a bottle page: pick/add bottle →
rating + notes form. `event_id` stays null.

**Event pours.** Organizer edits the event → "The pours" section → add bottles
in order, optionally label them, optionally flip the secret toggle.

**Event review.** On a visible pour list, each bottle shows a "Review this
pour" button to RSVP'd members. Creates the event-tagged review; one per
bottle per event per user. Written any time after reveal — a review left two
weeks after the night still belongs to the night.

## Rendering surfaces

**Bottle page (public).**
- Header: name, distillery/region/style/abv, aggregate score, reviewer count.
- Score = mean of each reviewer's **latest** review of the bottle (any context).
- Review feed, newest first. Each review: author, rating, notes, tasting
  fields, provenance badge:
  - solo → no badge
  - event in a **private** society → "Tasted at a WSS society event" (no link)
  - event in a **public** society → linked event + society (+ deck when Phase 3
    links events to decks)
- Per-reviewer history: "tasted 2×" expands to all their reviews of the bottle.

**Event page.** "The pours" in order (or "the pours are a secret until the
night" while hidden). After reveal: per-bottle review button and the group's
ratings (mean of that event's reviews per bottle).

**Society review board.** Aggregate over reviews tied to the society's events:
bottles ranked by the society's mean event-review rating, with drill-down to
individual member reviews per bottle.

**Review section (public).** Bottle search (name/distillery), recent-reviews
feed. "Search by chapter/deck" arrives in Phase 3.

**User profile.** The member's tastings, with provenance badges under the same
veiling rules.

## Aggregation rules (summary)

| Surface | Inputs |
|---|---|
| Bottle public score | Latest review per user, any context |
| Event group rating | Only reviews tagged to that event |
| Society board | Only reviews tagged to that society's events |

All aggregates are computed queries in Phase 1–2 (no stored aggregate rows,
no counter caches until performance demands them).

## Phasing

1. **Bottle catalog + solo reviews.** `bottles`, `reviews` (event_id present
   but unused by UI), bottle pages, review section with search, add-bottle
   flow, profile tastings.
2. **Events + societies.** `event_bottles` + secret toggle, event review flow
   with RSVP gate, provenance badges with privacy veiling, event group
   ratings, society review board with drill-down.
3. **Deck ties.** `events.presentation_id` (optional "we're running this deck
   tonight"), deck pour-list rows linked to bottle records, deck names on
   provenance badges, "search by chapter," review badges on deck pages.

## Testing

- Model: rating step validation, uniqueness (context + solo partial index),
  event-review validations (pour membership, RSVP, secrecy), aggregation
  math (latest-per-user, event-only, society-only).
- System: solo review flow, add-bottle flow, event pour management with
  secret reveal at end time, RSVP-gated event review, privacy veiling on
  bottle pages (private vs public society).
- The existing suite must stay green; reviews touch no existing tables
  except the two new columns on `events`.

## Deliberately deferred

- Admin bottle merge/dedup tool (until real duplicates exist)
- Moderation/reporting of reviews
- Flavor-profile attributes and flavor search
- Photos on reviews
- Any use of reviews on deck pages (Phase 3+)

## Addendum (2026-07-07, owner-approved): bottle images & detail enrichment

Queued as its own phase after Phase 2 (events/societies). Decisions:

- Reviews gain ONE optional attached photo.
- A bottle's default label image is DERIVED: the photo from its
  highest-rated review that has one (ties → most recent). Admins can pin an
  explicit label image, which beats the derived default; admins can delete
  a review's photo, the review, or both.
- No photo anywhere → a designed SVG placeholder (WSS linework bottle
  silhouette, tinted deterministically by style). Never a blank square, and
  no external/scraped imagery — licensing.
- Bottle detail enrichment (Distiller-style details page): optional
  `description` (text), `age_statement`, `cask_type`, `cost_tier`
  (1–5, rendered as $ glyphs) columns on bottles.
- Per-review photos are thereby UN-deferred from the original deferred list;
  moderation surface is the admin Bottles section (which also hosts the
  future merge tool).

## Addendum (2026-07-07, owner-approved): private-society veiling, refined

What privacy protects on a private society: joining without an invite,
member lists, and the event calendar. It does NOT hide that a tasting
happened. Therefore a review tied to a private society's event MAY show
the event's name and date (and the deck used, once Phase 3 links decks) —
but the SOCIETY stays hidden: no society name, no society link, and no
link into the society's event page (which would reveal it). Public
societies keep the fully linked event card. This supersedes the original
"generic badge only" veiling rule.

## Addendum (2026-07-07, owner idea, design queued): flavor-profile similarity

Reviews' nose/palate/finish/body fields are free text today. Future phase:
tokenize them into descriptor tags (a curated whiskey-descriptor lexicon —
peat, honey, cherry, oak... — matched against the text, not free tagging),
store as review_descriptors, and drive: (a) "tastes like" similar-bottle
suggestions on bottle pages ranked by shared-descriptor weight; (b) simple
infographics (descriptor frequency bars per bottle — "what 12 reviewers
smell"). Sequenced after the images/enrichment phase. UN-defers "flavor
search" from the original deferred list, in this constrained form.
