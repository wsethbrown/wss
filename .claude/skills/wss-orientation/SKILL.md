---
name: wss-orientation
description: Read FIRST in any WSS (Whiskey Share Society) session — project map, house rules, and which skill covers what. Use when starting any task on this repo.
---

# WSS Orientation

WSS is a subscription marketplace for narrative whiskey tasting decks, plus
societies (public/private groups) with events/RSVPs and a reviews/community
layer. Rails 8, Ruby 3.4.3, PostgreSQL, Hotwire, Tailwind v4, Devise+Pundit,
Stripe (LIVE), Solid Queue, Docker. Deployed to production — see
wss-production-launch.

## House rules (non-negotiable, learned the hard way)
1. **User-facing copy is PROPOSED, never just edited.** Present options, get
   Seth's approval, THEN ship the chosen one. Commits carry "(owner-approved)".
   Code comments and internal docs are exempt — this is about anything a user
   reads. See wss-membership-model for the benefit-copy source of truth.
2. **Verify in the browser, not just tests.** Screenshots or JS probes of the
   real page before claiming done. Many past bugs (sticky scroll, blank admin,
   empty downloads box) were invisible to the test suite.
3. **When work lands and the suite is green: commit AND push** to origin
   (github.com/wsethbrown/wss) without being asked. Never leave a red suite
   overnight. Gate on the printed summary, not a pipeline exit code — see
   wss-testing for the test-gate ritual and current green baseline.
4. **No fabricated content, ever.** No fake reviews/stats/guarantees/ratings.
   This codebase shipped fake testimonials once; they were purged. If a number
   isn't real, it doesn't render.
5. **The credit ledger is sacred.** Never write users.credits directly —
   see wss-payments-credits.
6. **Design carte blanche for NON-copy visual work** — but REJECTED directions
   in DESIGN_BRIEF.md stay rejected; never re-propose them.
7. **Logging ships WITH the code, always.** Every new controller action, service,
   model callback, and job gets logging as part of the work — not a later pass.
   info for real state changes and silent no-ops, warn for refusals/invalid
   tokens/permission denials, error in EVERY rescue (a bare rescue with no log is
   a bug). Always include ids (`user 42`, `event 17`); NEVER log tokens, secrets,
   session, or full params. Full standard in CLAUDE.md ("Logging"). Owner
   directive, July 2026: this is part of the definition of done.
8. **Read the docs trio when context is missing**: OVERHAUL_PLAN.md (history),
   SECTION_NOTES.md (per-section state + punch list), DESIGN_BRIEF.md
   (design direction incl. REJECTED ideas). Check wss-backlog before building
   anything new — it may already be planned or half-decided.

## Skill map
- wss-dev-environment — running the app, Docker layout, env gotchas, known
  failure signatures
- wss-testing — test commands, the test gate, parallel flake, schema-dump trap
- wss-design-system — tokens, layout rules, sticky/overflow traps, rejected
  design directions
- wss-payments-credits — Stripe, webhooks, credit ledger, welcome credit,
  purchase states
- wss-membership-model — free-vs-paid split, society-creation paywall,
  benefit copy source of truth, live pricing
- wss-auth — magic links, Google/Apple OAuth, 2FA encryption keys
- wss-deck-pipeline — import, slide rendering, teaser gate, Present mode
- wss-societies — privacy model, invites, member management, creation paywall
- wss-reviews — bottle catalog, solo + event reviews, society verdicts,
  veiling, search modes (NO longer holds the social layer — see wss-community)
- wss-community — favorites-as-follows, review votes, feeds, Century badge,
  /contact + Cloudflare email routing, link previews
- wss-admin — admin panel structure and its traps
- wss-production-launch — deploy + operations runbook, secrets, backups
- wss-backlog — pending work (SEO, SMTP, OAuth URI, Aug 9 renewal watch, real
  deck uploads); read before starting new work

## Key models (30-second data model)
User (credits cache, subscription_* fields, is_admin, favorites/followers) ·
Presentation (deck: content markdown + slide_images + files + tags) ·
UserPresentation (ownership: purchase_type direct|credit) · CreditTransaction
(LEDGER — source of truth) · StripeEvent (webhook idempotency) · Society
(is_private, invite_token) · SocietyMembership (role: member|officer|admin —
the JOIN table, unrelated to paid Membership) · Event + EventRsvp · Bottle +
Review · Favorite (bookmark AND follow) · ReviewVote · Tag + PresentationTag ·
DownloadLog.
