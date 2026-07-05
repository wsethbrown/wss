# WSS Overhaul Plan — Handoff Notes for Opus

> **Who wrote this:** The outgoing staff engineer (Fable). I did a full read-through review of the
> Whiskey Share Society (WSS) codebase but intentionally did **not** implement the changes — the
> owner has limited time on this model and wants *you* (Opus) to execute. This document is your
> work order. Read it top to bottom, then execute in the priority order given.
>
> **How to use this doc:** Work the phases in order. **Phase 0 and Phase 1 are non-negotiable and
> must ship before anything else** — they are live security holes. Everything after is the
> "refresh/refactor/overhaul." Check items off as you go. When you finish a phase, run the test
> suite and commit with a clear message.
>
> **Repo:** `~/Documents/Coding/wss` — Rails 8.0, Ruby 3.4.3, PostgreSQL, Hotwire (Turbo/Stimulus),
> Tailwind, Devise + Pundit, Stripe. Solid Queue/Cache/Cable configured. Kamal + Docker for deploy.

---

## ★ STATUS — overhaul complete (Fable + Opus)

All phases executed on branch **`overhaul/full-refresh`**, pushed to
`origin/overhaul/full-refresh` (github.com/wsethbrown/wss). Ready to merge to `main`.

**Final verified state (Docker, Ruby 3.4.3 + Postgres 15):**

| | failures | errors | skips | runs |
|---|---|---|---|---|
| `main` (baseline) | 59 | 55 | 0 | 173 |
| `overhaul/full-refresh` (final) | **0** | **0** | 9 | 177 |

The 9 skips are the Apple OmniAuth tests, intentionally gated until `APPLE_*` credentials are
configured. Brakeman: **0 security warnings**. To reproduce: `docker compose up -d db` then
`docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL="postgresql://wss:password@db:5432/wss_test" web bash -c "bin/rails db:test:prepare && bin/rails test"`.

**Completed beyond the original phases (second pass, verified in the browser end-to-end):**
- Google OAuth diagnosed (empty credentials in `.env`) and made honest: strategy registered per
  environment, button gated on real credentials, exact console setup steps in `.env.example`.
  **Owner action: paste real GOOGLE_CLIENT_ID/SECRET into `.env`, then `./wss restart`.**
- Deck content renders as an editorial reading experience (redcarpet + sanitized
  `render_markdown`, `.prose-deck` with drop cap, amber-thread reading progress).
- Full visual system shipped: char/paper two-surface identity, Fraunces / Instrument Sans /
  Source Serif 4, homepage rewritten (pinned how-it-works fixed), library rebuilt (JS-modal cards
  → real links with ownership badges), societies/events/account/auth reskinned.
- Purchase flow unified and audited state-by-state; free decks claimable without Stripe; credit
  spending consistently requires an active membership; **fixed a real access bug** (lapsed members
  could download credit-purchased files); Checkout offers all dashboard payment methods.
- All fabricated content removed (fake testimonials, reviews, member stats, money-back guarantee,
  reviewless star ratings, dead wishlist buttons, dead footer links, Unsplash hotlink).
- Admin panel: root cause of unusability was `stylesheet_link_tag :app` (nonexistent) — admin
  rendered with no CSS. Rebuilt as a char sidebar shell; added the missing credit-ledger view
  (was a 204). Every admin page verified rendering.
- Test suite fully reconciled: 177 runs, 0 failures, 0 errors.

**Remaining owner actions (not code):** real Stripe keys + price IDs in `.env` (current values are
placeholders — checkout cannot succeed until then), Google OAuth credentials, renewed Apple key
(revoke the leaked one), production deploy config.

**Third pass (visual carte blanche + audits):**
- **Society privacy hole fixed:** `SocietyPolicy#join?` ignored the privacy flag — anyone signed
  in could POST `/societies/:id/join` into a private society. Now public-only; private societies
  show an "Invite only" state (there is no application flow yet — `SocietyApplication` exists as a
  model but has no routes/UI; build it if self-serve requests are wanted).
- Society show page rebuilt: the two duplicated header variants (emoji icons, yellow/green one-off
  buttons, inline text-shadows) became one char masthead with banner-image support. Killed two
  live bugs there: "Apply to Join" linked to `#`, and the banner variant linked
  `new_user_session_path`, which doesn't exist (500 for signed-out visitors). Emoji stripped from
  event/society templates; full-bleed layout handling centralized in the application layout.
- **Dev CLI (`./wss`)**: rewritten for Docker Compose v2 — `wss up|start`, `down|stop`, `restart`,
  `logs`, `console`, `bash`, `test`, `db migrate|seed|reset|console`, `setup`, `clean`, `status`.

**Admin tracking review (assessment delivered to owner; implementation NOT yet done — candidate
next work):**
- `ActivityLog` is unreliable: 4 emitted event types (`presentation_downloaded`,
  `presentation_preview_downloaded`, `subscription_paused`, `subscription_resumed`) fail the
  model's type-list validation and are silently swallowed — never recorded. Login logging covers
  password only (not magic link / Google). IP + user agent are stored twice per row.
- `presentation_viewed` logs one row per authenticated page view (IP+UA) — already 56% of all
  activity rows; recommend cutting it (use a counter if popularity is ever wanted).
- Downloads are triple-tracked (ActivityLog broken, DownloadLog works, download_count column).
  Keep `DownloadLog` only.
- Recommendation on record: retire ActivityLog; every event worth keeping has a first-class home
  (CreditTransaction, UserPresentation, Stripe, DownloadLog, Devise trackable).
- Management gaps: admin user form permits direct `:credits` edits (bypasses the ledger — remove
  it; use Credits→adjust); no admin moderation for societies/events; no UI to grant/revoke
  `is_admin`.

**Done (see git log on the branch):**
- **Phase 0 (critical security) — COMPLETE.** Deleted the three auth-bypass controllers
  (`TestCallbackController`, `AppleAuthController`, `AppleDirectController`) and their routes; two of
  them signed every caller in as the hard-coded owner, one trusted an unverified Apple JWT. Untracked
  the committed `apple_private_key.pem` / dev certs / `*.log` and gitignored them. Stopped logging
  tokens/session/params. Deleted committed scratch scripts.
- **Phase 1 (authz) — MOSTLY DONE.** Unified admin onto the `is_admin` column (`User#admin?` no
  longer keys off email domain). *Still TODO:* audit Pundit coverage on account/subscriptions/admin,
  and harden paid-download URLs (expiring/proxied) — see Phase 4/§4.
- **Phase 2 (payments/credits) — MOSTLY DONE.** `credit_transactions` is now the single source of
  truth; `users.credits` is a self-healing cache (`credits == sum(ledger)`); all mutations go through
  `CreditTransaction.record!/use_credit` under a row lock; deleted every direct-write path. Added the
  `StripeEvent` dedup table so webhooks are idempotent. Removed the "simulated" free-purchase path.
  Enabled Apple Pay/Link via `automatic_payment_methods`. Stripe init fails loud in prod.
  *Still TODO:* move webhook processing to a Solid Queue job; replace the `obj.try(:x)||obj["x"]`
  soup with typed SDK access and verify `current_period_end` location for the pinned API version.
- **Phase 3 (auth consolidation) — MOSTLY DONE.** Magic links rewritten via
  `Auth::MagicLinkService` (single-use, expiring, HMAC-digested tokens on dedicated columns, no more
  password-reset collision, `deliver_later`). Apple reintroduced through `omniauth-apple` (real
  signature verification), gated on `APPLE_*` env vars. *Still TODO:* decide whether to restore the
  standard Devise session controller (sessions are still hand-rolled in `AuthController`).
- **Phase 4 (hygiene) — PARTIAL.** Added `.env.example`; removed scratch files and a stray `.backup`
  view. *Still TODO:* consolidate the three Dockerfiles, prune/update the stale `*.md` docs
  (Architecture.md, Database.md, Backlog.md, admin_panel_todo.md, AuthenticationFix.md), refresh
  README/CLAUDE.md.
- **Phase 7 (frontend) — FOUNDATION DONE.** Built a real design system in the (previously empty)
  Tailwind source: one warm **whiskey** palette (50–950), an editorial serif token for narrative
  headings, reusable `.btn/.card/.badge` components. Unified the accent app-wide by swapping ~370
  `indigo-*` utilities across 20 views to shade-matched `whiskey-*`. *Still TODO (the big visual
  work):* the premium narrative **deck viewer**, marketplace browse/filter polish, a11y pass, mobile.
- **Phase 8 (tests/CI) — PARTIAL.** Added tests for the credit ledger invariant, `StripeEvent`
  idempotency, and the magic-link service; rewrote/aligned the auth tests. Added a `test` job (with
  Postgres) and a `bundle-audit` step to CI. *Still TODO:* broaden Pundit/policy and subscription
  lifecycle coverage.

**Not started (need owner sign-off before building):**
- **Phase 5 (deeper backend refactor)** — extract the remaining Stripe orchestration into service
  objects; finish the presentation structured-content migration; promote string statuses to enums.
- **Phase 6 (the product's soul)** — model the monthly rotating-presenter ritual and narrative deck,
  tying societies to the marketplace. Additive product design; confirm scope first.

Everything below is the original plan, kept intact as the deeper spec. Trust the STATUS block above
for what's already merged.

---

## 0. The 30-second orientation

WSS is a **subscription marketplace for whiskey slide decks**, plus **societies** (public/private
groups) with **events + RSVPs**. Founding story that the product has drifted away from: a group of
friends took monthly turns being assigned a whiskey topic, researching it, and presenting a
**narrative** slide deck with a chosen whiskey — a thread connecting the pour to a story. That
"monthly rotating presenter / narrative deck" soul is **not modeled anywhere in the code today**;
it's just a flat catalog. See Phase 6.

**Business rules that must stay true (from CLAUDE.md, verified against code):**
- Subscribers get **1 credit/month** (on subscribe, then monthly renewal).
- A deck can be bought **à la carte (direct)** → owned forever, or **with a credit** → accessible
  only while the subscription is active.
- Users can hold a mix of both.

---

## 1. TOP-PRIORITY FINDINGS (the "why this review mattered")

These are the things I'd stop the presses for. Details and fixes are in the phases below; this is
the executive summary so you know the stakes before you touch anything.

| # | Severity | Finding | Where |
|---|----------|---------|-------|
| 1 | 🔴 **CRITICAL — full account takeover** | `TestCallbackController#callback` signs the request in as a **hard-coded user** (`wsethbrown@gmail.com`, the owner) whenever `params[:code]` or `params[:id_token]` is present. It's wired to public routes `/callback`, `/auth/callback`, `/users/callback`. Anyone can `GET /callback?code=x` and become the owner. | `app/controllers/test_callback_controller.rb`, `config/routes.rb:7-9` |
| 2 | 🔴 **CRITICAL — auth bypass / impersonate anyone** | `AppleAuthController` decodes the Apple ID token with `JWT.decode(token, nil, false)` — **signature verification disabled** — and trusts `params[:user]`'s email. A forged `id_token` with any `email` claim signs you in as that user. | `app/controllers/apple_auth_controller.rb:94`, `:83-105` |
| 3 | 🔴 **CRITICAL — committed private key** | `apple_private_key.pem` (Apple Sign-In signing key), `dev-cert.pem`, `dev-key.pem` are **tracked in git**. The Apple key must be rotated in the Apple Developer console and purged from history. | repo root, `git ls-files` |
| 4 | 🔴 **HIGH — prod crash** | `apple_auth_controller` calls `JWT` but the `jwt` gem is in the `:development, :test` bundle group only. In production this is a `NameError`. (Mostly moot once you delete the controller — see #2.) | `Gemfile:57`, `apple_auth_controller.rb:94` |
| 5 | 🟠 **HIGH — credit balance corruption** | The `users.credits` integer is a denormalized cache mutated from **two independent code paths** with no single source of truth: `CreditTransaction after_create` does `increment!`, while `User#add_credits/#deduct_credits` write the column directly. Balances will drift. | `app/models/credit_transaction.rb:25,76-78`, `app/models/user.rb:370-381` |
| 6 | 🟠 **HIGH — non-idempotent Stripe webhooks** | No dedup on Stripe event IDs. Stripe retries deliver duplicates → duplicate monthly credits. `grant_monthly_credit` fires on **both** `customer.subscription.created` and `invoice.payment_succeeded`(cycle); the first invoice can double-grant the welcome credit. | `app/controllers/webhooks_controller.rb:8-30,68,166` |
| 7 | 🟠 **HIGH — two conflicting "admin" concepts** | `User#admin?` = email ends with `@whiskeysharesociety.com`; `User#is_admin?` = the `is_admin` boolean column. Different gates use different ones (`Presentation#can_download_full_presentation?` uses email-based `admin?`; the admin panel uses column-based `is_admin?`). Pick one. | `app/models/user.rb:114-117,321-323`, `presentation.rb:82` |
| 8 | 🟠 **MED — secrets/PII in logs, logs in git** | `handle_csrf_error` and `magic_links#show` log full session, CSRF tokens, params, and reset tokens. Four `*.log` files are committed to git. | `application_controller.rb:48-58`, `magic_links_controller.rb:44-121` |
| 9 | 🟡 **MED — magic link reuses password-reset token** | Existing-user magic links overwrite `reset_password_token`/`reset_password_sent_at`, colliding with Devise's real password-reset feature. Clicking a reset link and a magic link interfere. | `magic_links_controller.rb:30-36,97-115` |
| 10 | 🟡 **MED — redundant/duplicate Apple flows + dead scaffolding** | Three overlapping Apple paths (`apple_auth`, `apple_direct`, `test_callback`) plus OmniAuth. Root is littered with committed scratch scripts (`fix_auth_now.rb`, `test_auth.rb`, `create_test_link.rb`, etc.). | routes + repo root |

---

## 2. STRATEGY / SEQUENCING (read before executing)

My reasoning for the order, so you don't reorder it and regret it:

1. **Stop the bleeding first (Phase 0/1).** The auth bypasses and committed key are exploitable
   *right now*. Nothing else matters until they're closed. These are also **low-risk deletions** —
   you're removing insecure code, not adding features, so they can ship immediately.
2. **Make money-handling correct (Phase 2).** Credits and Stripe webhooks are where real dollars and
   real trust live. Idempotency + a single source of truth for credits before you build anything on
   top of them.
3. **Consolidate auth to one blessed path (Phase 3).** Once the dangerous controllers are gone, the
   remaining OmniAuth + magic-link + password flows need to be unified and covered by tests.
4. **Repo hygiene + config (Phase 4).** Cheap, high-signal cleanup that makes the rest safe to work in.
5. **Backend refactor (Phase 5).** Service objects, kill the `try()||[]` Stripe soup, fix N+1s.
6. **Product/domain: bring back the soul (Phase 6).** Model the monthly rotation + narrative deck.
7. **Frontend refresh (Phase 7).** Design system pass, accessibility, the marketplace + deck viewer.
8. **Test + CI + deploy (Phase 8).**

**Guardrail:** WSS handles payments and PII. After every phase, run `bin/rails test` and
`bundle exec brakeman`. Don't let a "refactor" silently drop an authorization check.

---

## 3. PHASE 0 — Emergency security patches (ship today, tiny diffs)

- [ ] **Delete `TestCallbackController` entirely.** Remove the file and the routes at
  `config/routes.rb:7-9` (`/callback`, `/auth/callback`, `/users/callback`). This is the worst hole.
- [ ] **Delete `AppleAuthController` and `AppleDirectController`.** Remove their routes
  (`config/routes.rb:1-5,13-14,22-31` Apple bits). Apple Sign-In will be reintroduced *properly*
  via OmniAuth in Phase 3. If Apple login must keep working in the interim, gate it behind a feature
  flag rather than the insecure hand-rolled JWT path — **never** ship `JWT.decode(_, nil, false)`.
- [ ] **Rotate the Apple private key** in the Apple Developer portal (Keys → revoke the leaked key,
  create a new one). Move the new key into Rails encrypted credentials or an env var — never a file
  in the repo.
- [ ] **Purge secrets from git + history:** `git rm --cached apple_private_key.pem dev-cert.pem
  dev-key.pem rails*.log server.log`, add them to `.gitignore` (add `*.pem` and `*.log`), commit,
  then scrub history with `git filter-repo` (or BFG) and force-push. Treat every committed secret as
  compromised and rotate it.
- [ ] **Stop logging secrets:** delete the token/session/param dumps in
  `application_controller.rb#handle_csrf_error` and throughout `magic_links_controller`. Never log
  `reset_password_token`, `authenticity_token`, or full `session`.

**Acceptance:** `git ls-files | grep -E '\.(pem|log)$'` returns nothing; `grep -rn "JWT.decode"
app/` returns nothing; hitting `/callback?code=x` 404s.

---

## 4. PHASE 1 — Lock down authorization consistency

- [ ] **Unify admin identity.** Standardize on the `is_admin` **boolean column** as the single admin
  gate. Delete the email-suffix `User#admin?` (`user.rb:114-117`) or make it an alias of `is_admin?`.
  Fix every caller — critically `Presentation#can_download_full_presentation?` (`presentation.rb:82`)
  which currently grants downloads via the email-based check.
- [ ] **Remove the redundant `is_admin?` override** (`user.rb:321-323`) — Rails already generates it
  for the boolean column.
- [ ] **Audit Pundit coverage.** Controllers using `authorize`/`policy_scope`: societies, events,
  presentations, event_rsvps. **Missing/should verify:** `account`, `subscriptions`, `admin/*`
  (admin uses a hand-rolled `authenticate_admin!` — fine, but confirm every admin action checks it),
  `presentations/downloads`, `presentations/purchases`. Add `after_action :verify_authorized` where
  appropriate.
- [ ] **Download authorization:** `Presentations::DownloadsController` redirects to the blob URL
  (`rails_blob_url`) for paid content. Rails blob URLs are effectively public/guessable-signed and
  live "forever." For paid decks, serve through a controller with `authenticate_user!` +
  ownership check and short-lived, expiring signed URLs (or proxy the download). Don't hand a
  permanent public URL to paid PDFs.

---

## 5. PHASE 2 — Payments & credits correctness

### 5.1 Credits: one source of truth
- [ ] Decide the model. Recommended: **`credit_transactions` is the ledger; `users.credits` is a
  cached balance updated only by the ledger's `after_create`.** Then **delete `User#add_credits` and
  `#deduct_credits`** (`user.rb:370-381`) and route *all* mutations through `CreditTransaction`.
  Anywhere that calls `add_credits`/`deduct_credits` (check `admin/credits_controller.rb`) must
  create a transaction instead.
- [ ] Wrap balance mutation and transaction creation in a DB transaction with row locking
  (`user.with_lock`) to prevent races on concurrent grants/spends.
- [ ] Add a reconciliation task/spec: `users.credits == credit_transactions.sum(:amount)` for every
  user. Add it to the test suite so drift is caught.
- [ ] `CreditTransaction.use_credit` checks `user.credits > 0` outside a lock — move the check inside
  the locked transaction to prevent double-spend.

### 5.2 Stripe webhooks: idempotency + robustness
- [ ] **Add an event ledger.** Create a `stripe_events` table (`event_id` unique). At the top of
  `WebhooksController#stripe`, `find_or_create` by `event.id`; if already processed, return 200
  immediately. This kills duplicate-credit bugs from Stripe retries.
- [ ] **Fix the double welcome-credit.** Grant the welcome credit in exactly one place. Recommended:
  grant only on `invoice.payment_succeeded` with `billing_reason in ['subscription_create',
  'subscription_cycle']`, and stop granting in `customer.subscription.created`. Verify against
  Stripe's current invoice `billing_reason` values.
- [ ] **Kill the `obj.try(:x) || obj["x"]` soup** (all over `webhooks_controller.rb`). It's a symptom
  of fighting the SDK version. Pin the Stripe API version, use typed accessors, and note that in
  recent Stripe API versions `current_period_end` moved from the subscription to the subscription
  **item** — verify which your `Stripe.api_version = '2024-06-20'` (`config/initializers/stripe.rb`)
  actually returns and read it correctly. This is fragile today.
- [ ] **Move webhook processing to a background job** (Solid Queue is already configured). Verify the
  signature in the controller, enqueue, return 200 fast. Long webhook handlers that call back into
  Stripe (`Stripe::Subscription.retrieve`, `PaymentIntent.retrieve`) risk timeouts + retries.
- [ ] **Guard the whole handler in a rescue that still returns 2xx for unprocessable-but-valid
  events**, but 5xx for transient failures so Stripe retries. Current blanket `rescue => e; render
  500` will make Stripe retry *everything* including permanent failures.

### 5.3 Payment method expansion (the owner asked for Apple Pay / Shop / Link)
- [ ] You do **not** need separate integrations. In Stripe Checkout / Payment Element, enable
  `automatic_payment_methods: { enabled: true }` and turn on Apple Pay, Link, Cash App, etc. in the
  Stripe Dashboard. Apple Pay needs domain verification (host the association file). Document this in
  the README. Keep card + wallets flowing through the one Stripe Checkout session you already build
  in `Presentations::PurchasesController` and `SubscriptionsController`.

---

## 6. PHASE 3 — Authentication consolidation

Goal: exactly **three** blessed auth methods, all tested — (1) email + password (Devise),
(2) magic link, (3) OAuth via OmniAuth (Google now; Apple reintroduced *correctly*).

- [ ] **Magic links:** stop hijacking `reset_password_token`. Add a dedicated
  `magic_link_token` + `magic_link_sent_at` (or a small `MagicLink` model / signed `GlobalID` with
  `expires_in`). New-user and existing-user flows should share one code path that creates-or-finds
  the user, then signs in. Remove the blank `first_name: ''`/`last_name: ''` account creation smell.
- [ ] **Deliver magic-link + all transactional mail with `deliver_later`** (Solid Queue), not
  `deliver_now` in the request.
- [ ] **Apple Sign-In (proper):** reintroduce via `omniauth-apple` (already in Gemfile) through the
  standard Devise `omniauth_callbacks` controller, with real JWT signature verification handled by
  the gem. Store the signing key in credentials/env.
- [ ] **`User.from_omniauth`** (`user.rb:9-55`): the "email already tied to another provider" branch
  returns an unsaved `User.new` with errors — callers must handle that (verify
  `Users::OmniauthCallbacksController`). Add account-linking UX instead of a hard reject if desired.
- [ ] Delete the leftover custom session routes hackery in `routes.rb:28-31` if the standard Devise
  session controller can be restored (sessions are currently `skip`ped and hand-rolled in
  `AuthController`). Confirm why sessions were skipped before removing.

---

## 7. PHASE 4 — Repo hygiene & configuration

- [ ] **Delete committed scratch scripts:** `create_test_link.rb`, `fix_auth_now.rb`, `test_auth.rb`,
  `test_magic_link.rb`, `test_tab_functionality.rb`, `watch_emails.rb`. If any are genuinely useful,
  move them to `lib/tasks/` as rake tasks or `bin/`.
- [ ] **Consolidate Dockerfiles.** There are `Dockerfile`, `Dockerfile.dev`, `Dockerfile.prod`,
  `docker-compose.yml`. Keep the Rails 8 default multi-stage `Dockerfile` + one compose for local.
  Remove the rest or document exactly what each is for.
- [ ] **Prune stale docs.** `AuthenticationFix.md`, `admin_panel_todo.md`, `Backlog.md`,
  `Architecture.md`, `Database.md`, `SecurityChecklist.md` describe aspirational/edge states that no
  longer match the code (e.g. Architecture.md claims service objects that don't exist). Either update
  them to reality or delete. Fold anything load-bearing into `CLAUDE.md`. **This `OVERHAUL_PLAN.md`
  should become the source of truth until the work is done.**
- [ ] **`.gitignore`:** add `*.pem`, `*.log` (beyond `/log/*`), and confirm `config/master.key` stays
  ignored. Provide a committed **`.env.example`** (no real values) — there is none today.
- [ ] **Stripe init:** `config/initializers/stripe.rb` falls back to `'sk_test_...'` placeholder
  strings. In production, fail loudly if `STRIPE_SECRET_KEY` is missing rather than silently using a
  bad key. `verify_ssl_certs = false` in dev is acceptable but comment why.
- [ ] **`allow_browser versions: :modern`** (`application_controller.rb:3`) can hard-block real
  visitors. Confirm this is intended for a consumer marketplace; consider relaxing.

---

## 8. PHASE 5 — Backend refactor

- [ ] **Extract service objects** (Architecture.md already imagined these — make them real):
  `Subscriptions::CheckoutService`, `Subscriptions::WebhookProcessor`, `Credits::Ledger`,
  `Presentations::PurchaseService`, `Auth::MagicLinkService`. The fat controllers
  (`subscriptions_controller.rb` 357 lines, `account_controller.rb` 445, `admin/subscriptions` 333)
  are doing Stripe orchestration inline.
- [ ] **N+1 / performance:** `SocietiesController#index` already uses `includes` — good; audit
  presentations index, events, and admin dashboards similarly. Add `bullet` in dev to catch N+1s.
- [ ] **Presentation content model:** the deck's teaching content is stored as freeform text parsed
  by hand-rolled parsers (`parsed_what_youll_learn`, `parsed_slides_preview`, pipe-delimited
  `whiskey_recommendations`) with a half-migrated `whiskey_recommendations_json`. Finish the
  migration to structured JSON columns (or associated tables) and delete the legacy text parsers.
- [ ] **Consistent enums:** membership `role`/`status` and subscription `status` are string columns
  compared with string literals everywhere. Promote to Rails enums for safety and query clarity.
- [ ] **Money:** `presentation.price` math (`* 100` to cents) is done ad hoc. Consider storing cents
  as integers or using a money gem to avoid float rounding.

---

## 9. PHASE 6 — Restore the product's soul (the founding concept)

Today the app is a flat deck catalog. The original WSS ritual isn't modeled. This is the highest-
leverage *product* work and what will make the refresh feel like more than a coat of paint.

- [ ] **Model the monthly rotation.** New concepts (scoped to a Society): `Topic` (the assigned
  whiskey subject for a month), `Assignment`/`Rotation` (which member presents which month), and a
  link from a `Presentation` to the `Topic` it fulfilled. A society has a schedule; one member is
  "on deck" each month.
- [ ] **Make decks narrative-first.** The content schema should encourage a *thread* — an ordered
  sequence of slides that connect the whiskey to a story — not a fact sheet. Reflect this in the
  authoring UI (Phase 7) and the viewer: intro → the thread → the pour → tasting → payoff.
- [ ] **Tie the marketplace to the ritual.** Decks that came out of real monthly sessions are the
  premium catalog; the subscription/credit system gates access to them. This connects the two halves
  of the app (societies ↔ marketplace) that are currently siloed.
- [ ] Events already exist and RSVP works — connect an event to a `Topic`/monthly session so an RSVP
  is "I'm coming to this month's tasting," closing the loop.

*(Confirm scope with the owner before building — this is additive product design, not a bug fix.)*

---

## 10. PHASE 7 — Frontend refresh

Stack: Hotwire (Turbo + Stimulus), Tailwind, importmap, "glassmorphism" theme. 83 ERB templates
(~10.8k lines). Stimulus controllers exist for search, purchase buttons, crop, flash, recommendations.

- [ ] **Establish a real design system.** Right now styling is inline Tailwind per-view with a
  glassmorphism motif. Extract a small set of components/partials (buttons, cards, modals, form
  fields, deck tiles) and shared Tailwind `@layer components`. Aim for an intentional whiskey-brand
  aesthetic (warm ambers, editorial serif for narrative, generous whitespace) rather than the
  default-SaaS gradient look. *(Consider invoking the `frontend-design` skill for direction.)*
- [ ] **The deck viewer is the hero surface.** Build a first-class narrative reader: slide-by-slide
  progression, the whiskey pairing panel, tasting notes, speaker notes for owners. This is what a
  subscriber pays for — it should feel premium.
- [ ] **Marketplace browse/filter:** real-time search already exists (`society_search_controller`,
  presentation filtering). Polish into a proper catalog with categories, difficulty, region facets.
- [ ] **Accessibility pass:** semantic landmarks, focus states, keyboard nav, color contrast on the
  glass/gradient backgrounds (contrast is the usual casualty of glassmorphism), tap-target sizes.
  Use the `chrome-devtools-mcp:a11y-debugging` skill.
- [ ] **Responsive/mobile:** verify the marketplace, deck viewer, and checkout on mobile widths.
- [ ] **Checkout UX:** surface Apple Pay / Link / wallet buttons (Phase 2.3) prominently.

---

## 11. PHASE 8 — Testing, CI, deploy

- [ ] **Grow the suite.** ~21 test files exist but the CLAUDE.md claims TDD and features clearly
  shipped untested (auth, webhooks). Priority coverage: webhook idempotency + credit granting,
  credit ledger reconciliation, purchase (credit vs direct) access rules, magic-link happy/expiry
  paths, Pundit policies for every controller, subscription lifecycle (create/cancel/pause/resume).
- [ ] **Security scanning in CI:** wire `brakeman` and `bundle audit` into `.github/workflows`.
  Re-run Brakeman after Phase 0 — the deleted controllers were almost certainly flagged.
- [ ] **Confirm the app boots + migrates clean** on a fresh DB (`bin/rails db:setup`) before deploy.
- [ ] **Kamal/Docker deploy:** validate secrets come from env/credentials, `force_ssl` is on
  (`config/environments/production.rb:31` — it is), and no dev-only Stripe SSL bypass leaks to prod.

---

## 12. Quick reference — file → concern map

| Area | Files |
|------|-------|
| **Auth (delete)** | `test_callback_controller.rb`, `apple_auth_controller.rb`, `apple_direct_controller.rb` |
| **Auth (keep/fix)** | `auth_controller.rb`, `magic_links_controller.rb`, `users/omniauth_callbacks_controller.rb`, `users/registrations_controller.rb`, `config/initializers/devise.rb` |
| **Payments** | `subscriptions_controller.rb`, `webhooks_controller.rb`, `presentations/purchases_controller.rb`, `config/initializers/stripe.rb`, `home_controller.rb` (Stripe product fetch) |
| **Credits** | `credit_transaction.rb`, `user.rb` (credit methods), `admin/credits_controller.rb` |
| **Core domain** | `user.rb` (481 lines — split it up), `society.rb`, `presentation.rb`, `event.rb`, `event_rsvp.rb`, `society_membership.rb`, `society_application.rb` |
| **Admin** | `app/controllers/admin/*` (base, dashboard, users, subscriptions, credits, presentations, analytics, activities) |
| **Authz** | `app/policies/*` (society, event, event_rsvp, presentation — no policies for account/subscription/admin) |
| **Frontend** | `app/views/**` (83 erb), `app/javascript/controllers/*`, Tailwind config, `layouts/application.html.erb` + `layouts/admin.html.erb` |
| **Scratch (delete)** | root `*.rb` scripts, root `*.log`, `*.pem`, extra Dockerfiles, stale `*.md` |

---

## 13. Definition of done

1. No auth bypass; `/callback` gone; no `JWT.decode(_, nil, false)`; no secrets in the repo or its
   history; leaked Apple key rotated.
2. Credits provably equal the sum of their ledger for every user; webhooks idempotent; no
   double-granting.
3. One admin concept, one blessed set of auth flows, all covered by tests.
4. Brakeman + `bundle audit` clean in CI; `bin/rails test` green on a fresh DB.
5. The marketplace + deck viewer feel intentional and premium; checkout offers wallets; mobile + a11y pass.
6. (Stretch, confirm with owner) the monthly-rotation / narrative-deck concept is modeled and ties
   societies to the marketplace.

— Handoff complete. Good luck; make it something the founders would be proud to pour to.
