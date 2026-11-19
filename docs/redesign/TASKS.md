# Task list — site redesign and backend fixes

Read `ORCHESTRATION.md` first (roles, waves, gates, definition of done, environment).
Design rules: `DESIGN_SYSTEM.md`. Backend evidence: `ARCHITECTURE_REVIEW.md`
(finding ids like **M2**, **S4**, **I7** refer to it).

Status key: `[ ]` open · `[~]` in progress · `[x]` done · `[!]` blocked (say why).
The orchestrator updates the boxes and adds a one-line result under each task.

Already done by the advisor (do not redo): design tokens and components in
`app/assets/tailwind/application.css`, the floating nav and rounded footer in
`layouts/application.html.erb`, the homepage, `DESIGN_SYSTEM.md`.

---

# Track D — design

Every D task also has these acceptance criteria, in addition to its own:
- **A.** Follows `DESIGN_SYSTEM.md`: paper ground, `.card` surfaces, no `bg-char`
  masthead, sentence case, no small-caps labels, no emoji icons, no off-palette colours.
- **B.** At 1440px and 390px there is no horizontal scroll and nothing overlaps the nav.
- **C.** Every link, form, button, Turbo frame/stream target and Stimulus hook that
  existed still exists and works; element ids and `data-*` hooks are unchanged.
- **D.** No authorisation or data change: the same people see the same records.
- **E.** Copy is reused; anything new is listed in the hand-back.

And this test plan, in addition to its own:
- Run the task's listed test files; fix tests that asserted old styling by asserting
  behaviour or content instead (never delete an assertion that guards behaviour).
- Screenshot each owned page at both widths, signed out and signed in where it differs,
  and report `scrollWidth`.

## Wave D0 — shared pieces (run alone, before everything else)

### [x] D0 · Shared partials and helpers — `sonnet`
Result: page header partial, `deck_cover`/`avatar` helpers with tests, new deck card, flash and five error pages restyled. Homepage `<style>` left inline (ERB-computed keyframes). Error-page copy awaiting owner approval.
**Goal:** the building blocks other tasks reuse, so pages do not each invent them.
**Owns:** `app/views/shared/*`, `app/views/presentations/_deck_card.html.erb`,
`app/helpers/application_helper.rb`, `app/helpers/design_helper.rb` (new),
`public/404.html`, `public/422.html`, `public/500.html`,
`public/406-unsupported-browser.html`, `test/helpers/design_helper_test.rb` (new).
May **append** component classes to `app/assets/tailwind/application.css`.
**Do:**
1. `shared/_page_header.html.erb`: locals `title` (may contain one `<em>`), `lede`
   (optional), block or `actions` local for the page's main action, optional `back`
   link. Sits on paper, left-aligned, `pt-28` to clear the nav.
2. `DesignHelper#deck_cover(deck, **opts)`: first slide image, else `featured_image`,
   else a plain `bg-char` block; always 16:9, 18px radius, hairline. One query per deck
   at most; accept a preloaded attachment.
3. `DesignHelper#avatar(user, size:)`: profile image, else initials on
   `bg-whiskey-100 text-ink`. Do not use `avatar_color`.
4. Redesign `_deck_card` on top of `deck_cover`: cover, title, one line of meta
   (category · level · duration), price or "In your library". A `.card-hover`, the whole
   card one link. Keep its locals (`deck`, `owned`) and the "Featured" marker.
5. Restyle `shared/_flash_messages` (keep the `#flash-messages` target and `toast-in`),
   and the four static error pages (inline CSS only; paper ground, green heading, one
   link home).
6. Move the homepage's inline `<style>` block from `app/views/home/index.html.erb` into
   `application.css` unchanged under a `/* Homepage */` comment **only if** the two
   ERB-computed keyframe timings can stay inline; otherwise leave it and say so.
**Don't:** change `_membership_pricing` (D6 owns it); touch the nav or footer.
**Acceptance:** A–E, plus: `deck_cover` and `avatar` have unit tests for each fallback;
the library and homepage still render with the new card; error pages render standalone
with no external requests.
**Tests:** `bin/rails test test/helpers test/integration/featured_decks_test.rb test/controllers/presentations_controller_test.rb`.

## Wave D1 — public pages (parallel; disjoint files)

### [ ] D1 · Library and deck page — `opus`
**Owns:** `app/views/presentations/index.html.erb`, `show.html.erb`, `_pour_card.html.erb`,
`purchases/*`, `app/javascript/controllers/` files used only by these views.
Delete `presentations/show_next.html.erb` and its `maybe_render_next` call if the new
`show` supersedes it (say so in the hand-back).
**Do:** Library: `_page_header`, a filter row of chips/selects on paper, the deck grid
using `_deck_card`, the tag row, pagination. Deck page: a two-act page per the old brief —
*sell* (cover from real slides, title, meta, the purchase action bar, the story teaser, the
first slides, tasting notes, reviews) and *own* (Present button, full story, downloads).
The sidebar price card becomes one action bar under the header. Purchase page: one card.
**Don't:** change the teaser gate (`preview_markdown`, `@full_story`), the preview slide
count, download gating, purchase states, or `present.html.erb`. Read
`.claude/skills/wss-deck-pipeline` and `wss-payments-credits` first.
**Acceptance:** A–E, plus: a signed-out visitor, a member with a credit, a lapsed member,
a direct owner and an admin each see the same actions and content as before (list the
five states with a screenshot each); hidden story content is still absent from the DOM
for non-owners; the downloads box still renders only when files exist.
**Tests:** `test/controllers/presentations_controller_test.rb`,
`test/controllers/presentations/*`, `test/integration/*deck*`, `test/integration/*purchase*`.

### [ ] D2 · Societies index — `opus`
**Owns:** `app/views/societies/index.html.erb`, society card partials it uses.
**Do:** Replace the signed-out landing page. It is the old design and makes claims the
product does not deliver ("VIP distillery visits", "Guest speakers & experts", "Smart
RSVP System"). New signed-out page: `_page_header`, real public societies as a ruled list
or cards with real member and event counts, one `.panel-ink` explaining what a society is
using sentences that already exist on the homepage or `/membership`, and the join action.
Signed-in page: "your societies" and "discover" in the same language, search kept.
**Acceptance:** A–E, plus: none of the removed claims remain anywhere in `app/views`
(`grep`); every number shown is computed from the database; the one 🥃 empty-state
glyph is replaced by a sentence.
**Tests:** `test/controllers/societies_controller_test.rb`, `test/integration/*societ*`.

### [ ] D3 · Society pages — `sonnet`
**Owns:** `app/views/societies/show.html.erb`, `activity.html.erb`, `new.html.erb`,
`edit.html.erb`, `invite.html.erb`, `app/views/invitations/*`, `society_memberships` and
`society_invitations` views if any.
**Do:** Show: header on paper with name, place, counts and the member actions; the next
event as the page's one `.panel-ink`; events, members (using `avatar`), the review board
and invite tools as cards with ruled rows. Forms: one card each.
**Don't:** change privacy behaviour — read `.claude/skills/wss-societies` first.
**Acceptance:** A–E, plus: a non-member of a private society still sees only the
invite-only state; admin/officer tools appear only for those roles (screenshot member vs
officer vs admin).
**Tests:** `test/controllers/societies_controller_test.rb`, `test/policies/society_policy_test.rb`,
`test/integration/*invit*`.

### [ ] D4 · Events — `opus`
**Owns:** `app/views/events/*`, `app/views/event_rsvps/*`, the RSVP control rules at the
bottom of `application.css` (`.rsvp-*`).
**Do:** Event page on paper: header (date, title, place, host), the RSVP control, then
cards for details, pours, deck, table talk, attending. Remove the "Event Stats" card's
internal rows (status, created date); keep the going/maybe/no counts next to the RSVP
control. The RSVP segmented control currently assumes a dark ground (`.rsvp-option`
colours): re-colour it for a white card while keeping the sliding indicator, the
`aria-pressed` state model and the Stimulus `segmented` controller untouched.
**Don't:** let any Turbo stream re-render the control (see the long comment in
`application.css`); change the secret-pour or provenance-veiling behaviour.
**Acceptance:** A–E, plus: answering Yes/Maybe/No still slides the indicator and updates
counts without a page load (record a before/after pair); RSVP colours still meet 4.5:1;
host-only and admin-only controls are unchanged.
**Tests:** `test/controllers/events_controller_test.rb`, `test/controllers/event_rsvps_controller_test.rb`,
`test/system/*` if they touch events, `test/integration/*rsvp*`, `test/integration/*event*`.

### [ ] D5 · Reviews, bottles, profiles — `sonnet`
**Owns:** `app/views/reviews/*`, `app/views/bottles/*`, `app/views/profiles/*`,
`app/views/favorites/*`, `app/views/review_votes/*`.
**Do:** Tasting record index: `_page_header`, search and sort on paper, bottles as a ruled
list in a card with the score right-aligned (`tabular-nums`, stars in `text-mark`), the
feed tabs as chips. Review and bottle pages: header on paper, the bottle tile, cards for
notes and the review list. Profile: header with `avatar`, shelf and reviews as cards.
Fix the 511px overflow at 390px on the reviews index.
**Don't:** change veiling, search modes, vote or favourite behaviour (`wss-reviews`,
`wss-community` skills).
**Acceptance:** A–E, plus: reviews index `scrollWidth` is 390 at 390px; vote and
favourite buttons still update in place.
**Tests:** `test/controllers/reviews_controller_test.rb`, `test/controllers/bottles_controller_test.rb`,
`test/controllers/review_votes_controller_test.rb`, `test/controllers/favorites_controller_test.rb`.

### [ ] D6 · Membership, auth, contact — `sonnet`
**Owns:** `app/views/home/membership.html.erb`, `home/contact.html.erb`,
`app/views/shared/_membership_pricing.html.erb` (take it over from D0's "don't"),
`app/views/subscriptions/*`, `app/views/auth/*`, `app/views/devise/**`,
`test/integration/home_subscription_cards_test.rb`.
**Do:** Membership: `_page_header`; three plan cards on paper (the popular one is the
single `.panel-ink`), prices and savings from `@stripe_products` exactly as now; the
founding-member offer as a card with its real remaining count; the free-vs-member
comparison as two ruled lists. No navy buttons, no "Best value" ribbon — mark the popular
plan with its fill only if the existing label can go; otherwise keep the label as a chip.
Auth: one centred card, the Google button, magic link, password toggle — ids unchanged.
Remove the developer hint about `GOOGLE_CLIENT_ID` from what visitors can see when
Google is not configured (render nothing instead).
**Don't:** change plan ids, form actions, Stripe params, or the benefit copy (its source
of truth is `Membership::BENEFITS`; see `wss-membership-model`).
**Acceptance:** A–E, plus: the rewritten tests assert plans, prices, savings, the
free-vs-member split and three sign-up actions by content and structure, not by Tailwind
class names; `#magic-link-email`, `#password-toggle`, `#signin-email`,
`#signin-password` still exist and sign-in works for both seeded users.
**Tests:** `test/integration/home_subscription_cards_test.rb`, `test/controllers/home_controller_test.rb`,
`test/controllers/subscriptions_controller_test.rb`, `test/system/magic_links_test.rb`,
`test/integration/*auth*`.

### [ ] D7 · Account and notifications — `sonnet`
**Owns:** `app/views/account/*`, `app/views/notifications/*`,
`test/system/account_navigation_test.rb`.
**Do:** Account: section navigation as a row of chips on phones and a left column on
desktop; each panel a card. **Fix the phone layout**: the page is 1152px wide in a 390px
viewport today. Notifications: a ruled list in a card, unread marked with a `bg-mark` dot.
**Acceptance:** A–E, plus: `scrollWidth` is 390 on every account panel at 390px; each
panel is reachable by its existing URL/param; billing and subscription actions are
unchanged.
**Tests:** `test/controllers/account_controller_test.rb`, `test/system/account_navigation_test.rb`.

## Wave D2 — admin (D8 alone, then D9a and D9b in parallel)

### [ ] D8 · Admin shell and patterns — `opus`
**Owns:** `app/views/layouts/admin.html.erb`, `app/views/admin/dashboard/*`,
`app/views/admin/shared/*` (new), `app/helpers/admin_helper.rb`.
**Do:** Keep the fixed 240px sidebar (`main.ml-60.min-w-0`), restyled: green, the sans
wordmark, grouped links, the current section marked. Add a phone layout (sidebar becomes
a top bar with a menu) — the admin is unusable on a phone today. Define and document, as
partials in `admin/shared`, the patterns every admin page uses: page header with primary
action, filter bar, data table (hairline rows, sticky header, right-aligned numbers,
row actions), detail panel (definition rows), form card, status chip, empty state,
confirmation for destructive actions. Rebuild the dashboard with them.
Admin status chips may use three semantic tones (ok / attention / problem) built from
green, neutral and the existing rsvp-no red; nothing else.
**Don't:** change `authenticate_admin!`, `can_delete?` gating, or any admin action.
Read `.claude/skills/wss-admin` first.
**Acceptance:** A–E, plus: every pattern partial has a short usage comment at its top;
the dashboard shows the same figures as before; a limited admin still sees no delete
controls; admin pages work at 390px.
**Tests:** `test/controllers/admin/*`.

### [ ] D9a · Admin content sections — `sonnet` (after D8)
**Owns:** `app/views/admin/presentations/*`, `admin/bottles/*`, `admin/moderation/*`,
`admin/invitations/*`.
**Do:** Apply D8's partials. The deck form is the largest (structured editors, EasyMDE,
import, render states): regroup into cards without changing field names, Stimulus
targets or the server-side preview.
**Acceptance:** A–E, plus: creating, importing, editing, publishing and re-rendering a
deck all still work end to end (walk it and screenshot each state); moderation actions
unchanged.
**Tests:** `test/controllers/admin/presentations_controller_test.rb`,
`test/controllers/admin/bottles_controller_test.rb`, `test/controllers/admin/moderation*`.

### [ ] D9b · Admin people and money sections — `sonnet` (after D8)
**Owns:** `app/views/admin/users/*`, `admin/subscriptions/*`, `admin/credits/*`,
`admin/activities/*`, `admin/analytics/*`.
**Do:** Apply D8's partials. Tables for users, subscriptions, ledger; analytics as
plain tables and simple CSS bars (no chart library).
**Don't:** add or remove any credit or subscription control here — B2 owns the removal of
the "Set credit balance" field; if B2 has landed, do not bring it back.
**Acceptance:** A–E, plus: the ledger view still lists every transaction with its
running total; filters and pagination keep their params.
**Tests:** `test/controllers/admin/users_controller_test.rb`,
`test/controllers/admin/subscriptions_controller_test.rb`, `test/controllers/admin/credits_controller_test.rb`,
`test/controllers/admin/analytics_controller_test.rb`.

## Wave D3 — finish

### [ ] D10 · Emails — `haiku`
**Owns:** `app/views/layouts/mailer.html.erb`, `app/views/mailers/*`,
`app/views/*_mailer/*.html.erb`.
**Do:** Swap the old palette for the new one in inline styles using this exact map:
dark ground `#191009`→`#16332a`; raised dark `#261a10`→`#1d4034`; amber accents and
button fills (any `#b86e2f`, `#a15825`, `#c9884a`, `#d9ab74`)→`#16332a` for fills and
`#ff6d00` for small marks only; cream `#f6edda`→`#f6f4ee`; page ground→`#f6f4ee`;
button radius 16px; heading font stack → `'Instrument Sans', Arial, sans-serif`.
Do not change any wording, link or the `.text.erb` files.
**Acceptance:** no old hex values remain in mailer views (`grep`); every mailer preview or
test still renders; button text contrast at least 4.5:1.
**Tests:** `bin/rails test test/mailers`.

### [ ] D11 · Consistency, accessibility and docs sweep — `opus` (last)
**Owns:** any view, for small fixes only; `SECTION_NOTES.md`; `docs/redesign/*`.
**Do:** Walk every route in `config/routes.rb` that renders HTML, at both widths, signed
out, as a member and as an admin. Fix leftovers: old mastheads, eyebrows, emoji, stray
colours, inconsistent headers or spacing, focus states, missing labels and alt text,
heading order, contrast below 4.5:1, tap targets under 44px. Run an automated check
(axe-core via Playwright, loaded from cdnjs) on the ten most-used pages and fix
violations. Update `SECTION_NOTES.md` to the new state. Produce
`docs/redesign/GALLERY.md` listing each page with its two screenshots' paths.
**Acceptance:** the gate greps in `ORCHESTRATION.md` are clean across `app/views`; axe
reports no serious or critical violations on the ten pages; no page overflows at 390px.
**Tests:** full suite (orchestrator).

---

# Track B — backend

Backend tasks have their own acceptance criteria. Common rules: test-first (write the
failing test, show it fail, then fix); a migration must be reversible and safe on a live
table; never write `users.credits` directly; every new path logs per `CLAUDE.md`; nothing
here deploys. Items marked **[owner]** need a decision before the worker starts — ask the
advisor, who will put it to the owner; do the rest of the task meanwhile.

## Wave B1 — close the holes (parallel; disjoint files)

### [x] B1 · Event and society authorisation — `opus`
Result: event authorised wherever loaded, `verify_authorized` on owned controllers, private RSVPs need membership (`Event::PUBLIC_EVENTS_OPEN_TO_NON_MEMBERS` flips the public rule), officers cannot touch admins, limited admins cannot purge photos, 500s gone. Follow-up for D3: hide officers' Remove button on admin rows.
**Findings:** S2, S8, S11, S17, S19.
**Owns:** `app/controllers/event_rsvps_controller.rb`, `events_controller.rb`,
`events/*_controller.rb`, `email_rsvps_controller.rb` (membership re-check only),
`society_memberships_controller.rb`, `admin/bottles/reviews_controller.rb`,
`app/policies/event_policy.rb`, `event_rsvp_policy.rb`, `app/models/event.rb`
(`can_rsvp?` only), matching tests.
**Do:** Authorise the event (`show?`) wherever an event is loaded by id; make RSVP
require society membership for **private** societies (leave public events as they are
until the owner answers the question below); protect society admins from officers; add
`authenticate_user!` and nil guards that turn the three 500s into redirects/404s; put
`destroy_image` behind `require_delete_rights!`; add `after_action :verify_authorized`
to the controllers this task owns; log every refusal at `warn` with ids.
**[owner]** May signed-in non-members RSVP to events of *public* societies?
**Acceptance:** for each finding a test that failed before and passes after: a non-member
POSTing an RSVP to a private event gets no RSVP row, no attendee list in the response and
no email is enqueued; a non-member GET of the event-review form for a private event is
refused without the society name in the body; an officer cannot demote or remove an
admin, the creator can; signed-out POSTs redirect to `/auth`; a limited admin cannot
purge a review photo. Existing member flows still pass.
**Tests:** `test/controllers/event_rsvps_controller_test.rb`, `events_controller_test.rb`,
`test/controllers/events/*`, `society_memberships_controller_test.rb`,
`test/policies/*event*`, `test/controllers/admin/bottles/*`.

### [x] B2 · Admin powers — `opus`
Result: admin email edits full-admin only and never on another admin; change clears magic-link/invitation/reset/remember tokens; `:credits` field removed; admin-created subs get the welcome credit via the ledger; admin changes and Pundit denials logged.
**Findings:** S1, M7/S10, M16, S16 (admin parts).
**Owns:** `app/controllers/admin/users_controller.rb`, `admin/subscriptions_controller.rb`,
`app/views/admin/users/edit.html.erb`, `admin/subscriptions/edit.html.erb` (field removal
only), `app/controllers/application_controller.rb` (`user_not_authorized` logging),
`societies_controller.rb` (`society_not_authorized` logging only), matching tests.
**Do:** Email edits by admins: full admins only, never on another admin's record, and
on change clear the magic-link, invitation and remember tokens. Remove `:credits` from
`subscription_params` and its form field. Make the admin-created subscription use
`grant_welcome_credit`, or correct the flash if no credit is granted. Log admin
email/role/profile changes at `info` (actor id, target id, which fields — never values of
tokens) and every Pundit denial at `warn` (user id, policy, record class and id).
**Acceptance:** tests prove: a limited admin's attempt to change any email is refused and
logged; a full admin cannot change another admin's email; after an allowed change the old
magic-link token no longer signs in; posting `user[credits]` to the subscriptions update
leaves `users.credits` and the ledger untouched; the ledger invariant test still passes.
**Tests:** `test/controllers/admin/users_controller_test.rb`,
`admin/subscriptions_controller_test.rb`, `test/models/credit_transaction_test.rb`.

### [x] B3 · Rate limits and sign-in hardening — `sonnet`
Result: `rate_limit` on sign-in (IP+email), email_check, magic link (IP+email), email change, invitations; browser gets redirect + flash, JSON 429; case-insensitive sign-in; missing param 400; email not logged. Lockable proposed, not built.
**Findings:** S3, S18, S16 (sign-in log).
**Owns:** `app/controllers/auth_controller.rb`, `magic_links_controller.rb`,
`society_invitations_controller.rb`, `account_controller.rb` (`request_email_change`
limit only), `config/environments/test.rb` if a cache store is needed, matching tests.
**Do:** Rails 8 `rate_limit` (Solid Cache store) on password sign-in, `email_check`,
magic-link request (per IP **and** per target email), email-change request and society
invitation sending; a friendly 429 response. Use `find_for_authentication` so
mixed-case emails sign in; stop logging the attempted email (log a user id or nothing).
Do not enable Devise `:lockable` — propose it in the hand-back instead.
**Acceptance:** tests show the Nth+1 request inside the window gets 429 and sends no
email, and that requests after the window succeed; `Jon@X.com` signs in; a request with no
`user` param returns 4xx, not 500. Limits are constants at the top of each controller.
**Tests:** `test/controllers/auth_controller_test.rb`, `magic_links_controller_test.rb`,
`test/system/magic_links_test.rb`.

### [x] B4 · Stop account deletion from doing damage — `sonnet`
Result: DELETE /users deletes nothing, redirects to /contact; button replaced by a sentence; `ACCOUNT_DELETION.md` written (29 FKs, 7 hard blockers).
**Findings:** M6, S9.
**Owns:** the Devise `registrations` route options in `config/routes.rb`,
`app/controllers/users/registrations_controller.rb`,
`app/views/devise/registrations/edit.html.erb`, matching tests.
**Do:** Make self-service deletion unavailable for now: `destroy` responds with a
redirect to `/contact` and a notice, logged at `info`; replace the "Cancel my account"
button with one existing sentence pointing to contact (list it as copy for approval).
Write `docs/redesign/ACCOUNT_DELETION.md`: what a real deletion service must do
(cancel Stripe, transfer or refuse founded societies, anonymise authored content, remove
PII, FK map of every table referencing `users`) and the decisions the owner must make.
**Acceptance:** `DELETE /users` deletes nothing and returns a redirect; no data
changes; the design note lists every FK to `users` found in `db/schema.rb`.
**Tests:** `test/controllers/users/registrations_controller_test.rb`.

## Wave B2 — money (strictly in this order, one at a time)

### [ ] B5 · A credit every month on every plan — `opus`
**Findings:** M1, M4, M17.
**Owns:** `app/jobs/monthly_credit_job.rb` (new), `config/recurring.yml`,
`app/models/credit_transaction.rb` (grant methods), the `subscription_cycle` branch of
`app/controllers/webhooks_controller.rb`, `admin/credits_controller.rb` (`grant_monthly`),
`lib/tasks/credits.rake` (new), matching tests. Read `wss-payments-credits` first.
**Do:** One idempotent grant per member per calendar month, keyed in the ledger (for
example a unique `grant_key` column, `monthly:<user_id>:<YYYY-MM>`), taken under
`user.with_lock`. A daily recurring job grants to every member whose subscription is
active and who has not had this month's credit, anchored to their subscription start day.
The renewal webhook and the admin "grant monthly" button use the same key, so no path can
double-grant. On a paid `subscription_cycle` invoice, refresh status from the retrieved
subscription before granting, and log any no-op. Add `rake credits:owed` that **reports**
(does not grant) how many credits each current quarterly/yearly member would have received
under the new rule.
**[owner]** Whether to back-pay the credits `credits:owed` reports. Do not back-pay.
**Acceptance:** tests: a yearly member receives exactly one credit in each of 12
simulated months; running the job twice in a day, or the job plus the webhook plus the
admin button in one month, yields exactly one; a society-only founding member receives
none; a `past_due` member whose retry succeeds receives that month's credit; `users.credits`
equals the ledger sum for every user after each scenario. The migration is reversible.
**Tests:** `test/jobs/monthly_credit_job_test.rb`, `test/models/credit_transaction_test.rb`,
`test/controllers/webhooks_controller_test.rb`, `test/controllers/admin/credits_controller_test.rb`.

### [ ] B6 · Webhook correctness — `opus` (after B5)
**Findings:** M3, M5, M8, M10, M15, M18, M19.
**Owns:** `app/controllers/webhooks_controller.rb`, `app/models/stripe_event.rb`,
`app/services/presentations/checkout_fulfillment.rb` (error propagation only),
`app/models/user.rb` (subscription status only), a migration, matching tests.
**Do:** Ignore subscription events that are not for the user's current subscription
(except a newer `created`); write state from a fresh `Stripe::Subscription.retrieve`
rather than the event payload; add `processed_at` to `stripe_events` and let a claim
older than 10 minutes with no `processed_at` be re-claimed; make fulfilment raise on the
webhook path so Stripe retries; decide the society-only plan from the Stripe price id;
handle `checkout.session.async_payment_succeeded`; unique partial index on
`users.stripe_customer_id`; normalise `cancelled` → `canceled` with a backfill and an
enum. Do not move processing to a background job (deferred by the owner).
**Acceptance:** tests for each: late `created(incomplete)` after `updated(active)` leaves
the user active; a `deleted` event for an old subscription changes nothing; a simulated
crash between claim and completion is reprocessed on redelivery and processed exactly
once; a fulfilment error returns 5xx and releases the claim; a founding-society checkout
grants no deck credit whichever event arrives first; both spellings are gone from `app/`.
**Tests:** `test/controllers/webhooks_controller_test.rb`, `test/models/stripe_event_test.rb`,
`test/services/presentations/checkout_fulfillment_test.rb`.

### [ ] B7 · Purchase integrity — `sonnet` (after B6)
**Findings:** M2, M12, M13, M20, M21.
**Owns:** a migration for `user_presentations`, `app/models/user_presentation.rb`,
`presentation.rb` (associations only), `credit_transaction.rb` (`use_credit`, `readonly?`),
`app/controllers/presentations/purchases_controller.rb`,
`app/services/presentations/checkout_fulfillment.rb` (ownership upgrade),
`app/controllers/admin/presentations_controller.rb` (`destroy`), matching tests.
**Do:** A data migration that merges duplicate ownership rows (keeping `direct` over
`credit`), then a unique index on `(user_id, presentation_id)`; re-check ownership inside
the credit lock; let an existing `credit` row be upgraded to `direct` by a paid checkout
and allow a lapsed credit-owner to buy outright; make deck deletion refuse when anyone
owns the deck (unpublish instead) and never cascade into ownership or ledger rows; make
persisted ledger rows read-only; load owned deck ids once for the library.
**[owner]** When a direct purchase replaces a credit unlock, is the spent credit returned?
Until answered: do not return it, log at `warn` with user and deck ids.
**Acceptance:** tests: two concurrent credit unlocks of one deck spend one credit and
create one row; webhook plus return path create one row; a direct purchase over a credit
row leaves one `direct` row that survives membership lapse; deleting an owned deck is
refused with a message and nothing is destroyed; updating or destroying a ledger row
raises; the library page issues one ownership query. The migration is reversible and
its duplicate merge is covered by a test.
**Tests:** `test/models/user_presentation_test.rb`, `test/controllers/presentations/purchases_controller_test.rb`,
`test/services/presentations/checkout_fulfillment_test.rb`, `test/controllers/admin/presentations_controller_test.rb`.

## Wave B3 — hardening (parallel; disjoint files)

### [ ] B8 · Email change and token hygiene — `opus`
**Findings:** S6, S4, S12 (RSVP and invite links).
**Owns:** `app/controllers/account_controller.rb` (email-change actions),
`app/mailers/user_mailer.rb` and its email-change views, `users/registrations_controller.rb`
(`update`), `email_rsvps_controller.rb` and a new confirm view, `societies#join_by_invite`
and its view, lograge config in `config/environments/production.rb`, a migration for the
token digest, matching tests.
**Do:** Send the confirmation to the **new** address and a notice to the old one; store
only a digest of the token; compare emails case-insensitively; block email changes through
Devise's registration update. Email-RSVP and invite-join links show a one-button
confirmation page that POSTs, and the RSVP POST re-checks `EventPolicy#rsvp?`. Scrub
token path segments from lograge output (`/magic_links/[FILTERED]`, and the same for
`/invitations/`, `/invite/`, `/account/verify_email/`).
**[owner]** Should magic-link sign-in also become click-to-confirm (protects against mail
scanners consuming the link, adds one click)? Not in this task unless answered yes.
**Acceptance:** tests: the old address alone cannot complete an email change; the token
is not stored in clear; a GET of an email-RSVP or invite link changes nothing and the
following POST does; a removed member's old RSVP link is refused; a unit test of the
lograge scrubber shows no token in the logged path. New page copy is listed for approval.
**Tests:** `test/controllers/account_controller_test.rb`, `email_rsvps_controller_test.rb`,
`societies_controller_test.rb`, `test/mailers/user_mailer_test.rb`.

### [ ] B9 · Private downloads — `sonnet`
**Findings:** S5.
**Owns:** `app/controllers/presentations/downloads_controller.rb`,
`config/initializers/active_storage.rb`, matching tests. Read `wss-deck-pipeline` first.
**Do:** After `check_access`, redirect owner downloads to a short-lived service URL
(`blob.url(expires_in: 5.minutes, disposition: :attachment)`) instead of the permanent
signed-id redirect; keep the public sneak-peek as it is; keep `DownloadLog`.
**Acceptance:** tests: the redirect target for a paid file is a service URL with an expiry
and is not the `/rails/active_storage/blobs/redirect/` route; a lapsed credit member and a
signed-out visitor are refused; the blank scorecard path is unchanged. Note in the
hand-back whether the existing permanent links can be invalidated without re-uploading.
**Tests:** `test/controllers/presentations/downloads_controller_test.rb`.

### [ ] B10 · Dead paths and documentation drift — `sonnet`
**Findings:** S14, S20, S13 (logging the rebind only).
**Owns:** `app/controllers/presentations_controller.rb` (remove authoring actions),
`app/views/presentations/new.html.erb`, `edit.html.erb`, `app/policies/presentation_policy.rb`,
`app/controllers/admin_controller.rb`, the `presentations` line in `config/routes.rb`,
`CLAUDE.md` (auth invariant wording), `.claude/skills/wss-auth/SKILL.md`, matching tests.
**Do:** Restrict the public presentations resource to `index`, `show`, `present`; delete
the dead authoring views, policy methods and the unused `AdminController`; document
admin invitations as the fourth sign-in path; log (do not change) OAuth uid rebinds at
`warn` and report whether `email_verified` is available from the Google strategy.
**Acceptance:** `POST /presentations` and `/presentations/new` are not routable; nothing
in `app/` references the removed code (`grep`); suite green.
**Tests:** `test/controllers/presentations_controller_test.rb`, `test/policies/presentation_policy_test.rb`.

## Blocked on the owner

### [!] B11 · Two-factor sign-in (S7)
Half-built: enabling it breaks password sign-in and every other path bypasses it.
**[owner]** Remove it (small) or build it properly across all four sign-in paths (large)?
Advisor's recommendation: remove now, revisit after launch.

### [!] B12 · Account deletion service (M6)
Waits for the decisions listed in `ACCOUNT_DELETION.md` (produced by B4).

## Wave B1 addition (parallel with B1–B4)

### [ ] B13 · Job and config hygiene — `sonnet`
**Findings:** I1, I6, I9, I14, I20, I21, I25, I27.
**Owns:** `config/initializers/*` (new files plus `stripe.rb`), `app/jobs/application_job.rb`,
`event_notification_job.rb`, `event_reminder_job.rb`, `backup_restore_drill_job.rb`,
`app/services/subscription_products.rb`, the cleanup entry in `config/recurring.yml`,
`app/controllers/application_controller.rb` (`set_timezone` only — coordinate with B2,
which owns the denial handler in the same file: B13 goes second),
`app/controllers/admin/presentations_controller.rb` (remove `reset_column_information`
only), matching tests.
**Do:** Stop logging mail-job arguments; add the recurring clear of finished Solid Queue
jobs and a `rake` task for the one-off purge (do not run it); retry mail delivery on
transient network/SMTP errors with backoff; make the event fan-out and reminder safe to
run twice; compare the restore drill against counts recorded at dump time (or
`0 < restored <= production`); Stripe timeouts and retries, `race_condition_ttl`, cache
only a complete price set; fail at boot in production when price ids, encryption keys or
R2 settings are missing; `around_action` with `Time.use_zone`.
**Acceptance:** tests: enqueueing a magic-link mail writes no token to the log; a
transient SMTP error is retried and a permanent one is not; running the fan-out job twice
sends one notification and one email per member; a drill with a newer production row
still passes; a partial Stripe result is not cached as complete; production boot with a
missing price id raises a clear error (tested through the initializer's guard method).
**Tests:** `test/jobs/*`, `test/services/subscription_products_test.rb`,
`test/services/auth/*`, `test/initializers/*` (new).

## Wave B3 additions (parallel with B8–B10)

### [ ] B14 · Deck pipeline safety — `opus`
**Findings:** I4, I5, I8.
**Owns:** `app/services/deck_import.rb`, `app/jobs/deck_slide_render_job.rb`,
`app/jobs/deck_import_job.rb` (new), `config/queue.yml`,
`app/controllers/admin/presentations_controller.rb` (`import` only),
`test/services/deck_import_test.rb`, `test/jobs/deck_*`. Read `wss-deck-pipeline` first;
its two iron rules still hold.
**Do:** For `.ppt`/`.pdf`, create the draft immediately and do the LibreOffice/pdftotext
text extraction in a job (`.pptx` XML parsing may stay inline). A separate `renders`
queue with one thread; mail and default jobs on their own worker. Wrap `soffice` and
`pdftoppm` in a timeout, give each run its own LibreOffice profile directory, and raise
(and log with the deck id) when no slides come out. Render job: one at a time per deck,
attach the new set before purging the old one, log start/finish/no-op/failure.
**Acceptance:** tests (stubbing `system` where needed, plus one real render of a small
fixture `.pptx` since `soffice` is installed here): a `.ppt` import request does not
invoke `soffice` in-process; two render jobs for one deck leave exactly one ordered slide
set; a failed render leaves the previous slides intact; an empty render raises and logs;
a magic-link mail job is picked up while a render is running (queue config asserted).
**Tests:** `test/services/deck_import_test.rb`, `test/jobs/deck_slide_render_job_test.rb`,
`test/controllers/admin/presentations_controller_test.rb`.

### [ ] B15 · Event emails: right time, easy opt-out — `sonnet`
**Findings:** I3, I23.
**Owns:** a migration adding `events.time_zone`, `app/models/event.rb` (time-zone
methods), `app/controllers/events_controller.rb` (set it on create/update — after B1 has
finished with this file), `app/mailers/event_mailer.rb`, `app/views/event_mailer/*`
(wording and times only; D10 restyles later), a signed mute endpoint, matching tests.
**Do:** Store the organiser's zone on the event (from the existing browser-zone cookie,
falling back to the society creator's last known zone, then `America/New_York` — list
this fallback for owner approval); render every event time in mail with that zone and
its abbreviation; backfill existing events with the fallback. Add `List-Unsubscribe` and
`List-Unsubscribe-Post` headers and a signed one-click mute link using the same verifier
pattern as `EmailRsvpsController`.
**Acceptance:** tests: a 7:30pm Eastern event is mailed as "7:30 PM EST/EDT" in created,
updated and reminder emails, html and text; the mute link works signed-out, mutes only
that member's event emails, and is single-purpose; headers present. New copy listed.
**Tests:** `test/mailers/event_mailer_test.rb`, `test/models/event_test.rb`.

## Wave B4 — after the design track (D11 done)

### [ ] B16 · Images and query counts — `sonnet`
**Findings:** I13, I15, I22, I28, M21 if B7 left it.
**Owns:** attachment variant definitions in `app/models/*`, `DesignHelper` cover/avatar
internals, `app/controllers/societies_controller.rb` (`show` loading),
`admin/users_controller.rb` (`edit` loading), small view edits to pass preloaded data.
**Do:** Named variants (`:card`, `:hero`, `:avatar`, `:thumb`) generated ahead of time
in the jobs process; every cover and avatar uses one. Society page: cap the review board
at 15 with the existing "all" route, eager-load member rows, look up the viewer's
membership once. Move the Stripe calls out of the admin user template into the controller
behind a timeout. Preload owned / voted / favourited ids as sets; count unread
notifications once per request.
**Acceptance:** query-count assertions: library index, society show, reviews index and
the layout each stay under a stated bound that does not grow with the number of rows;
no `url_for(…image)` of an original remains in views (`grep`) outside downloads.
**Tests:** `test/integration/query_counts_test.rb` (new), existing controller tests.

### [ ] B17 · Scripts, semantics and dead code — `sonnet`
**Findings:** I17, I18, I19, I24, I26.
**Owns:** new Stimulus controllers replacing the inline scripts in `account/index` and
`presentations/show`, `app/views/profiles/show.html.erb` (the count only),
`app/models/user.rb` (`rsvped_to?`), `SocietyApplication` and its associations,
`lib/tasks/seed_activities.rake`, `CLAUDE.md` (dead document references),
`.claude/skills/wss-deck-pipeline/SKILL.md`.
**Do:** Inline scripts become Stimulus controllers with `disconnect` cleanup; account
tabs get `role="tablist"/"tab"` and `aria-selected`. "Events attended" counts past events
with a `yes` RSVP. Remove `SocietyApplication` (model, associations, table via a
reversible migration) **only if the advisor confirms the owner does not want
self-serve applications**; otherwise leave it and say so. Fix or delete the broken rake
task. Remove references to documents that do not exist; correct the skill.
**Acceptance:** no `<script>` blocks remain in the two views; navigating between pages
ten times leaves one listener of each kind (checked in the browser); a profile with two
past `yes` RSVPs shows 2; `grep` finds no reference to the missing documents.
**Tests:** `test/system/account_navigation_test.rb`, `test/controllers/profiles_controller_test.rb`.

### [ ] B18 · Test gaps and CI — `sonnet` (last backend task)
**Findings:** I16, S15 (report-only CSP).
**Owns:** new tests only, `.github/workflows/ci.yml`,
`config/initializers/content_security_policy.rb`.
**Do:** Add what the other tasks did not: request tests for every download action per
access state, policy tests for `PresentationPolicy`, `EventPolicy`, `EventRsvpPolicy`, the
same signed webhook posted twice through the controller, `customer.subscription.deleted`
expiring credits. CI: Postgres 15 to match production; run system tests. Ship a
**report-only** CSP with nonces for importmap and the remaining inline styles; do not
enforce.
**Acceptance:** the new tests pass and each fails if its guard is removed (state which
guard you removed to check); CI config is valid YAML and the suite passes locally; pages
load with the report-only header and no console CSP errors on the ten main pages.
**Tests:** the new files; full suite (orchestrator).

## Operations items for the owner (not code tasks)

- **I7** memory limits for the web and jobs containers in `config/deploy.yml` (needs the
  box's RAM).
- **I10** a separate R2 bucket and a write-only token for backups; consider encrypting dumps.
- **I11** a dead-man's-switch ping from the nightly backup.
- **M1** confirm the yearly and quarterly Stripe prices' billing intervals.
- **M15** confirm which payment methods are enabled in the Stripe dashboard.
- **S7** check whether any production user has `otp_enabled = true`.

---

# Suggested schedule

Design and backend tasks touch different files, so a design wave and a backend wave can
run together. Run the full gates after each row.

| Step | Run together | Notes |
|---|---|---|
| 1 | D0 · B1 · B2 · B3 · B4 | then B13 (shares `application_controller.rb` with B2) |
| 2 | D1 · D2 · D3 · D4 · D5 · D6 · D7 · B5 | B5 alone on the money files |
| 3 | D8 · B6 | then B7 |
| 4 | D9a · D9b · B8 · B9 · B10 · B14 | then B15 (shares `events_controller.rb` with B1) |
| 5 | D10 · D11 | D10 after B15 |
| 6 | B16 · B17 | then B18 |

Stop and report to the advisor if a gate fails twice, if any task wants to change money
or authorisation behaviour beyond its findings, or when a task is `[!]` blocked.
