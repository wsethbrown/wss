# WSS — Section-by-Section Notes for the Next Engineer

> Written by the outgoing engineer during the section-by-section analytical pass
> (July 2026). Each section: what's there now, what was changed and why, and the
> known gaps with enough detail to act on. Read OVERHAUL_PLAN.md first for the
> big-picture history; this file is the working punch list.
>
> House rules for working on this codebase:
> 1. Verify in the browser, not just in tests. The dev stack is `./wss up`,
>    tests are `./wss test`.
> 2. No fabricated content, ever. No fake reviews/stats/guarantees.
> 3. The design system is the 2026 redesign: rules in docs/redesign/DESIGN_SYSTEM.md,
>    tokens and components in app/assets/tailwind/application.css, reference
>    implementation the homepage. Paper ground, white hairline cards, bottle
>    green for ink and solid objects, the logo orange as a small mark only.
>    Use it; don't invent new one-off colors.
>
> November 2026: the redesign programme (docs/redesign/TASKS.md) rebuilt every
> page below. Sections now describe the redesigned state; backend findings and
> their status live in docs/redesign/ARCHITECTURE_REVIEW.md and TASKS.md.
> Screenshots of every page at 1440px and 390px: docs/redesign/GALLERY.md.

---

## 1. Design system & layout chrome

**State:** Paper ground (`bg-paper`), white `.card` surfaces with a hairline edge,
at most one green `.panel-ink` per view, Instrument Sans for UI and headings,
Source Serif 4 for long reads. The nav is a floating rounded green bar 12px from
the top and the footer an inset rounded green panel, both in
app/views/layouts/application.html.erb. The layout has `lang="en"`, a skip link
to `#main-content`, and the nav avatar uses `DesignHelper#avatar` (initials on
`bg-whiskey-100`; `avatar_color` is no longer used anywhere in views). Shared
pieces: `shared/_page_header`, `DesignHelper#deck_cover`, `DesignHelper#avatar`,
`shared/_society_icon` (picture, else initials; no emoji). Rating stars
(`bottles/_rating`) are inline SVG in the orange mark with the value as sr-only
text. Turbo ignores `data-confirm`: use `turbo_confirm` (on the form for
`button_to`).

**Known simplification (left on purpose):** the layout's `full_bleed` list
(home index/membership, societies index/show/join_by_invite, events#show, every
presentations page, reviews index/show, bottles#show, the unified auth page)
renders `<main>` without the standard container, and each of those views carries
its own `max-w-6xl` / `pt-28` wrapper (or `clear_nav`). Nothing on those pages is
full-bleed any more, so the list could be removed and the wrappers deleted, but
that touches a dozen views at once and every one must be re-checked at both
widths. Do it as one dedicated change, not piecemeal.

**Gaps:**
- The mobile menu is a bare `<details>` dropdown; it doesn't close on
  navigation with Turbo. Low priority.
- No favicon refresh — still the default icon.png.

## 2. Homepage (app/views/home/index.html.erb)

**State:** The reference implementation of the 2026 design system: the pinned
how-it-works player showing real slides and real decks, the spotlight deck
(admin-featured; its first slide, else its cover, else no image), pricing from
`@stripe_products` (DOM contract pinned by
test/integration/home_subscription_cards_test.rb), FAQ. Do NOT reintroduce
`height: 100%` on body or `overflow-x: hidden` on ancestors; it kills sticky.
`/?design=next`, `next2` and `next4` render earlier studies (admin-only).

**Gaps:**
- FAQ copy should be read once by the owner for voice.

## 3. Deck library (/presentations)

**State:** Page header on paper, a filter row (search, category, level, sort),
the deck grid of `presentations/_deck_card` (cover from the first rendered slide,
else featured image, else a plain green block; title, one meta line, price or
"In your library"), kaminari pagination. Covers and ownership are preloaded
once per page. Default order pins featured decks first, except that a featured
deck with no cover is never placed above a deck with one
(test/integration/featured_decks_test.rb).

**Gaps:**
- Search matches title/description only (Presentation.search scope).
- No "Free" filter; free decks just show "Free" as the price.

## 4. Deck page (/presentations/:id)

**State:** Two acts. Sell: header with title, meta and description beside the
cover (the cover column is dropped when the deck has no slides and no featured
image, so the text takes the width), one action bar (`#deck-actions`), the story
teaser, the first slides, tasting notes, pours, reviews. Own: Present, downloads
and the whole story. **The story is gated:** non-owners get the first ~24 source
lines (`preview_markdown` in PresentationsHelper), cut at the source so hidden
content never reaches the DOM. Access is decided in the controller
(`@full_story`) and by the ownership row.

**Gaps:**
- The 24-line teaser threshold is arbitrary; revisit once real deck content
  exists (maybe a per-deck teaser marker).

## 5. Purchase & payments

**State:** One flow in Presentations::PurchasesController: free decks claimed
instantly (no Stripe), credit purchases require active membership + go
through the CreditTransaction ledger under a row lock, direct purchases via
Stripe Checkout (payment_method_types omitted on purpose — that's how
Checkout offers Apple Pay/Link/etc from dashboard settings). Fulfillment via
webhook (StripeEvent dedup table = idempotent). Downloads gate through
`can_download_full_presentation?` — lapsed credit owners are blocked and get
a reactivation message.

**Gaps / owner actions:**
- .env Stripe values are placeholders. NOTHING can be charged until real keys
  + price IDs are set. Then do one real test-mode purchase end-to-end
  (card 4242…) and a subscription cycle with `stripe listen`.
- Refunds: no in-app flow. Admin would refund via Stripe dashboard; the
  webhook doesn't handle `charge.refunded` → UserPresentation isn't revoked.
  Worth adding when refunds become real.
- Webhook processing is inline in the request; the plan was to move it to a
  Solid Queue job (OVERHAUL_PLAN Phase 2 TODO).

## 6. Societies

**State:** Index: page header on paper, your societies and discover lists, real
public societies with counts from the database, search. Show: header on paper
(name, place, counts, member actions), the next event as the one `.panel-ink`,
events, members (avatars), the review board and invite tools as cards with
ruled rows; section headings in sentence case. "Leave society" confirms through
`turbo_confirm`. Private societies show only the invite-only state to
non-members (SocietyPolicy). Invite links exist (`/invite/:token`).

**Gaps:**
- `SocietyApplication` model still has no routes/UI (self-serve requests to
  join private societies). B17 decides whether to remove it.
- Forums: `Forum` model exists, unbuilt. Decide to build or drop.

## 7. Events

**State:** Event page on paper: header (date, title, place, host), the RSVP
segmented control (Stimulus `segmented`, state on `aria-pressed`; the
going/maybe colours are the `rsvp-*` tokens), then cards for details, pours,
deck, table talk, attending and the society (its picture or initials). RSVP
updates by turbo_stream. "Table talk" comments: society members/organizer post
until a week after `end_time` (`Event#comments_open?`).

**Gaps:**
- events#index IS routed (nested: /societies/:id/events) — earlier draft of
  this note claimed otherwise. A cross-society "my events" page still doesn't
  exist and would be useful (all upcoming events for my societies).
- No calendar export (.ics) — small, high-value for a meetup product.
- Event reminders exist (EventReminderJob); event emails render times in UTC
  until B15 lands (I3).
- Event image/banner not supported.

## 8. Account (/account)

**State:** Panels are partials (`account/_*_panel`): Profile, Account details,
My presentations, My societies, Followed, Subscription, Billing. Section
navigation is a row of chips on phones and a left column on desktop; tabs are
switched by the `account-tabs` Stimulus controller (tablist/tab/tabpanel roles,
arrow keys; URL hash deep links; legacy
`?subscription` param for Stripe returns). In-panel links to another tab use
`data-tab-link` (billing's "View plans" → `/account#subscription`). Headings and
tab labels are sentence case.

**Gaps:**
- Billing history is read from Stripe invoices inline — consider a lazy Turbo
  frame.
- 2FA is half-built (S7, B11 blocked on the owner).

## 9. Auth (/auth)

**State:** One centred card on paper (Google button, magic link, password
toggle; ids `#magic-link-email`, `#password-toggle`, `#signin-email`,
`#signin-password` are relied on by tests and scripts). Sign-in endpoints are
rate limited (B3). Unified page: Google OAuth (button gated on real credentials —
see .env.example for the exact console steps), Apple (gated on APPLE_* env),
magic links (single-use, HMAC-digested, 15-min expiry, dedicated columns),
optional password. Devise sessions are hand-rolled in AuthController
(sign_in/logout) — works, tested, but nonstandard.

**Gaps:**
- The page still shows sign-up/sign-in as a JS toggle with inline
  `showMagicLinkForm()` script — works, but it's the last vanilla-JS island;
  convert to a small Stimulus controller for consistency.
- Password reset for password-users exists via Devise :recoverable but the
  path isn't linked prominently (magic link covers most cases).
- The Devise "Edit user" page (/users/edit) shows the email read-only and points
  to the account page; email changes happen only there (B8).
- Terms of Service / Privacy Policy links on sign-up are still `href="#"`
  (owner decision pending; no pages exist).
- Consider passkeys eventually; magic link + OAuth covers the near term.

## 10. Admin panel

**State:** Green sidebar shell (layouts/admin.html.erb): fixed 240px sidebar
from `lg`, a sticky top bar with a menu below it, `main` is `lg:ml-60 min-w-0`
(never flex-1). `lang="en"` and a skip link to `#admin-main`; no breadcrumbs
(page headers carry their own back link). Every page is built from the pattern
partials in `app/views/admin/shared/` (page header, filter bar, table, detail
panel, form card, stats, status chip with ok / attention / problem tones,
empty state, confirm button), each documented at its top. Money is shown with
`number_to_currency`. Limited admins see no delete controls (`can_delete?`).
Details: `.claude/skills/wss-admin`.

**Gaps:**
- Tracking cleanup (see §12) is still the agreed direction.
- No society/event moderation pages.

## 10b. Deck import + slide rendering (build/infra notes)

- Import accepts .pptx (full XML parse), .ppt and .pdf (LibreOffice→PDF→text via
  pdftotext for the draft). DeckImport.parse takes BYTES + filename — read the
  upload ONCE and hand each consumer a fresh StringIO (re-reading the request
  tempfile after an attach caused ActiveStorage::IntegrityError).
- Slide rendering (soffice --convert-to pdf, then pdftoppm) is HEAVY: it must
  run OFF the web request — DeckSlideRenderJob does it. Running soffice inside
  the dev web (foreman) process crashed the container: the memory spike killed
  the tailwindcss:watch process and foreman cascades SIGTERM to all. The job
  keeps it out of the web worker.
- Dev now runs Solid Queue (not :async): `config/initializers/solid_queue_dev.rb`
  points it at the primary DB, Procfile.dev has a `jobs:` process, and the
  queue schema was loaded into wss_development. Production already runs Solid
  Queue in its own DB + process (Kamal), so slide rendering is isolated there.
- LibreOffice + poppler-utils + fonts-liberation are in BOTH the canonical
  `Dockerfile` (Debian, the one Kamal builds) and `Dockerfile.dev`.
  NOTE: `Dockerfile.prod` is a STALE Alpine/Ruby-3.2 artifact, unused — delete it.
- New attachment: Presentation#slide_images (rendered pages, ordered by
  filename). The deck page shows first 3 to non-owners, all to owners; falls
  back to the text outline when no renders exist.

## 11. Deck authoring flow (/admin/presentations/new)

**State & design intent:** The form (admin/presentations/_form.html.erb) is
ordered as an authoring pipeline and should stay that way:
1. Essentials — title, category, price, difficulty, duration, banner.
2. The pitch — description (card copy) + "What You'll Learn" (structured
   editor → serialized to the legacy dash format, Stimulus
   `what_youll_learn_controller`).
3. The story — `content`, Markdown, rendered by the public reader;
   non-owners see only the first ~24 lines (gate lives in
   PresentationsHelper).
4. The tasting — nose/palate/finish/body + "Recommended Whiskeys"
   (structured editor → pipe format, `whiskey_recommendations_controller`).
5. Slide-by-slide preview — structured editor (`slides_preview_controller`,
   built during this pass) serializing to the legacy `Slide N|title|desc|min`
   pipe format. Slide numbers are derived from row order — admins never type
   them. Rows can be added/removed/reordered.
6. Files — preview images (max 3), main deck file, downloadables.

**Philosophy:** structured fields that serialize into the existing plain-text
column formats — no migrations, not freeform pipe syntax, not a rigid CMS.
If the formats ever get painful, the right move is JSONB columns
(whiskey_recommendations_json already exists as precedent) with a data
migration from the parsers in Presentation (parsed_slides_preview etc.).

**Gaps (owner-requested, scoped, not yet built):**
- STORY EDITOR: replace the raw textarea with a proper Markdown editor —
  recommended: EasyMDE (importmap-pin it, no build step) with a preview pane
  wired to a small POST /admin/presentations/preview endpoint that runs
  render_markdown, so preview matches the real reader exactly. Also show a
  marker at line 24 (the non-owner teaser cut).
- DECK TAGS: owner wants tags alongside categories. Tag model already exists
  (used for user tags with a category column). Plan: presentation_tags join
  table + tag-input (comma/datalist) on the form + tag chips on deck cards +
  tag filter on the library. Reuse Tag.find_or_create_by(name:, category:
  'deck').
- Category is now free-text with datalist suggestions (existing categories +
  defaults) — new categories like Cocktails just work; library filters
  already derive from data.
- No draft/publish workflow beyond the `published` checkbox (no preview-as-
  member link on the edit page; add one: it's just the public URL).
- Slide preview rows don't support drag reorder (up/down buttons only).

## 12. Tracking & data (assessment on record)

Decision record from the tracking review (implement in admin cleanup):
- KEEP: CreditTransaction (ledger, source of truth), UserPresentation
  (purchases), DownloadLog (powers analytics), Stripe as billing truth.
- CUT: `presentation_viewed` ActivityLog rows (56% of the table, per-view
  IP+UA, nothing uses it); ActivityLog download duplicates (broken anyway —
  validation silently rejects them); `download_count` counter column
  (derivable from DownloadLog).
- FIX-OR-CUT: login/logout logging (only password logins are recorded).
- LONG-TERM: retire ActivityLog entirely; the Activity admin tab can render
  the ledger + purchases + DownloadLog instead.

## 13. Infrastructure, CLI, CI

- `./wss` CLI: up/down/restart/logs/console/bash/test/db/setup/clean/status,
  Compose v2. Test command runs against a dedicated test DB.
- CI (.github/workflows): test job with Postgres + bundle-audit + brakeman.
- Deploy: Kamal files exist but were never exercised in this overhaul.
  Deploy config (accessory DB? Solid Queue supervisor? storage volume for
  ActiveStorage) is UNVERIFIED — treat the first deploy as a project.
- ActiveStorage is local-disk; production needs S3/R2 config in
  config/storage.yml + `config.active_storage.service` switch.
- Secrets: `.env` (gitignored). The old committed Apple key must be revoked
  when Apple membership renews.

## 14. Test suite

About 800 tests in test/integration, test/controllers and test/helpers alone run
green (run the suite as `.claude/skills/wss-testing` describes). View tests
assert behaviour and content, not Tailwind classes. System tests
(test/system) need a ChromeDriver that matches the installed Chrome; in the
redesign sandbox they could not start (version mismatch), so account tab and
magic-link flows were checked in a real browser with Playwright instead.

## 15. Known pre-existing issues (not caused by the redesign)

- `/events/:id/reviews/new` without a `bottle` param returns 404.
- CLAUDE.md "Admin Panel Development" refers to `admin_panel_todo.md`, which does not
  exist. Owner to reword that section.
- The sign-up Terms and Privacy links are `href="#"`. Owner decision pending.
