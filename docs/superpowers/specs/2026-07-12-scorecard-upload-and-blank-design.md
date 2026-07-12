# Scorecard upload + always-included blank — design & plan

**Date:** 2026-07-12 · **Owner-approved:** design + copy approved in session.

## Problem

Today a deck's tasting scorecard is an **auto-generated HTML print page**
(`/presentations/:id/scorecard`, built from the pour list, showing a filled card
+ a blank card), viewable by anyone who can see the deck. The owner wants:

1. Ability to **upload a custom scorecard** for a deck instead of relying on
   generation.
2. A **static blank scorecard** (the provided `WSS_Scorecard_Blank.pdf`) that is
   **always included** in the deck's downloadable files as a fallback — useful
   when a group pours different bottles than the deck suggests.

**Decision (owner):** *Replace* the generator. Each deck gets an optional custom
uploaded scorecard plus the static blank, both delivered as file downloads.
**Access:** owner-gated exactly like speaker notes / whiskey list — ownership
required (bought directly, or credit + active membership). Members who have not
purchased the deck cannot download.

## Design

### Data model
- `Presentation` gains `has_one_attached :scorecard` (optional custom PDF).
- The blank is one static asset shipped in the repo, identical for every deck:
  `app/assets/documents/wss_scorecard_blank.pdf` (non-public path so it can be
  served behind the ownership gate via `send_file`).

### Admin deck-editing page (`admin/presentations/_form.html.erb`)
- Replace the "Printable tasting scorecard / Generated automatically… No upload
  needed" info box with a real upload field.
- Copy (owner-approved):
  - Label: **"Custom tasting scorecard (PDF)"**
  - Hint: **"Upload a scorecard tailored to this deck's pours. Optional —
    buyers always get the standard blank WSS scorecard to fill in either way."**
- Show current filename + a download link when one is attached.
- Permit `:scorecard` in `presentation_params`.

### Buyer downloads (`presentations/show.html.erb`, owner-gated Downloads box)
- Add rows to the existing `downloads` list:
  - **"Tasting scorecard"** → custom file, rendered only when
    `@presentation.scorecard.attached?`.
  - **"Blank scorecard"** → static blank, always present.
- Both go through `Presentations::DownloadsController` under the existing
  `check_access` gate; both call `track_download`.

### Routes + controller (`Presentations::DownloadsController`)
- New collection routes under the nested `downloads` resource: `:scorecard`,
  `:blank_scorecard`.
- `#scorecard` → `redirect_to rails_blob_url(@presentation.scorecard)` when
  attached; otherwise redirect to the blank (safe fallback).
- `#blank_scorecard` → `send_file` the static asset,
  `type: "application/pdf", disposition: "attachment"`.
- Both log via `track_download` (file types `scorecard` / `blank_scorecard`).

### Retire the generator
- Remove the public `member { get :scorecard }` route on `resources
  :presentations` (routes.rb:151) and drop `:scorecard` from
  `PresentationsController` (`set_presentation` before_action + the action).
- Delete views: `presentations/scorecard.html.erb`,
  `presentations/_scorecard_sheet.html.erb`,
  `presentations/_scorecard_table.html.erb`.
- Remove the "Printable tasting scorecard" link on the buyer show page
  (show.html.erb ~292) — its job moves into the Downloads box.
- Keep `parsed_whiskey_recommendations` (still used for the whiskey list); only
  its scorecard usage is removed.

### Generator archival
- Stash the owner's Python generator under `script/scorecard/wss_scorecard.py`
  plus a `README.md` noting: it produced the shipped blank, needs CrimsonText
  TTFs in a sibling `fonts/` dir to run, and is NOT wired into the app runtime.

## Access & edge cases
- Non-owner / anon / member-without-purchase hitting either download → existing
  `check_access` redirects (sign in / buy / reactivate membership).
- Drafts: `DownloadsController#set_presentation` already 404s non-admins for
  unpublished decks.
- Custom link only renders when attached; the `#scorecard` action still guards
  and falls back to the blank if called without an attachment.

## Tests
- Download gating for `scorecard` + `blank_scorecard`: owner succeeds; anon,
  non-owner, and member-without-purchase are redirected.
- Blank is always downloadable on an owned, published deck.
- Custom scorecard is served when attached.
- Old `GET /presentations/:id/scorecard` now returns 404.
- Admin form accepts + persists a `scorecard` upload.

## Out of scope
- No change to the credit/purchase model or the other owner downloads.
- No per-deck generation of the blank (single static asset for all decks).
