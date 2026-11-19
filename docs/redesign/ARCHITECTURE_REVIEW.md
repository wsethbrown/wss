# Architecture and backend review — November 2026

Three read-only review passes over the codebase at commit `a1e2195`: data and money (**M**),
requests/auth/security (**S**), and jobs/infrastructure/tests/frontend structure (**I**).
Nothing was run or changed. Items already recorded as decided or deferred in
`OVERHAUL_PLAN.md`, `SECTION_NOTES.md` or the `wss-*` skills are left out unless still open
and worth ranking.

**Verification status.** Findings marked ✔ were re-checked against the code by a second
reader. The rest come from one reviewer's reading and should be confirmed by the engineer
who picks up the task (each task in `TASKS.md` starts with a failing test, which does that).
Findings marked *unverified* could not be confirmed from code alone; what would confirm
them is stated.

## Overall

The architecture is sound for its size: a conventional Rails 8 monolith with Hotwire,
Pundit, Solid Queue and a clear domain. The strongest parts are the credit ledger design,
webhook idempotency, magic-link tokens, the single privacy scope for societies and events,
and careful HTML output. The weak parts cluster in three places:

1. **Subscription state is driven by webhooks with no ordering, no reconciliation and one
   missing schedule**, so members can be charged and under-served (M1, M3, M4, M5, M8).
2. **Authorisation is opt-in per action**, with no `verify_authorized` safety net, which
   has left real holes around events and admin powers (S1, S2, S8, S11).
3. **There is no abuse protection at all**: no rate limits, no lockout (S3).

## M — data model and money

| # | Sev | Finding | Where | Fix |
|---|---|---|---|---|
| M1 ✔ | High | **Quarterly and yearly members get one credit per billing cycle, not per month.** The only recurring grant is on `invoice.payment_succeeded` with `subscription_cycle`, which Stripe sends once per interval; no scheduled job grants monthly. `Membership::BENEFITS` promises a credit every month on every plan. A yearly member gets 2 credits in year one instead of 12. *Confirm the live prices' intervals in Stripe.* | `webhooks_controller.rb:182-185`, `config/recurring.yml` | M: daily job granting on each monthly anniversary, idempotent per `(user, YYYY-MM)` under `with_lock`; webhook uses the same key. |
| M2 ✔ | High | **`user_presentations` has no unique index.** A double-click on "unlock with credit" spends two credits; webhook and return path can both write a row; `RecordNotUnique` rescue in fulfilment is dead code. With both a credit and a direct row, `can_access_presentation?`'s unordered `find_by` can pick the credit row and lock out a cash buyer when membership lapses. | `db/schema.rb`, `purchases_controller.rb:41-45`, `credit_transaction.rb:81-102`, `checkout_fulfillment.rb:47,66-69`, `user.rb:440` | S: dedupe, add unique `(user_id, presentation_id)`, re-check ownership inside the lock. |
| M3 | High | **Out-of-order or stale subscription webhooks overwrite current state.** No handler checks the event's subscription id against the user's current one or compares timestamps. A late `created` (incomplete) after `updated` (active) leaves a paying member inactive; a late `deleted` for an old subscription cancels the new one and expires its credits. | `webhooks_controller.rb:61-75, 89-113, 135-160` | M: ignore events for a non-current subscription; on each event re-fetch the subscription from Stripe and write its current state. |
| M4 | High | **A recovered renewal payment grants no credit.** After a failed payment sets `past_due`, the successful retry's invoice event calls `grant_monthly_credit`, which returns early (silently) because status is not `active`. | `webhooks_controller.rb:220-226`, `credit_transaction.rb:42-43` | S: the paid invoice is the proof; set status from the retrieved subscription before granting; log the no-op. |
| M5 | High | **Deck fulfilment errors are swallowed and the webhook returns 200.** A transient DB error during `UserPresentation.create!` leaves a paid checkout with no ownership row and no retry. | `checkout_fulfillment.rb:70-73`, `webhooks_controller.rb:240` | S: re-raise on the webhook path so the claim is released and Stripe retries. |
| M6 | High | **Self-service account deletion 500s for most users, and when it works it cascades into other members' data and leaves Stripe billing.** `DELETE /users` is live; several FKs to `users` have no dependent handling; `societies`/`events`/`presentations` are `dependent: :destroy`; nothing cancels the subscription. (Also S9.) | `routes.rb:5-8`, `devise/registrations/edit.html.erb:41`, `user.rb:135-168` | L: disable the route now; build a deletion service. **[owner]** decides what is kept. |
| M7 ✔ | High | **Admin "Set credit balance" writes `users.credits` directly**, bypassing the ledger (the users form was fixed; this second form was not). Balance can go negative with no audit row. (Also S10.) | `admin/subscriptions_controller.rb:324-330`, `admin/subscriptions/edit.html.erb:127-128` | S: remove the param and the field. |
| M8 | Med | **A claimed webhook whose handler never finishes is lost.** The claim commits before processing; a deploy or kill mid-handler leaves the event marked processed. | `webhooks_controller.rb:12-41`, `stripe_event.rb:138-148` | S/M: `processed_at`, re-claim stale unprocessed events. |
| M9 | Med | **Two parallel checkouts can create two live subscriptions**; in-app cancel acts on one. | `subscriptions_controller.rb:42-69, 90-109` | M: one open Checkout Session per user, or detect on `created`. |
| M10 | Med | **Society-only founding members can receive a welcome deck credit** because the guard reads a local column the triggers can beat. | `credit_transaction.rb:61`, `account_controller.rb:311-318`, `webhooks_controller.rb:186-191` | S: decide from the Stripe price id. |
| M11 | Med | **The 50-slot founding cap can be oversold**: checked only at session creation. | `subscriptions_controller.rb:26-35`, `webhooks_controller.rb:326-331` | S/M: reserve with a TTL, or re-check on completion. **[owner]** on over-cap handling. |
| M12 | Med | **Deleting a deck either 500s (FKs from ledger/download rows) or removes buyers' lifetime access** via `dependent: :destroy`. | `presentation.rb:8`, `admin/presentations_controller.rb:132-134` | S: archive instead of delete; `restrict_with_error`. |
| M13 | Med | **A lapsed credit-owner cannot buy the deck outright; a direct payment over a credit unlock is absorbed without upgrading the row.** | `purchases_controller.rb:41-45`, `checkout_fulfillment.rb:47-51` | M: allow direct over credit and upgrade the row. **[owner]** on returning the credit. |
| M14 | Med | **Pause writes a local `paused` status that Stripe's next event overwrites**, so access while paused depends on timing. | `subscriptions_controller.rb:258-261`, `webhooks_controller.rb:100-113` | S: derive from `subscription_paused_at`. **[owner]**: do paused members keep access? |
| M15 | Med | *Unverified:* **delayed payment methods are never fulfilled** (`checkout.session.async_payment_succeeded` unhandled). Confirm which methods are enabled in Stripe. | `webhooks_controller.rb:17-32` | S |
| M16 | Low | Admin-created subscriptions (1-day trial) never get the welcome credit the flash claims. | `admin/subscriptions_controller.rb:285-306` | S |
| M17 | Low | "Grant monthly" admin button has no per-month idempotency. | `admin/credits_controller.rb:80-90` | S (shares M1's key) |
| M18 | Low | `users.stripe_customer_id` has no index or uniqueness; every webhook scans. | `db/schema.rb` | S: unique partial index. |
| M19 | Low | `canceled` vs `cancelled` spelling splits admin counts and filters. | `webhooks_controller.rb:144`, admin controllers, `user.rb:398` | S: enum with Stripe's spellings, backfill. |
| M20 | Low | Ledger rows are mutable; negative balances possible. | `credit_transaction.rb` | S: `readonly?` once persisted. |
| M21 | Low | Library checks ownership once per card (12 queries a page). | `presentations/index.html.erb:109` | S |

Checked and fine: money maths (decimal column, server-computed amounts), no SQL
interpolation in model scopes, every other ledger write path goes through the ledger API
under a row lock.

## S — requests, authentication, authorisation, security

| # | Sev | Finding | Where | Fix |
|---|---|---|---|---|
| S1 ✔ | High | **A limited admin can take over any account, including a full admin's**: admin `user_params` permits `:email`, the change skips verification and is unlogged, and magic links make the mailbox the credential. | `admin/users_controller.rb:66, 115-120` | S: drop `:email` (or full-admin only, never on another admin); clear sign-in tokens on change; log. |
| S2 ✔ | High | **Any signed-in user can RSVP to a private society's event.** `EventRsvpsController#set_event` never authorises the event and `Event#can_rsvp?` has no membership check. The turbo-stream response returns the attendee list; the "yes" later lets the outsider post reviews to the society's board and review the deck. | `event_rsvps_controller.rb:69`, `event.rb:115-119`, `event_rsvp_policy.rb:13-19` | S: authorise `show?`; require membership. **[owner]**: may non-members RSVP to *public* events? |
| S3 ✔ | High | **No rate limiting and no lockout anywhere.** `POST /magic_links` can exhaust the daily email quota (locking everyone out of sign-in), passwords can be guessed without limit (min length 6), `email_check` enumerates accounts at volume. | no `rate_limit`/rack-attack; `devise.rb:181` | S/M: Rails `rate_limit` on the five entry points; consider lockout. |
| S4 | Med | **Raw sign-in and invite tokens are written to production logs** because they are URL path segments and lograge logs the path. | `routes.rb`, `production.rb:50` | S: scrub token segments in lograge, or move tokens to query params. |
| S5 | Med | **Paid deck files are served by permanent, unauthenticated blob URLs** (known TODO, still open). | `presentations/downloads_controller.rb` | M: short-lived URLs after `check_access`, or stream. |
| S6 | Med | **Email change never verifies the new address** (the link goes to the old one), and Devise's `/users/edit` changes it with only the current password. Token stored in plain text; case-sensitive uniqueness check can 500. | `account_controller.rb:89-170`, `user_mailer.rb:44` | M |
| S7 | Med | **2FA is half-built**: no challenge step exists, so enabling it breaks password sign-in while magic link, OAuth and invitation sign-in bypass it. No UI to enable. *Unverified whether any production user has it on.* | `auth_controller.rb:23-27`, `account_controller.rb:226` | **[owner]**: remove (S) or build properly (L). |
| S8 ✔ | Med | **A society officer can demote or remove the society's admins.** Only the creator's record is protected. | `society_memberships_controller.rb:7-31` | S |
| S9 | Med | Account deletion cascades and does not cancel Stripe (same as M6). | | |
| S10 ✔ | Med | Admin subscriptions form permits `:credits` (same as M7). | | |
| S11 | Med | **The event-review form reveals private society names and event titles** to any signed-in user iterating event ids. | `events/reviews_controller.rb:9, 28` | S |
| S12 | Low | State-changing GET links (email RSVP, magic link, invite join) can be triggered by mail scanners or embedded images; email RSVP skips the membership re-check. | `email_rsvps_controller.rb`, `magic_links_controller.rb`, `societies#join_by_invite` | M: confirm page that POSTs. |
| S13 | Low | *Unverified:* OAuth links to an existing account by email without checking `email_verified`, and silently rebinds a changed uid. | `user.rb:27-43` | S |
| S14 | Low | A leftover public deck-authoring path works for any society member; signed-out `POST /presentations` 500s; dead policy methods and an unused `AdminController`. | `presentations_controller.rb:58-95`, `presentation_policy.rb:28` | S |
| S15 | Low | No Content Security Policy. | `content_security_policy.rb` | M: report-only with nonces, then enforce. |
| S16 | Low | Pundit denials, one rescue, and admin role/email changes are not logged; failed sign-ins log the email address. | `application_controller.rb:82`, `account_controller.rb:221` | S |
| S17 | Low | Limited admins can permanently delete review photos. | `admin/bottles/reviews_controller.rb:4, 12` | S |
| S18 | Low | Password sign-in fails on mixed-case emails; malformed request 500s. | `auth_controller.rb:20` | S |
| S19 | Low | Nil-user and nil-record 500s in event controllers. | `events_controller.rb`, `event_policy.rb`, `event_rsvps_controller.rb` | S |
| S20 | Low | Admin invitation links are a fourth sign-in path the `CLAUDE.md` invariant does not mention. | `Auth::InvitationService` | S: document. |
| S21 | Low | Four controllers of 330+ lines (known Phase 5 work). | subscriptions, account, webhooks, admin/subscriptions | L |

Root cause behind S2 and S11: no controller declares `after_action :verify_authorized`.

Done well: magic-link tokens (digested, single use, 15 minutes); one shared privacy scope
for societies and events, including the autocomplete endpoints; purchase returns verified
with Stripe and bound to the signed-in user; sanitised markdown and escaped mentions;
admin role changes and deletes consistently guarded.

## I — jobs, infrastructure, performance, tests, frontend structure

| # | Sev | Finding | Where | Fix |
|---|---|---|---|---|
| I1 ✔ | High | **Raw magic-link, invitation and email-change tokens are logged and kept in the queue database.** The token is a positional argument of the mail job; Active Job logs arguments at `info`; `filter_parameters` does not apply; finished jobs are never cleared because `recurring.yml` dropped the Rails default cleanup task. | `auth/magic_link_service.rb:39,42`, `auth/invitation_service.rb:38,54`, `config/recurring.yml` | S: `ActionMailer::MailDeliveryJob.log_arguments = false`; recurring clear of finished jobs; one-off purge. |
| I2 | High | Duplicate purchases are possible (same as M2, M5). | | |
| I3 ✔ | High | **Every event email shows its time in UTC.** `config.time_zone` is unset; web pages look right only because of the browser-cookie zone; mail renders in the job process. A 7:30pm Eastern tasting is emailed as "11:30 PM". | `event_mailer/*.erb`, `config/application.rb:48` | M: store a time zone on events (from the organiser's zone) and render with it. |
| I4 ✔ | High | **Importing a .ppt or .pdf still runs LibreOffice / pdftotext inside the web request**, against the pipeline's own rule. | `admin/presentations_controller.rb:35-36`, `deck_import.rb:55-63,111-113` | M: create the draft, extract text in a job. |
| I5 ✔ | High | **Mail shares one 3-thread queue with LibreOffice renders, which have no timeout.** Three renders, or one hung `soffice`, stop every magic-link email, so nobody can sign in. Parallel `soffice` on one profile can also silently produce no slides (*unverified*). | `config/queue.yml:6-9`, `deck_import.rb:96-117` | M: separate `renders` worker with one thread; `timeout`; per-run LibreOffice profile; raise on empty output. |
| I6 | High | **Mail delivery failures are never retried** (retry lines commented out; the mail job has no `retry_on`). A provider 429 during an event fan-out, or a blip on a magic link, loses the email. | `app/jobs/application_job.rb:2-6` | S |
| I7 | Med | The jobs container has no memory cap and shares the host with Postgres and web; an OOM can take the database. *Box RAM unverified.* | `config/deploy.yml:14-17` | S **[owner/ops]** |
| I8 | Med | `DeckSlideRenderJob` purges old slides before attaching new ones, can run twice for one deck (interleaved duplicates), and logs nothing. | `app/jobs/deck_slide_render_job.rb:7-19` | S/M |
| I9 | Med | The weekly restore drill compares an hour-old dump with live counts, so it will raise false alarms once there is traffic. | `backup_restore_drill_job.rb:124-131` | S |
| I10 | Med | Database backups sit unencrypted in the same R2 bucket, under the same keys, as user uploads. | `database_backup_job.rb:66-73`, `config/storage.yml` | S/M **[owner/ops]** |
| I11 | Med | Nothing alerts if the jobs container or the nightly backup stops. | `config/recurring.yml`, `config/deploy.yml` | S **[owner/ops]** |
| I12 | — | A newer Ruby base image could ship a `pg_dump` 17 that cannot restore into Postgres 15. **Not a problem as wsethbrown/wss#36 stands**: it pins `-slim-bookworm`, whose client is 15. Keep the pin. | `Dockerfile:18` | — |
| I13 | Med | Full-size uploads are served where thumbnails are shown (deck covers up to 15MB, avatars up to 5MB, the nav avatar on every page), each through a Rails redirect. | `_deck_card.html.erb:8`, `presentations/show.html.erb:37`, layout `:166`, `societies/show.html.erb` | M: named variants, preprocessed; proxy mode. |
| I14 | Med | A Stripe cache miss puts up to three sequential Stripe calls in the homepage request with 30s/80s default timeouts, and a partial result is cached for an hour (a blip hides a plan). | `subscription_products.rb:14-104`, `initializers/stripe.rb` | S |
| I15 | Med | The society page loads every bottle and review in the society's history, and runs several queries per member row. | `societies_controller.rb:57-59`, `societies/show.html.erb:200-283` | S/M |
| I16 | Med | Important paths have no tests: `DeckImport`, `DeckSlideRenderJob`, credit purchase POST, most download actions, webhook replay through the controller, subscription deletion, three policies, mailer content. CI runs Postgres 16, production 15; system tests do not run in CI. | `test/`, `.github/workflows/ci.yml:66` | M |
| I17 | Med | Inline page scripts add global listeners on every Turbo visit and never remove them (account page, deck page). They also block a CSP. | `account/index.html.erb:75-163`, `presentations/show.html.erb:183-206` | S: Stimulus controllers. |
| I18 ✔ | Low | **Profiles always say "0 events attended"**: the query uses status `confirmed`, which does not exist. | `profiles/show.html.erb:38`, `user.rb:254-256` | S |
| I19 | Low | Dead code: `SocietyApplication`, unused tag queries on every account view, a rake task that now raises, design-study templates. | various | S |
| I20 | Low | Missing production env vars (price ids, encryption keys, R2 bucket) fail late with silent fallbacks instead of at boot. | `subscriptions_controller.rb:12-16`, `subscription_products.rb:156-196` | S |
| I21 | Low | The admin deck controller resets the shared schema cache on every request ("temporary fix"). | `admin/presentations_controller.rb:6,139-140` | S |
| I22 | Low | The admin user edit template calls Stripe twice while rendering. | `admin/users/edit.html.erb:104-105,214` | S |
| I23 | Low | Event emails have no one-click unsubscribe, so opting out means marking as spam on the domain magic links use. | `event_mailer.rb` | S/M |
| I24 | Low | `<html>` has no `lang`; no skip link; account tabs lack tab semantics. | layouts, `account/index.html.erb` | S |
| I25 | Low | Event notification and reminder jobs are not safe to run twice (a deploy mid-fan-out duplicates emails). | `event_notification_job.rb`, `event_reminder_job.rb` | S |
| I26 ✔ | Low | `CLAUDE.md` references five documents that are not in the repo; the deck-pipeline skill describes controllers that no longer exist. | `CLAUDE.md`, `.claude/skills/wss-deck-pipeline` | S |
| I27 | Low | *Unverified:* `Time.zone=` in a `before_action` may leak a browser zone to the next request on the thread. | `application_controller.rb:69-71` | S: `around_action` with `Time.use_zone`. |
| I28 | Low | Small N+1s: ownership per deck card, vote/favourite per tasting card, unread count twice in the layout, a `find` loop in admin analytics. | various | S |

Done well: the backup and restore-drill jobs; event reminders that self-cancel when an
event moves; one fulfilment path for return page and webhook; the search-privacy
middleware; a clean Stimulus setup with no CDN pins and good eager loading in the
reviews index.

## What to do first

1. **M1** — members on quarterly and yearly plans are being under-served today.
2. **S1, S2, M7** — small fixes to real privilege and privacy holes.
3. **S3, I1, I5, I6** — sign-in can be knocked out by abuse or by a hung render, and
   tokens are in logs.
4. **M2–M5** — charged-but-not-served cases in purchases and renewals.
5. **I3** — event emails give the wrong time.

