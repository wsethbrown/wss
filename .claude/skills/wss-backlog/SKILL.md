---
name: wss-backlog
description: WSS pending-work register — deferred/half-decided items (Maps + email cost watches, the Aug 9 renewal watch, real deck uploads, review-system leftovers) with each item's blocker and owner. Use BEFORE building anything new, so you don't rediscover or duplicate work already scoped, deferred, or blocked on an owner decision.
---

# WSS Backlog — check here before building anything new

An item is on this list because it is **pending, half-decided, or deliberately deferred** — not
forgotten. Before you scope new work, check if it's already here. Some items are blocked on an
**owner decision** (do not just pick an answer); some are **owner-only** (legal/console actions you
can't do from code). **When an item ships, delete it from this file.**

Legend: **[code]** = engineering work · **[owner]** = only the owner can do it (console/legal/manual).

## Highest priority

- **Deploy discipline (shipped 2026-07-19, don't regress). [code, done]**
  CI had NEVER passed before this date, so it was decoration and deploys
  ignored it. Now: `bin/kamal-deploy deploy` refuses unless HEAD is committed,
  pushed and CI-green (`--force` overrides and says so loudly), and `bin/smoke`
  runs after every deploy. **Never "fix" a red build by deleting the check.**
  NOTE: running `bin/kamal-deploy deploy` really deploys once CI is green;
  there is no dry-run. Don't run it to "test the gate".

- **Infrastructure plan agreed with the owner 2026-07-19, in this order. [code]**
  1. **Restore drill on a schedule.** A manual restore was verified once on
     2026-07-19 (server-side into a scratch DB, 45 tables, row counts matched
     production, zero ledger drift, scratch dropped). Turn that into a weekly
     job so silent backup rot is caught without anyone remembering to look.
  2. **Staging environment, seeded from a SCRUBBED production restore**
     (owner decision: scrub, not seed-only, not raw). Rewrite emails/names,
     drop Stripe ids and tokens, keep data shape and volume. Deploy to staging
     first, smoke there, then production.
  3. **Browser regression tests.** The 700 tests are all request-level, which
     is why several things shipped today that passed tests but were visibly
     broken in the page (dead Remove link, pour-card wiring). Rails system
     tests over the flows that earn money: purchase + access, deck pour list
     editing, RSVP, sign-in. Keep the set focused so CI stays fast.
  4. **Devise 5.x upgrade.** Clears the two advisories waived in
     `.bundler-audit.yml`. Real auth migration: verify password, magic link and
     OAuth sign-in end to end. `test/models/devise_exemption_test.rb` fails if
     anyone enables `:confirmable`/`:timeoutable` while the waiver stands.

- **Cloudflare is replacing our robots.txt. [owner]** Discovered 2026-07-19 by
  `bin/smoke`. Cloudflare's managed robots.txt serves in front of the origin,
  so our `Sitemap:` line and our `Disallow:` rules for `/admin/`, `/account`,
  `/magic_links/`, `/invitations/`, `/email_rsvps/` never reach crawlers, which
  now see `Allow: /`. Fix in the Cloudflare dashboard (disable the managed
  robots.txt, or merge our directives into it). Then restore the content
  assertion in `bin/smoke` (it currently checks reachability only, with a note).

- **Backups: what they do and don't cover. [awareness]** Nightly `pg_dump` to
  R2 at 09:00 UTC, 14 kept (`DatabaseBackupJob`, `config/recurring.yml`).
  Postgres ONLY: Active Storage uploads (deck PDFs, images) live in R2 and rely
  on R2's own durability, they are not in the dump.


- **Google Maps cost watch (owner rule, July 2026). [watch + one-flag response]**
  Places autocomplete (location fields) runs on the "WSS Location Autocomplete"
  key in the Whiskey Share Society GCloud project (billing account "My Maps
  Billing Account"). Budgets: "$5 Monthly Budget Alert" (early warning) and
  "$10 Maps kill-switch (turn off autocomplete)" (alerts at $5/$9/$10 to
  billing-admin email). **When the $10 alert fires: set MAPS_AUTOCOMPLETE: "off"
  in config/deploy.yml env.clear and deploy** — every location field degrades
  to a plain text input by design. Don't delete the key; the flag is the switch.

- **Email cost tracking as volume grows. [owner watch + code later]** Resend went live 2026-07-17
  (verified sending domain send.whiskeysharesociety.com, sending-scoped API key in the prod env
  file + encrypted backup). FREE TIER = 3,000 emails/month, 100/day. Owner directive: once volume
  approaches the free tier, analyze sending costs (Resend paid starts ~$20/mo for 50k) and track
  the line item in the business budget. Watch volume in the Resend dashboard; event notifications
  (launched July 2026) multiply sends per event, so member growth is the driver.

## Review system, remaining ties

- **[code] wss-reviews "Phase 3" leftovers.** Deck reviews SHIPPED (July 2026: events carry an
  optional deck + host, PresentationReview with the purchased-or-attended rule, ratings cached on
  the deck and shown on library/homepage cards). Still open from that phase: deck names on review
  provenance cards, and "search by chapter". Read wss-reviews before extending.

## Watch item — Aug 9, 2026 (first real renewal)

- **Owner's live subscription renews ~Aug 9, 2026. [owner watch, no code]**
  Sub started ~Jul 9, 2026; ~Aug 9 fires the first real
  `invoice.payment_succeeded` with `billing_reason: "subscription_cycle"` — the first production
  test of monthly credit cycling. Code path verified: `webhooks_controller.rb:171` routes
  `subscription_cycle` → `CreditTransaction.grant_monthly_credit` (+1 credit), and every webhook is
  deduped via `StripeEvent.claim` (`webhooks_controller.rb:12`). **On that day, verify exactly:**
  1. Balance goes up by **exactly +1** credit (not 0, not 2).
  2. **One** new `credit_transactions` row (monthly renewal), not a welcome-credit row.
  3. **One** `stripe_events` row for that event id (idempotency held; Stripe retries didn't stack).
  If any of these is off, see wss-payments-credits (welcome-credit saga / dedup rules).

## Content & config

- **Real deck uploads. [owner]** The catalog still holds demo/dev decks. Owner must import real
  decks via the admin import flow (see wss-deck-pipeline) before any marketing push.

## Gotchas / Traps

- **The review board's plain AVG is DECIDED, not a placeholder.** Owner ruling (July 2026):
  every member gets one vote, their most recent take, weighted equally. Explainable beats clever,
  and weighting only matters at volumes a club doesn't reach. Do NOT "improve" it into per-event
  or per-reviewer weighting; revisit only if a society complains a single night skewed a bottle.
- **Don't build an in-app refund flow.** Refunds are the owner's manual Stripe-dashboard action by
  design (see wss-payments-credits) — not a backlog gap.
- **The Aug 9 item is a verification watch, not a build task.** The code is already in place and
  verified; the job that day is to confirm it behaved, then delete this item.
- **This file is a register, not a spec.** When you finish an item, remove its bullet — a stale
  "pending" line will send a future session chasing already-shipped work.
