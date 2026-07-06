---
name: wss-testing
description: Run the WSS test suite correctly, interpret results, and handle the known parallel flake. Use before every commit and when tests fail unexpectedly.
---

# WSS Testing

## The command (run after EVERY change)
    docker compose run --rm --no-deps -e RAILS_ENV=test \
      -e DATABASE_URL="postgresql://wss:password@db:5432/wss_test" \
      web bash -c "bin/rails db:test:prepare && bin/rails test"
(or `./wss test`). Baseline: **177 runs, 662 assertions, 0 failures,
0 errors, 9 skips**. The 9 skips are Apple OmniAuth tests, intentionally
gated until APPLE_* env vars exist. Any other skip/failure is a regression.

## The known parallel flake
Rarely (~3 in 45 runs) one run shows 1 failure/error with 655–659 assertions
(a test aborted mid-run). It has never reproduced twice in a row. Protocol:
re-run; if clean twice, proceed but note it. If it EVER repeats with the same
seed, capture `--seed N` from the output and hunt it (tests run 8-way
parallel; suspect shared-state).

## Test-environment pinning (do not "fix" these)
- HomeController#fetch_stripe_products returns fallback_products in test env
  ON PURPOSE — real keys in .env would otherwise make tests hit live Stripe
  and assert against dashboard product names. Tests must stay offline.
- The pricing DOM contract is pinned by tests (test/integration/
  home_subscription_cards_test.rb): #plan-cards, h3 plan names, /mo spans,
  ul.space-y-3 features, "Get Started" links. Keep the contract or update
  tests WITH the view in the same commit.

## Writing tests here
- Fixtures live in test/fixtures (societies: whiskey_lovers is public,
  single_malt is private — used by privacy tests).
- OmniAuth test mode is enabled for Google in integration tests; the Google
  strategy registers with dummy creds outside production so routes exist.
- Thin coverage areas (add tests when touching): purchase controller states,
  downloads gating, the 24-line teaser gate, account tab JS (needs system
  tests).
