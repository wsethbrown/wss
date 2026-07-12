---
name: wss-payments-credits
description: WSS money architecture — Stripe checkout/webhooks, the credit ledger invariant, welcome credit, purchase state matrix, download gating, and basil-API gotchas. Use for ANY change touching payments, credits, subscriptions, or deck access.
---

# WSS Payments & Credits

Stripe is **LIVE in production** (real keys in secrets; commit fa9b4b1 removed
`ALLOW_MISSING_STRIPE` from config/deploy.yml, so Stripe boots strict in prod —
`config/initializers/stripe.rb` raises on missing keys, carve-outs only for asset
precompile). See wss-production-launch. **Refunds are the owner's manual action
in the Stripe dashboard — there is NO in-app refund flow. Do not build one unasked.**

## The invariant that must never break
**users.credits == CreditTransaction.where(user:).sum(:amount)** — the ledger is
the source of truth; the column is a self-healing cache (`recompute_cached_balance`
after_create is the ONLY writer of users.credits). ALL mutations go through
CreditTransaction.record!/use_credit/grant_*/expire_all_credits — every one is
row-locked (`user.with_lock`). NEVER user.update(credits:) — the admin form once
allowed this and it was removed. Admin adjustments: Admin → Credits → adjust.

## The welcome credit (app/models/credit_transaction.rb:56 grant_welcome_credit)
The new-subscriber credit. `grant_welcome_credit(user)` is the ONE idempotent entry
point — the dedup SELECT and the INSERT run in the SAME `user.with_lock` critical
section (so two concurrent grants can't both see "no row"). Dedup = a `granted` row
whose `description LIKE 'Welcome credit%'` within the last 24h; if none, grant 1 with
`description = WELCOME_DESCRIPTION` (the constant `"Welcome credit - new subscription"`,
credit_transaction.rb:48). Returns true if granted. **Both triggers call this same
method, so both write that same constant — the descriptions never diverge; a double
means the guard was bypassed, not that two prefixes mismatched. Both resolve the SAME
user via `stripe_customer_id`** (sync = `current_user`; webhook = `find_user_by_customer_id`).
**Two triggers fire it seconds apart, both must call it:**
1. Checkout success redirect (SYNCHRONOUS) — account_controller#index sees
   `params[:subscription] == "success"`, calls `ensure_welcome_credit_after_checkout`
   which VERIFIES with Stripe (`Subscription.list status:active`, created <1h ago)
   before granting. The forgeable `?subscription=success` param alone grants nothing.
   Credit is on screen the moment they land back.
2. `invoice.payment_succeeded` webhook with `billing_reason == "subscription_create"`
   — the closed-tab fallback. No active-status guard: a successful first payment IS
   the proof (our subscription_status row can still lag as "incomplete").

**Do-not-regress rules (each was a live bug, July 9 saga):**
- Grant on `invoice.payment_succeeded`/`subscription_create`, NOT on
  `customer.subscription.created` — that event arrives status `"incomplete"` during
  checkout, so an active-sub guard silently swallowed the credit (ef51e3f).
- NEVER reintroduce exact-description dedup — an admin backfill row plus the auto
  grant stacked to 2 credits; prefix LIKE + 24h window fixed it (fc30a1b). Pinned by
  test/integration/welcome_credit_test.rb.
- StripeEvent idempotency does NOT protect this: it keys on Stripe event id, and the
  sync redirect is not a webhook event — the description guard is the ONLY thing
  serializing the sync-vs-webhook overlap.
- Accepted trade-off: a genuine cancel-then-resubscribe within 24h is denied a fresh
  welcome (the window can't tell it from the double). Fine; months-later re-subscribes
  earn one. Don't "fix" this by narrowing the window and reopening the double.
- Remediating an erroneous double: claw it back with a NEGATIVE Admin → Credits
  adjustment (a real ledger row), never `user.update(credits:)` and never a refund flow
  (refunds are the owner's manual Stripe action).

## Monthly renewal & expiry
`invoice.payment_succeeded` + `billing_reason == "subscription_cycle"` →
`grant_monthly_credit` (+1, guarded by `subscription_active?`).
`customer.subscription.deleted` immediate → `expire_all_credits` (single negative
ledger row zeroing the balance).

## One-shot banners (commit 0630764)
Subscription success/cancel banners render ONCE then redirect to strip the query
param. account_controller#index: on `params[:subscription].present?` it stashes
`flash[:checkout_result]` and `redirect_to account_path(anchor: "subscription")`.
Flash makes the banner one-shot — never leave an immortal banner keyed on a sticky
URL param.

## Business rules (verified against code)
- Subscribers get 1 credit/month (welcome on subscribe + each renewal cycle).
- A deck bought **direct** = owned forever. Unlocked **with a credit** = access only
  while the subscription is active.
- Spending a credit REQUIRES an active subscription (Presentations::PurchasesController).
- Free decks (price 0) claim instantly, NO Stripe (Stripe rejects unit_amount 0).
- Access authority: `Presentation#can_download_full_presentation?(user)` is the entry
  point (admins pass here, at presentation.rb:113) → delegates to
  `User#can_access_presentation?(id)` for purchase-type rules (direct = forever, credit
  = needs active sub; NO admin check there). Downloads controller + story/Present gates
  all call the Presentation method — never fork this logic or call the User method directly.
- **Membership prices are LIVE from Stripe** (home_controller#fetch_stripe_products,
  1h cache). Do NOT hard-code dollar amounts as authoritative. `fallback_products`
  (test env + Stripe unreachable) are display values only: monthly/quarterly/yearly,
  yearly `popular: true` = the best-value highlight. See wss-membership-model.

## Purchase state matrix (the show page renders all of these)
signed-out · member-with-credit · member-no-credit · non-subscriber · owned-direct ·
owned-credit+active · owned-credit+LAPSED (blocked from downloads/story, shown
"reactivate" — this leaking was a real access bug).

## Webhook pipeline
POST /webhooks/stripe → signature verify (STRIPE_WEBHOOK_SECRET) → StripeEvent.claim
(idempotency table; duplicate events no-op, return 200) → handlers. On error:
StripeEvent.release + 500 so Stripe retries. Processing is INLINE in the request
(background job is a known TODO). Handlers: subscription created/updated/deleted,
invoice payment succeeded/failed, checkout.session.completed (fulfills deck purchases
via metadata user_id/presentation_id).

## basil-API payload shapes (commit c916a99 — webhooks_controller.rb)
The webhook endpoint is pinned to **2025-05-28.basil** (dashboard) while direct API
calls pin `Stripe.api_version = '2024-06-20'` — objects arrive in BOTH shapes. Helper
methods read whichever is present:
- `subscription_period_end` — basil moved `current_period_end` off the subscription
  onto each subscription ITEM; falls back to `items.data[].current_period_end`.max.
- `invoice_subscription_id` — basil moved `invoice.subscription` →
  `invoice.parent.subscription_details.subscription`.
- `line_subscription_id` — basil moved `line.subscription` →
  `line.parent.subscription_item_details.subscription`.
Keep both legacy and basil branches; do not "simplify" to one shape.

## Stripe API gotchas (each was a production-grade bug)
1. `Stripe::Price.retrieve(id, expand: [...])` is WRONG — 2nd arg is request OPTS;
   unknown opts become HTTP headers and net-http 0.6 crashes on the array. Use
   `retrieve({ id:, expand: [...] })`.
2. Checkout Sessions: OMIT payment_method_types to get all dashboard-enabled methods
   (Apple Pay/Link). `automatic_payment_methods` is PaymentIntents-only, 400s on Checkout.
3. Local webhooks: `stripe listen --forward-to localhost:3000/webhooks/stripe
   --api-key $STRIPE_SECRET_KEY` — WITHOUT --api-key the CLI may pair to a different
   account and events never arrive. Signing secret: `stripe listen --print-secret --api-key $KEY`.
4. Fulfillment test without a card: `stripe trigger checkout.session.completed
   --api-key $KEY --add "checkout_session:metadata[user_id]=ID"
   --add "checkout_session:metadata[presentation_id]=ID"`.
5. Test env NEVER talks to Stripe (pinned to fallback products) — see wss-testing.

## Where things are
Presentations::PurchasesController · WebhooksController · SubscriptionsController
(checkout/pause/resume/cancel) · AccountController#index (sync welcome credit +
banners) · HomeController#fetch_stripe_products · CreditTransaction · StripeEvent.
