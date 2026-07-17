# Whiskey Shelf — chip entry + structured shelf items (owner-approved)

**Date:** 2026-07-17 · **Status:** approved by owner (data model, profile rendering, and copy
all approved via structured proposal; recommended options chosen in each case).

## Problem

The account profile's "My Whiskey Shelf" is a raw `users.whiskey_shelf` text column edited in a
monospace one-per-line textarea and rendered as amber pills on the public profile. The owner
dislikes the textarea UX, and the entries never connect to the bottle catalog even when the same
bottle has a page, ratings, and reviews.

## Approved design

### Data model — structured `shelf_items`

New table `shelf_items`:

| column | type | notes |
|---|---|---|
| `user_id` | bigint, null: false, FK, indexed | owner |
| `bottle_id` | bigint, nullable, FK | set for catalog-linked entries |
| `custom_name` | string, nullable | set for free-text entries (max 200) |
| `position` | integer, null: false | display order (append = max + 1) |

- Validation: **exactly one** of `bottle_id` / `custom_name` present.
- Uniqueness: `(user_id, bottle_id)` unique where `bottle_id` is not null;
  `custom_name` unique per user case-insensitively.
- `User has_many :shelf_items` (ordered by position, then id), `dependent: :destroy`.
- `ShelfItem#display_name` → `bottle.name` for linked entries, else `custom_name`.
  (Bottle's own `display_name` appends the distillery — used in the dropdown, not the chip.)
- Free-text entries deliberately **never** create `Bottle` records. The shelf is low-intent
  input; the catalog's junk-entry rule (see wss-reviews, grouped search mode) applies here.
  Cataloging happens through the existing "Add a review" flow only.

### Backfill migration

For each user with a non-blank `whiskey_shelf`: split on newlines, strip, reject blanks, and for
each line in order:

- exactly one `Bottle` with `lower(name) = lower(line)` → linked entry;
- zero or multiple matches → free-text entry (never guess between ambiguous matches).

`users.whiskey_shelf` is **kept** (data safety); it stops being written or rendered. Dropping it
is a follow-up once the backfill has been verified in production.

### Entry experience (account → Profile tab)

The textarea is replaced by a chip editor in its own section (separate from the profile form —
adds/removes apply immediately):

- Current shelf renders as removable chips: linked chips in whiskey-amber with a small link
  glyph; free-text chips quieter gray. Remove is an × per chip (DELETE).
- Below the chips, a search input backed by the existing `GET /bottles/search` autocomplete
  (`bottle_search_controller.js`). Selecting a catalog row adds it immediately (fills the hidden
  `bottle_id` and submits). A final row adds the typed text as a free-text entry (fills a hidden
  `custom_name` and submits).
- Controller: `Account::ShelfItemsController` — `create` (either `bottle_id` or `custom_name`)
  and `destroy`, scoped to `current_user`. Turbo Stream updates the editor in place; HTML
  fallback redirects back to the account profile tab.
- `bottle_search_controller.js` gains a submit-on-select variant of fill mode plus a
  configurable add-row that fills a `custom_name` target instead of navigating to
  `/bottles/new`. Existing grouped/picker/fill behavior is unchanged.
- `:whiskey_shelf` is removed from `account_controller.rb` profile params.

### Public profile rendering (profiles/show sidebar)

Replace the pill stack with a de-carded, hairline-separated list:

- Linked entries: bottle name links to the bottle page, with the community average + tasting
  count beside it (via one `Bottle.with_score` query for the whole shelf; rendered **only when
  reviews exist** — no fabricated or empty ratings).
- Free-text entries: plain muted text, no link, no rating.
- Section renders only when the user has shelf items (same as today's `present?` guard).
- Profiles already require sign-in (`ProfilesController` `authenticate_user!`); no new
  visibility rules.

### Copy (owner-approved, option A)

- Label: **"My whiskey shelf"**
- Helper: **"Search the bottle library, or add anything you keep on hand."**
- Free-text add row: **`+ Add "<query>" to my shelf as written`**

### Testing

- Model: exactly-one-of validation, per-user uniqueness (linked + free-text), display_name.
- Controller: add linked, add free-text, destroy, blank input rejected, auth required,
  cannot destroy another user's item.
- Profile view: linked entry renders as a link with rating when reviews exist; free-text plain.
- Respect fixture landmines (wss-reviews): no new reviews on `eagle_rare`/`lagavulin`, no
  memberships on `whiskey_lovers`.

### Out of scope

- Dropping `users.whiskey_shelf` (follow-up after prod verification).
- Any "who else has this bottle" / shelf-social features.
- Cataloging new bottles from the shelf editor.
