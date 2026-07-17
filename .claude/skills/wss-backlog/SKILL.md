---
name: wss-backlog
description: WSS pending-work register — deferred/half-decided items (SEO trio, review-board weighting, the Aug 9 renewal watch, real deck uploads, prod OAuth URI, SMTP, business registration) with each item's blocker and owner. Use BEFORE building anything new, so you don't rediscover or duplicate work already scoped, deferred, or blocked on an owner decision.
---

# WSS Backlog — check here before building anything new

An item is on this list because it is **pending, half-decided, or deliberately deferred** — not
forgotten. Before you scope new work, check if it's already here. Some items are blocked on an
**owner decision** (do not just pick an answer); some are **owner-only** (legal/console actions you
can't do from code). **When an item ships, delete it from this file.**

Legend: **[code]** = engineering work · **[owner]** = only the owner can do it (console/legal/manual).

## Highest priority

- **SMTP provider undecided — magic links break in prod until fixed. [code + owner]**
  Magic links are the PRIMARY sign-in path (see wss-auth). `SMTP_*` secrets are blank, no outbound
  SMTP configured — so magic-link email never sends in production. Provider not yet chosen
  (Resend vs Postmark). Owner picks provider + creates account; then wire `SMTP_*` into
  `~/.wss-production.env` / `.kamal/secrets` and Action Mailer prod config. This is the top blocker
  for a real launch — nobody can sign in by magic link without it.

## SEO (all three absent today — verified)

- **Sitemap.xml. [code]** No sitemap route or generator exists (`grep -rin sitemap config/ app/`
  returns nothing). Build dynamic `/sitemap.xml`. Absolute URLs need the prod host
  `whiskeysharesociety.com` (there is no base_url constant — see wss-community). `public/robots.txt`
  is the stock empty Rails file today; add a `Sitemap:` line to it when the sitemap ships.
- **Canonical tags. [code]** None in `app/views/layouts/application.html.erb` (no `canonical`).
  Add `<link rel="canonical">` (per-page overridable, mirroring the existing `og_*` helper pattern
  in the layout).
- **JSON-LD structured data. [code]** No `application/ld+json` anywhere. Add structured data
  (Organization / Product for decks).
- **Google Search Console. [owner]** After the three above ship: verify the domain and submit the
  sitemap. Blocked on the sitemap existing first.

## Founding Member tier (owner idea July 2026, blocked on owner decisions)

- **[code + owner] Sketch:** a "Founding Member" status kept only while the subscription never
  pauses/cancels. Two shapes discussed: (a) a $5/mo society-only plan (create/run societies, NO
  monthly deck credit), and/or (b) a founding rate on the full monthly plan ($5 off, e.g. $10.99
  vs $15.99, which matches the yearly plan's effective monthly rate, a coherent story). Losing
  status is permanent; regular price on return.
- **Open owner decisions before building:** Is founding a limited-time window (first N members or
  a date)? Does the $5 tier exist AND the founding rate, or just one? Does a PAUSE lose status or
  only cancel? (Recommend: voluntary cancel only; involuntary payment failure should not strip
  status.) Naming/copy.
- **Engineering notes when approved:** new Stripe Price(s) [owner creates in dashboard];
  `grant_monthly_credit` must become plan-aware (society-only plan gets NO credit);
  society-creation gate already keys on active subscription so the $5 plan passes it; webhook
  handling flags founding status on pause/cancel events. See wss-membership-model +
  wss-payments-credits before touching any of this.

## Society review board

- **Placement + weighting question. [code, blocked on owner decision]**
  Where the review board sits on the society page is undecided, AND the aggregation method is an
  **open owner decision**: plain AVG vs per-event weighting vs per-reviewer weighting.
  **Leave plain AVG until the owner decides** — do not silently pick a weighting scheme.
  Related verdict/aggregation code lives in the review system (see wss-reviews).

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
- **Google OAuth prod redirect URI. [owner — verify done]** The Google console needs
  `https://whiskeysharesociety.com/users/auth/google_oauth2/callback` added as an authorized redirect
  URI. Unconfirmed whether it's been added. The sign-in button gates on real creds being present
  (see wss-auth) — a missing URI = OAuth fails in prod. Verify in the Google Cloud console.

## Owner / legal (blocks nothing technical)

- **Georgia LLC registration. [owner/legal]** Register the business with the GA Secretary of State.
  Pure legal action — blocks no code, but matters before taking real revenue.

## Gotchas / Traps

- **Don't decide the review-board weighting yourself.** It's an owner call; plain AVG is the
  deliberate placeholder, not a bug to "fix."
- **Don't build an in-app refund flow.** Refunds are the owner's manual Stripe-dashboard action by
  design (see wss-payments-credits) — not a backlog gap.
- **The Aug 9 item is a verification watch, not a build task.** The code is already in place and
  verified; the job that day is to confirm it behaved, then delete this item.
- **This file is a register, not a spec.** When you finish an item, remove its bullet — a stale
  "pending" line will send a future session chasing already-shipped work.
