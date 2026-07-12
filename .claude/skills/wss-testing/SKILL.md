---
name: wss-testing
description: Run the WSS test suite correctly, gate deploys on it safely, interpret results, and handle the known parallel flake and schema-dump trap. Use before every commit, before any deploy, and when tests fail unexpectedly.
---

# WSS Testing

## The command (run after EVERY change)
    docker compose run --rm --no-deps -e RAILS_ENV=test \
      -e DATABASE_URL="postgresql://wss:password@db:5432/wss_test" \
      web bash -c "bin/rails db:test:prepare && bin/rails test"
(or `./wss test`).

## Expected count — DO NOT trust the old "177"
The suite has grown well past that. Last-known-green figures, cite the source,
do NOT treat either as today's number:
- **383 green** on 2026-07-08 (commit a883187 message: "suite 383 green").
- **296 runs** on 2026-07-07 (the review/social-layer plan). These two count
  different things at different points, so they don't reconcile — expect 380+.
There are 62 `*_test.rb` files now. Docker is down here; **re-run the suite to
get today's real count** and treat that as the baseline. The only expected skips
are the ~9 Apple OmniAuth tests, gated until `APPLE_*` env vars exist. Any other
skip/failure is a regression.

## THE TEST GATE (hard rule — a stale test once slipped past the deploy gate)
Commit 620c772: a stale assertion shipped because the suite ran through a `grep`
pipe that **ate the exit code** — the pipeline exited 0 while tests were red.
Rules:
- **Never gate on a pipeline's exit code.** `bin/rails test | grep ...` reports
  grep's status, not the suite's. `tee` has the same defect.
- Redirect the whole run to a file, THEN grep the saved summary:

      docker compose run --rm --no-deps -e RAILS_ENV=test \
        -e DATABASE_URL="postgresql://wss:password@db:5432/wss_test" \
        web bash -c "bin/rails db:test:prepare && bin/rails test" \
        > /tmp/wss-test.out 2>&1
      grep -qE ' 0 failures, 0 errors' /tmp/wss-test.out || { echo RED; exit 1; }

- Rails prints exactly: `N runs, N assertions, N failures, N errors, N skips`.
  The pattern MUST match that format — gate on `' 0 failures, 0 errors'`
  (leading space avoids matching e.g. "10 failures"). Gate on the printed
  summary TEXT, never the exit status of a pipe.
- Never deploy on a red (or unverified) suite. See wss-production-launch for
  where this gate sits in the deploy sequence.

## The schema-dump trap (new migrations)
Adding a migration requires committing the **regenerated `db/schema.rb`**.
Parallel test workers build their databases from the schema dump, NOT by
replaying migrations. A missing/stale dump makes every parallel worker error
out — while a single-file run (which loads the migration path) still passes,
giving a **false green**. After any migration: run `bin/rails db:migrate`,
commit the resulting `db/schema.rb` in the same commit. (Also noted in
wss-reviews, where a review-table migration first hit this.)

## The known parallel flake
Rarely (~3 in 45 runs) one run shows 1 failure/error with slightly fewer
assertions than a clean run (a test aborted mid-run). It has never reproduced
twice in a row. Protocol: re-run; if clean twice, proceed but note it. If it
EVER repeats with the same seed, capture `--seed N` from the output and hunt it
(tests run parallel across `:number_of_processors` workers per
`test/test_helper.rb:51`; suspect shared state / fixture ordering).

## Test-environment pinning (do not "fix" these)
- `HomeController#fetch_stripe_products` returns `fallback_products` in test env
  ON PURPOSE (`home_controller.rb:33` — `return fallback_products if
  Rails.env.test?`). Real keys in `.env` would otherwise make tests hit LIVE
  Stripe and assert against dashboard product names. Tests must stay offline.
  See wss-payments-credits for the live-Stripe reality.
- The pricing DOM contract is pinned by tests (`test/integration/
  home_subscription_cards_test.rb`): `#plan-cards`, h3 plan names, `/mo` spans,
  feature lists, "Get Started" links. Keep the contract or update the tests WITH
  the view in the same commit.

## Writing tests here
- Fixtures live in `test/fixtures` (societies: `whiskey_lovers` public,
  `single_malt` public, `bourbon_club` private — `bourbon_club` is the
  `is_private: true` fixture the privacy/policy tests use, e.g.
  `test/policies/society_policy_test.rb`, `test/models/society_test.rb`). Fixture landmines are
  documented in wss-reviews (eagle_rare/lagavulin review counts, `whiskey_lovers`
  membership counts, `event_rsvps` must QUOTE `status: "yes"`).
- OmniAuth test mode is enabled for Google in integration tests; the Google
  strategy registers with dummy creds outside production so routes exist.
- Thin coverage areas (add tests when touching): purchase controller states,
  downloads gating, the story teaser gate, account tab JS (needs system tests).
