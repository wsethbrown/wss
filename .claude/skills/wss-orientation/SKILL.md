---
name: wss-orientation
description: Read FIRST in any WSS (Whiskey Share Society) session — project map, house rules, and which skill covers what. Use when starting any task on this repo.
---

# WSS Orientation

WSS is a subscription marketplace for narrative whiskey tasting decks, plus
societies (public/private groups) with events/RSVPs. Rails 8, Ruby 3.4.3,
PostgreSQL, Hotwire, Tailwind v4, Devise+Pundit, Stripe, Solid Queue, Docker.

## House rules (non-negotiable, learned the hard way)
1. **Verify in the browser, not just tests.** Screenshots or JS probes of the
   real page. Many past bugs (sticky scroll, blank admin, empty downloads box)
   were invisible to the test suite.
2. **No fabricated content, ever.** No fake reviews/stats/guarantees/ratings.
   This codebase shipped fake testimonials once; they were purged. If a number
   isn't real, it doesn't render.
3. **Run the full suite after every change**: see wss-testing skill. 177 runs,
   0 failures is the baseline. Commit with a clear message; push to
   origin (github.com/wsethbrown/wss).
4. **The credit ledger is sacred.** Never write users.credits directly —
   see wss-payments-credits.
5. **Read the docs trio when context is missing**: OVERHAUL_PLAN.md (history),
   SECTION_NOTES.md (per-section state + punch list), DESIGN_BRIEF.md
   (design direction incl. REJECTED ideas — never re-propose those).

## Skill map
- wss-dev-environment — running the app, Docker layout, env gotchas, known
  failure signatures
- wss-testing — test commands, the parallel flake, test-env pinning
- wss-design-system — tokens, layout rules, sticky/overflow traps, rejected
  design directions
- wss-payments-credits — Stripe, webhooks, the credit ledger, purchase states
- wss-auth — magic links, Google/Apple OAuth, 2FA encryption keys
- wss-deck-pipeline — import, slide rendering, teaser gate, Present mode
- wss-societies — privacy model, invites, member management
- wss-admin — admin panel structure and its traps
- wss-production-launch — the launch runbook and current deploy state
- wss-reviews — bottle catalog, solo reviews, aggregation rules, Phase 2/3
  roadmap
  - Reviews (/reviews): public bottle library + tastings; bottle pages at
    /bottles/<slug> — see wss-reviews skill.

## Key models (30-second data model)
User (credits cache, subscription_* fields, is_admin) · Presentation (deck:
content markdown + slide_images + files + tags) · UserPresentation (ownership:
purchase_type direct|credit) · CreditTransaction (LEDGER — source of truth) ·
StripeEvent (webhook idempotency) · Society (is_private, invite_token) ·
SocietyMembership (role: member|officer|admin) · Event + EventRsvp ·
Tag + PresentationTag · ActivityLog (curated event stream) · DownloadLog.
