---
name: wss-membership-model
description: WSS paid-membership business model — the free-vs-paid split, the society-creation paywall, benefit copy source of truth, and live Stripe pricing. Use when touching membership benefits, the /membership page, pricing copy, or gating a feature on subscription. NOT for SocietyMembership (the join table).
---

# WSS Membership Model

**⚠ Naming collision, read first.** "Membership" (this skill) = the paid
**subscription** a user buys. It is UNRELATED to `SocietyMembership`, the join
table that ties a user to a society with a `role` (`member` | `officer` |
`admin`, `app/models/society_membership.rb:6`). A free account can hold
SocietyMemberships all day; paid membership is a separate thing. When someone
says "membership," disambiguate which they mean. See wss-societies.

## The free-vs-paid split (and WHY)

`app/models/membership.rb` is the **single source of truth** for benefit copy —
two frozen constants, `BENEFITS` and `FREE`. Verified:

**FREE (the everyday reasons to have an account — the sticky tasting record):**
- Join any public society
- Write reviews, rate and favorite bottles
- Follow tasters and societies you trust
- **Buy any deck outright to own it forever**

**Paid `BENEFITS` (what costs us / what power users want):**
- One deck **credit** every month — unlock any narrative deck
- **Create and run your own society** — host tasting nights, manage members/events
- **Keep** your credit-unlocked decks as long as you're a member

Rationale (from the module's own header comment): reviews are the everyday hook,
so the whole tasting record stays free; membership gates the recurring cost
(monthly credit) and the power feature (running a society). All three tiers
unlock the SAME thing — they differ only in price/cadence, so `BENEFITS` is one
list, not three. Credit mechanics (grant, spend, expiry, welcome credit) live in
wss-payments-credits — do not restate them here.

**Stripe metadata may override per-tier features.** `home_controller.rb:52`
reads `product.metadata['features']` (comma-split) and falls back to
`Membership::BENEFITS` only when absent. So dashboard product metadata wins over
the code list for the live pricing page; the constant is the fallback + the
authoritative *intent*.

## The society-creation paywall

`SocietyPolicy#create?` (`app/policies/society_policy.rb:39`):
```ruby
def create?
  return false unless user
  user.admin? || user.has_active_subscription?
end
```
Free accounts JOIN societies (`join?` checks `public? && !has_member?`) but
cannot CREATE one. Global admins are exempt. `new?` aliases `create?`.
`has_active_subscription?` is on User (`user.rb:288`). This is the single
enforcement point — don't add a second gate.

## Pricing — LIVE from Stripe, do NOT hard-code dollars

`home_controller#fetch_stripe_products` pulls live prices (1h cache). It returns
`fallback_products` (`home_controller.rb:147`) only in `Rails.env.test?` or when
`Stripe.api_key` is blank / Stripe is unreachable. **Never state dollar amounts
as authoritative** — they come from the live dashboard.

- Three tiers: **monthly**, **quarterly**, **yearly**.
- **Yearly is best-value / `popular: true`** — lowest per-month, the highlighted
  card. In `fetch_stripe_products` yearly's popular default is `'true'`; monthly
  and quarterly default `false`. In `fallback_products` only yearly is `popular`.
- **Quarterly-as-best-value was a bug and is fixed** (commit a883187). If you see
  quarterly highlighted, that's a regression.
- Fallback per-month display figures exist in code (monthly `1599`, quarterly
  `1299` savings `19%`, yearly `1099` savings `31%`) for test/offline rendering
  only — treat as illustrative, not the truth. Quarterly/yearly feature lists get
  `%`/"save"/"savings" lines stripped (`home_controller.rb:82,112`).

## The public /membership page

`GET /membership` → `home#membership` (`config/routes.rb:31`),
`app/views/home/membership.html.erb` (commit b5e5e67). It's the
start-your-own-club pitch ("Start your own…", line 15). Approved tagline
(commit ecaa82d, line 39):

> Joining a society is free · **Membership required to run a society**

Benefit-first pricing intro landed in 5c5c406 (lead with the credit and the
society, not the price).

## Traps / Gotchas
- **Naming collision** (above) — the #1 source of confusion. Membership ≠
  SocietyMembership.
- **Don't invent perks.** The `BENEFITS`/`FREE` lists exist precisely to stop
  invented copy creeping into pricing. Change the constant, don't sprinkle new
  claims in views.
- **Don't hard-code prices.** Prices are live from Stripe; quoting a dollar
  figure will go stale the moment the owner edits the dashboard.
- **Don't re-highlight quarterly** as best-value — that was the fixed bug.
- **User-facing copy is PROPOSED, never just edited.** All membership/pricing
  copy is owner-approved (see the "owner-approved" commit trail). Present options,
  get a yes, then ship. See wss-orientation for the full copy-approval rule.
- Credit granting/spending/expiry is out of scope here → wss-payments-credits.
