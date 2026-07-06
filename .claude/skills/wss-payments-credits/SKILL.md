---
name: wss-payments-credits
description: WSS money architecture — Stripe checkout/webhooks, the credit ledger invariant, purchase state matrix, download gating, and Stripe API gotchas. Use for ANY change touching payments, credits, subscriptions, or deck access.
---

# WSS Payments & Credits

## The invariant that must never break
**users.credits == CreditTransaction.where(user:).sum(:amount)** — the ledger
is the source of truth; the column is a self-healing cache. ALL credit
mutations go through CreditTransaction.record!/use_credit (row-locked,
atomic). NEVER user.update(credits:) — the admin form once allowed this and
it was removed as a bug. Admin adjustments: Admin → Credits → adjust (writes
a ledger row).

## Business rules (verified against code)
- Subscribers get 1 credit/month (on subscribe + each renewal cycle, via
  webhooks). Plans: monthly $19.99, quarterly $38.97, yearly $119.88.
- A deck bought **direct** = owned forever. Unlocked **with a credit** =
  access only while subscription is active.
- Spending a credit REQUIRES an active subscription (enforced in
  Presentations::PurchasesController — two paths once disagreed; keep single).
- Free decks (price 0) are claimed instantly, NO Stripe involved (Stripe
  rejects unit_amount 0 — this was once a crash).
- Access authority: User#can_access_presentation? → surfaced via
  Presentation#can_download_full_presentation? (admins always pass). The
  downloads controller AND the story/Present gates all delegate to it —
  never fork this logic.

## Purchase state matrix (the show page renders all of these)
signed-out · member-with-credit · member-no-credit · non-subscriber ·
owned-direct · owned-credit+active · owned-credit+LAPSED (blocked from
downloads/story, shown "reactivate" messaging — this leaking was a real bug).

## Webhook pipeline
POST /webhooks/stripe → signature verify (STRIPE_WEBHOOK_SECRET) →
StripeEvent.claim (idempotency table — duplicate events no-op) → handlers
(subscription created/updated/deleted, invoice payment, checkout.session
.completed fulfills deck purchases via metadata user_id/presentation_id).
Processing is inline in the request (moving to a job is a known TODO).

## Stripe API gotchas (each was a production-grade bug)
1. `Stripe::Price.retrieve(id, expand: [...])` is WRONG — the 2nd arg is
   request OPTS; unknown opts become HTTP headers and net-http 0.6 crashes on
   the array value. Use `retrieve({ id:, expand: [...] })`.
2. Checkout Sessions: OMIT payment_method_types to get all dashboard-enabled
   methods (Apple Pay/Link/etc). `automatic_payment_methods` is
   PaymentIntents-only and 400s on Checkout.
3. Local webhooks: `stripe listen --forward-to localhost:3000/webhooks/stripe
   --api-key $STRIPE_SECRET_KEY` — WITHOUT --api-key the CLI may pair to a
   different account/sandbox and events silently never arrive. Get the
   signing secret via `stripe listen --print-secret --api-key $KEY`.
4. End-to-end fulfillment test without a card:
   `stripe trigger checkout.session.completed --api-key $KEY \
    --add "checkout_session:metadata[user_id]=ID" \
    --add "checkout_session:metadata[presentation_id]=ID"`.
5. Test env NEVER talks to Stripe (pinned to fallback products) — see
   wss-testing.

## Where things are
Presentations::PurchasesController (single purchase flow) ·
WebhooksController · SubscriptionsController (checkout/pause/resume/cancel) ·
HomeController#fetch_stripe_products (live pricing, 1h cache, fallback) ·
CreditTransaction · StripeEvent.
