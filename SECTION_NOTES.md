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
> 3. The design system lives in app/assets/tailwind/application.css:
>    char/paper surfaces, whiskey scale, Fraunces/Instrument Sans/Source Serif 4,
>    `.eyebrow`, `.rule-double`, `.thread`, `.prose-deck`. Use it; don't invent
>    new one-off colors.

---

## 1. Design system & layout chrome

**State:** Two-surface identity — "char" (#191009, dark) for narrative surfaces,
paper/white for utility. Signature motif: the amber thread. Nav and footer are
char, in app/views/layouts/application.html.erb. Full-bleed pages (home,
societies index/show, all presentations pages) manage their own top padding via
mastheads; everything else gets the constrained container (see the `full_bleed`
conditional in the layout — and the comment about the fixed-sidebar/flex trap).

**Gaps:**
- The mobile menu is a bare `<details>` dropdown; fine, but it doesn't close on
  navigation with Turbo. Low priority.
- `avatar_color` user identicons (User#avatar_color) produce colors outside the
  brand palette (blues/greens). Harmless; could be re-mapped to whiskey tones.
- No favicon refresh — still the default icon.png. Consider a glencairn mark.

## 2. Homepage (app/views/home/index.html.erb)

**State:** Fully rebuilt. Hero (thread-underlined Fraunces headline), pinned
how-it-works split (grid + `self-start` sticky — do NOT reintroduce
`height: 100%` on body or overflow-x hidden on ancestors, it kills sticky),
ritual/house-rules section, featured decks (real DB records via the shared
`presentations/_deck_card` partial), pricing (DOM contract pinned by tests —
see test/integration/home_subscription_cards_test.rb), FAQ accordions.

**Gaps:**
- Pricing cards render from `@stripe_products` (HomeController#fetch_stripe_products,
  cached 1h, falls back to hardcoded `fallback_products`). Once real Stripe
  price IDs exist, verify metadata-driven features render correctly.
- FAQ copy is my rewrite; owner should read it once for voice.

## 3. Deck library (/presentations)

**State:** Char masthead, honest live filters (search debounce, category +
difficulty selects derived from the catalog, sort), kaminari pagination
(12/page, styles in the Tailwind file under `.pagination`), ownership badges,
two-flavor empty state. Cards are real links (the old page trapped decks
behind a JS modal).

**Gaps:**
- Search matches title/description only (Presentation.search scope). Consider
  including content/category.
- No "Free" filter; free decks just show "Free" as the price. Fine until
  there are many.

## 4. Deck page (/presentations/:id)

**State:** Char cover hero (featured image aware), takeaways grid, THE STORY
with reading-progress thread and markdown rendering (`render_markdown`,
sanitized, redcarpet). **The story is gated:** non-owners get the first ~24
source lines (`preview_markdown` / `story_truncated?` in
PresentationsHelper), cut at the source so hidden content never reaches the
DOM, fading into a purchase CTA. Owners/admins (via
`Presentation#can_download_full_presentation?` → `User#can_access_presentation?`)
get the full text. Tasting notes set like a back label; sidebar purchase card
is state-aware (signed-out / credit available / owned direct / owned credit /
owned credit + lapsed membership); "More from the library" at the bottom.

**Gaps:**
- The 24-line teaser threshold is arbitrary; if owners write short stories the
  gate never triggers (by design). Revisit once real deck content exists —
  maybe a per-deck `teaser_marker` (e.g. an HTML comment in the markdown).
- `rating`/`review_count` columns still exist on presentations but are unused
  (no review system). Either build reviews or drop the columns in a migration.
- Preview images section says "Slide N" over each image — number comes from
  position, fine, but consider lightbox viewing.

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

**State:** Index = char masthead + my societies + discover grid with honest
search (name/description + location ILIKE; the fake ZIP-radius UI and its
geolocation Stimulus controller are deleted). Show = unified char masthead
(banner-aware), membership-state actions, events + members panels.
**Privacy is now real:** SocietyPolicy#join? requires public?; policy scope
hides private societies from non-members; show? gates too.

**Gaps:**
- `SocietyApplication` model exists with zero routes/UI. Private societies
  currently say "Invite only" — but there's also no invite system! A private
  society's only members arrive via... nothing. THIS IS THE BIGGEST MISSING
  FEATURE: build either (a) invite links/codes, or (b) the application flow
  (apply → society admin approves in a pending-applications panel on the
  society page). The model + `pending_applications` method already exist.
- Society admins can't remove members or promote officers from the UI
  (SocietyMembership roles exist; `manage_members?` policy exists; no UI).
- The signed-out societies index variant (bottom half of index.html.erb) is
  long and partially redundant with the homepage; could be halved.
- Forums: `Forum` model + `has_many :forums` exist, completely unbuilt. Decide
  to build or drop.

## 7. Events

**State:** Nested under societies. Create/edit forms work; RSVP Yes/Maybe/No
with turbo_stream updates; event show has date/location/RSVP panels;
emoji stripped, display type on titles.

**Gaps:**
- events#index IS routed (nested: /societies/:id/events) — earlier draft of
  this note claimed otherwise. A cross-society "my events" page still doesn't
  exist and would be useful (all upcoming events for my societies).
- No calendar export (.ics) — small, high-value for a meetup product.
- No event reminders (needs a Solid Queue job + mailer; ActivityLog's
  `event_rsvp` type was never emitted anywhere either).
- Event image/banner not supported.

## 8. Account (/account)

**State:** Six JS tabs (Profile, Account Details, My Presentations,
My Societies, Subscription, Billing). Tab switcher now scrolls to the shown
panel, syncs the URL hash, and restores any tab from the hash on load.
Subscription tab: plan cards + pause/resume/cancel via SubscriptionsController
(Stripe-backed, tested). 2FA (TOTP + backup codes) in Account Details.

**Gaps:**
- The page is a 1000-line monolith with six panels inline. Split into
  partials (`account/_profile.html.erb` etc.) before touching anything else.
- My Presentations panel: big amber gradient placeholder block for decks
  without cover images — should reuse the char typographic cover from
  `_deck_card`; the whole panel should probably just use `_deck_card`.
- Billing history is read from Stripe invoices inline — slow with many
  invoices; consider caching or lazy Turbo frame.
- OTP secret (`otp_secret_key`) and backup codes are stored in PLAINTEXT
  columns. Encrypt with Rails `encrypts` (ActiveRecord encryption) — needs
  the encryption keys set up in credentials. Flagged since the first review;
  still open.

## 9. Auth (/auth)

**State:** Unified page: Google OAuth (button gated on real credentials —
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
- Consider passkeys eventually; magic link + OAuth covers the near term.

## 10. Admin panel

**State:** Char sidebar shell (layouts/admin.html.erb — note the fixed
sidebar + `ml-60` main; don't reintroduce flex-1 on main, it overflows the
viewport by the sidebar width). Sections: Dashboard, Decks, Users,
Subscriptions, Credits (+ ledger view), Activity, Analytics. All pages
verified rendering.

**Gaps (assessed, agreed direction, NOT yet implemented):**
- REMOVE `:credits` from Admin::UsersController#user_params — direct credit
  edits bypass the ledger. Credit changes only via Credits→adjust (which
  writes CreditTransaction rows).
- Tracking cleanup (see §12): stop emitting `presentation_viewed`; drop the
  ActivityLog download events (DownloadLog covers them); add
  subscription_paused/resumed to ACTIVITY_TYPES or stop emitting them
  (currently silently dropped by validation!); make login logging cover all
  three auth methods or none.
- No society/event moderation pages; no UI to grant/revoke `is_admin`.
- Dashboard "Recent Signups" panel has a stray blue button; icon colors are
  off-palette (blue/purple/yellow tints). Cosmetic.

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

177 runs green, 9 intentional Apple skips. Notable coverage: credit ledger
invariants, webhook idempotency, magic links, subscription pause/resume,
society privacy policy, pricing card DOM contract. Thin spots: purchase
controller states (free/credit/lapsed paths), downloads gating, teaser gate,
account tab behavior (JS — would need system tests; system test setup exists
but barely used).
