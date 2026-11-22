---
name: wss-admin
description: WSS admin panel — structure, layout traps, credit-adjustment rules, and the activity-tracking decisions. Use for admin UI changes or admin-reported issues.
---

# WSS Admin

## Structure
Green (`bg-char`) sidebar shell (layouts/admin.html.erb, links in
`admin/shared/_nav`; the current section gets `bg-oak` plus a thin `bg-mark` bar
and `aria-current`). Below `lg` the sidebar becomes a sticky top bar with a
`<details>` menu. Pages are built from the pattern partials in `admin/shared/`
(page header, filter bar, table, detail panel, form card, stats, status chip,
empty state, confirm button), each documented at its top. Status chips use three
tones only: ok / attention / problem. Sections: Dashboard · Decks · Bottles ·
Reviews (analytics) · Moderation · Users · Subscriptions · Credits
(+ /transactions ledger view) · Activity · Analytics.

**Moderation is POST-moderation by owner decision (July 2026):** review content
(text + photos) publishes instantly; members flag via the Report button on
review pages (ReviewReport, one per user per review, not your own). The admin
Moderation page queues open reports (dismiss closes ALL of a review's reports;
delete reuses the gated hard-delete so limited admins see no delete button) plus
pending BottleEdit proposals. If pre-moderation is ever wanted, the agreed rule
is auto-trust after ~3 approved photos; do not build it until asked.

**Revenue on the dashboard/subscriptions pages is estimated MRR** (active
subscribers per plan x live monthly-equivalent price via SubscriptionProducts,
the single pricing source shared with the homepage). Deck sales are exact from
UserPresentation. Never hardcode plan prices.

**Admin roles = `users.admin_role` enum (none/limited/full).** `User#admin?` is
true for either admin tier (limited OR full); `User#can_delete?` is true only for
full. admin_role is the single source of truth; the old `is_admin` boolean is
vestigial (backfilled once, no longer read by `admin?`). Roles are granted from
the admin USER PAGE (Role card selector → dedicated `update_role` action; only
full admins may change roles, never their own, value whitelisted; NEVER add
admin_role to user_params). A **limited** admin is a full
admin minus HARD-DELETE rights: the deck + review admin destroy actions call
`require_delete_rights!` (Admin::BaseController), and the society/presentation/event
`destroy?` policies gate the admin-override delete on `can_delete?` (owners and
organizers keep deleting their OWN records). Delete buttons hide for limited admins.

## Layout traps
- Fixed sidebar + `main` with `lg:ml-60 min-w-0` (no margin below `lg`, where the
  sidebar is a top bar). NEVER flex-1 on main (overflows the viewport by the
  240px sidebar width — clipped buttons/columns).
- The layout has `lang="en"` and a skip link to `#admin-main`. There are no
  breadcrumbs any more (the old `shared/_admin_breadcrumbs` render was removed;
  each page's header carries its back link).
- Stylesheets: "tailwind" + "application" (a `:app` typo once shipped the
  whole panel unstyled).

## Rules with teeth
- **Credits are never edited on the user form.** The edit page shows balance
  read-only + a link to Credits→adjust (ledger write). :credits must stay OUT
  of user_params.
- One page per deck: `/admin/presentations/:id/edit` (show only keeps the
  flash and redirects there). Markdown is rendered via render_markdown (never
  simple_format / raw dumps), slides are ordered by :id, and the Files tab is
  a COMPLETE file inventory (every slot: filename+size or "not uploaded").
- Admin deck table: title cell truncates (max-w-xs); whitespace-nowrap on it
  once pushed Actions off-screen.

## Activity tracking (decision record — implemented)
ActivityLog is CURATED, not a firehose:
- Logged: login/logout (all auth methods), purchases, credits used/added,
  subscription created/canceled/paused/resumed, society join/leave,
  event RSVPs, profile updates.
- NOT logged (removed deliberately): presentation_viewed (was >half the
  table, per-view IP+UA, unused), downloads (DownloadLog is the single
  download record; download_count column also exists).
- **Trap**: ACTIVITY_TYPES inclusion validation SILENTLY discards unknown
  types (logger swallows errors). Adding a new log_activity call ⇒ add the
  type to ActivityLog::ACTIVITY_TYPES in the same commit, or it never
  records.
- IP/UA live in dedicated columns only (not duplicated into metadata JSON).

## The deck page (admin/presentations/edit)

One page per deck, replacing the old view + edit pair (Nov 2026). A header
(sticky from `lg`) with the title, Published/Draft chip, facts line
(price · running time · slides · pours · purchases) and Save / Preview as
buyer / Publish-Unpublish, then six tabs: Overview, Slides and script, Pour
list, Listing, Files, Sales (`deck_tabs_controller.js`; tab in
`location.hash`; without JS every pane shows). Field groups are shared
partials (`_cover_fields`, `_takeaways_fields`, `_story_fields`,
`_tasting_fields`, `_pour_list_fields`, `_files_fields`); `_form` is the
one-column new-deck form built from the same partials.

Rules with teeth:
- ONE form (`#deck-form`) holds every editable field, so one Save saves all
  tabs. Forms can't nest: Overview (publish block), the second half of Files
  (package, re-render) and Sales sit OUTSIDE it; Save buttons outside use
  `form="deck-form"`. `presentation_page_test` checks every permitted param
  is on the form exactly once.
- Redirects back to the page carry the tab twice: as the anchor and in
  `flash[:deck_tab]` (Turbo drops anchors when following redirects).
- "Anything else" (`supplemental_materials`, has_many_attached): assigning
  REPLACES the set, and an empty array deletes every extra. The field uses
  `include_hidden: false`, and `handle_file_uploads` drops blanks and adds new
  uploads beside the existing ones (kept by signed blob id).
- `unsaved_changes_controller.js` guards edits WITHOUT disabling Turbo
  (disabling it skipped Delete/Unpublish's `data-turbo-confirm`): Turbo link
  visits become full loads (native leave prompt), forms without their own
  confirm ask once. Back/Forward are deliberately NOT guarded: holding
  `turbo:before-render` without resuming froze every later Turbo render.
- Every file field takes uploads only (`handle_file_uploads`, before the
  record is built on create too): a string would be read as a signed blob id
  and attach any stored blob.
- After a refused save, read-only parts render `admin_deck_saved(deck)` (the
  stored record) so they never show an unsaved title or file.
- "The buyer page" checklist (Overview) recomputes per render: green = will
  render (`bg-ink`), pale = hidden because empty, red (`bg-rsvp-no`) = blocks
  the sale, mid green (`bg-whiskey-400`) = slides (automatic). No amber. If
  you add a buyer-page section, add its checklist row, linked to its tab.
- Per-slide script: `presentations.slide_script` (jsonb, `[{title, body}]`),
  written by DeckPackageImport from `## [SLIDE n] Title` sections. Paid
  content: rendered ONLY on the admin Slides tab. Decks loaded before it show
  an Open link to the speaker notes PDF until re-uploaded.
- Admin "Open" on files: `Admin::PresentationFilesController`, whitelisted
  slot names (the nth extra by `?n=`), never a blob id; short-lived URL.

Design rules learned the hard way:
- There is NO manual slide-outline builder. Slides render from the deck file;
  `slides_preview` is a legacy column still written by DeckImport and rendered
  only as a fallback for unrendered drafts (which can't be published anyway).
  Don't resurrect the builder.
- `preview_images` is dead — never shown to buyers; removed from form/permit.
- Copy must stay topic-generic ("the pour list", "what to pour", origin) —
  decks cover cocktails and more, not just whiskey. Never "Whiskey
  recommendations". Storage keys keep the legacy `whiskey_*` names.
- `Presentation#duration_label` renders duration everywhere ("20" → "20 min");
  never interpolate raw `duration` into buyer copy.

## The story editor (chapter cards)

`story_chapters_controller.js` presents `presentation.content` (one Markdown
string, `## ` headings = chapters) as chapter cards: title + body per card,
reorder/remove/add, plus a raw-Markdown toggle for power edits. Every edit
serializes back into the hidden content field — the server format never
changed, and EasyMDE was removed with it (controller, importmap pin, CDN CSS,
and the server preview route all deleted; "Preview as buyer" is the preview).

The marker between cards (a sentence-case `text-mute` line between two
hairlines, no small caps) shows where the free teaser cuts off. It
mirrors `PresentationsHelper#preview_markdown` (first 24 SOURCE lines) — if
that number changes, change `TEASER_LINES` in the Stimulus controller too.

## Deck packages, unpublish and free decks (November 2026)

Decks can be created or replaced in place from a package zip (deck list → "Upload a package";
a deck's Files tab → "Replace with a package"). The Unpublish button states how many people own the
deck; owners keep access after it. Publishing at $0 is refused unless "This deck is free" is
ticked. Details: wss-deck-pipeline.
