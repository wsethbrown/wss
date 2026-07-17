---
name: wss-production-launch
description: WSS deploy + operations runbook — live prod architecture (Hetzner/Kamal/R2/Postgres accessory), how to deploy from the Mac with no local Ruby, the test gate, secrets flow, backups, and remaining launch items. Use for anything deploy-, secrets-, or production-related.
---

# WSS Deploy & Operations Runbook

**Production IS live.** Full first-deploy runbook: `docs/launch-checklist.md`.
This skill is the operator's map + the traps.

## Current prod architecture (verified config/deploy.yml)
- **Host:** Hetzner box, Kamal service `wss`, single server `178.156.251.37`.
- **Domain:** `whiskeysharesociety.com` (+ www) behind Cloudflare, SSL mode
  **Full**. Kamal proxy terminates TLS (`proxy.ssl: true`); prod forces SSL +
  `assume_ssl` (production.rb:29-32).
- **Registry:** `ghcr.io`, image `wsethbrown/wss` (`registry.server` prepended
  automatically — never repeat it in `image:`).
- **Postgres:** Kamal **accessory `db`** (`postgres:15`), on the same host,
  bound to `127.0.0.1:5432` (never public). App reaches it over TCP at host
  `wss-db` (config/database.yml:95 — a host-less pg config dials a missing Unix
  socket, so `DATABASE_HOST` must stay set). Four logical DBs: primary + cache
  + queue + cable (`db/*_migrate`).
- **Jobs:** a **separate `job` container** running `bin/jobs` (deploy.yml:14-17).
  LibreOffice deck rendering is memory-heavy and must NEVER share the web
  container — see wss-deck-pipeline.
- **Storage:** Active Storage → Cloudflare **R2** service `:cloudflare_r2`
  (production.rb:26). Uploads survive rebuilds; the `wss_storage` volume is
  scratch only.
- **Backups:** `DatabaseBackupJob` pg_dumps → gzip → R2 under `db-backups/`,
  keeps 14, runs nightly **09:00 UTC** via `config/recurring.yml` in the jobs
  container. Manual run: `bin/kamal-deploy backup`.
- **Observability:** Sentry (DSN-gated, inert without `SENTRY_DSN`, `pii: false`);
  **lograge** one structured line/request, greppable from `kamal app logs`.

## Deploying from the Mac (NO local Ruby)
`bin/kamal-deploy` runs the official Kamal Docker image against this repo — no
Ruby/gem install needed. It needs Docker Desktop running.

```sh
source ~/.wss-production.env && bin/kamal-deploy deploy
```

It forwards these env vars into the Kamal container (bin/kamal-deploy:17-23):
`KAMAL_REGISTRY_PASSWORD`, `WSS_DATABASE_PASSWORD`, the three `AR_ENCRYPTION_*`,
`GOOGLE_CLIENT_ID/SECRET`, `STRIPE_SECRET_KEY/PUBLISHABLE_KEY/WEBHOOK_SECRET`,
`STRIPE_{MONTHLY,QUARTERLY,YEARLY}_PRICE_ID`, `SENTRY_DSN`, the four `R2_*`,
and `SMTP_{ADDRESS,USERNAME,PASSWORD}`. `RAILS_MASTER_KEY` comes from
`config/master.key` via `.kamal/secrets`. First-ever deploy is `setup` not
`deploy`. Migrations run automatically on boot.

**Kamal aliases** (deploy.yml:71-76 — `bin/kamal-deploy <alias>`):
`console` · `shell` · `logs` · `dbc` (dbconsole) · `backup`. The wrapper passes
ANY args straight to Kamal (`exec … kamal "$@"`), so every built-in works too —
notably **`bin/kamal-deploy rollback [VERSION]`** to revert a bad deploy and
`bin/kamal-deploy app version`.

**A deploy ships the current WORKING TREE, not a git ref.** The builder mounts
`${PWD}` as the build context (no `builder.context`/git ref in deploy.yml), so
uncommitted edits DO ship. Commit+push is the house rule and DR hygiene, but does
NOT gate what deploys — deploy from a clean, pushed tree so prod matches origin.

## THE TEST GATE (hard rule — cost a bad deploy)
Never deploy on a red suite. **Never trust a piped test run** — a stale
assertion once slipped the gate because the suite ran through a grep pipe that
ate the exit code (fixed 620c772). A pipeline's exit status is the LAST
command's, so `rails test | grep ...` can hide failures.

Rule: redirect to a file, THEN gate on the **printed summary text**:
```sh
... bin/rails test > /tmp/wss-test.out 2>&1
grep -qE " 0 failures, 0 errors" /tmp/wss-test.out || { echo RED; exit 1; }
```
Rails prints `N runs, N assertions, N failures, N errors, N skips` — the
pattern must match that. See wss-testing for how to run the suite (Docker) and
the schema.rb / parallel-worker traps.

## Secrets flow (NEVER committed)
`~/.wss-production.env` (chmod 600, OUTSIDE the repo) → `source` it → shell env
→ `.kamal/secrets` interpolates each `$VAR` at deploy time. `.kamal/secrets`
holds NO literal values — every line is `VAR=$VAR` (or `RAILS_MASTER_KEY=$(cat
config/master.key)`). Secret list is deploy.yml `env.secret`. `env.clear`
(non-secret) sets `DATABASE_HOST=wss-db`, `DATABASE_USERNAME=wss`,
`WEB_CONCURRENCY=2`, `JOB_CONCURRENCY=1`, `SMTP_PORT=587`.

### Backup ritual — `bin/backup-secrets` (run weekly / after any secret change)
Encrypts `config/master.key` + `~/.wss-production.env` (AES-256-CBC, pbkdf2)
into `~/Documents/WSS-Backups` (iCloud carries the blob off-machine), keeps 8
snapshots, and **verifies each decrypts** before trusting it. Passphrase lives
in macOS Keychain item `wss-secrets-backup`:
```sh
security find-generic-password -s wss-secrets-backup -w
```
The Keychain copy dies with the machine — **also store the passphrase in your
password manager** (the DR copy). The `AR_ENCRYPTION_*` trio + `master.key` are
**UNRECOVERABLE if lost**: every user's 2FA enrollment goes with them (the
master.key was lost once — credentials had to be regenerated). Keep offline
copies.

## Stripe: LIVE mode + boot guard
Stripe is in **live mode** in prod. In production the initializer FAILS LOUDLY
if `STRIPE_SECRET_KEY/PUBLISHABLE_KEY/WEBHOOK_SECRET` are blank
(config/initializers/stripe.rb:8-12). Two carve-outs (927e9c1):
- `SECRET_KEY_BASE_DUMMY` — asset precompile during image build runs env-less;
  without this skip the image can't build at all.
- `ALLOW_MISSING_STRIPE=1` — the deliberate pre-launch window. **Not set in
  deploy.yml now** = live keys are in. Never re-add it once keys exist.

API pinned to a fixed version; webhook endpoint is
`https://whiskeysharesociety.com/webhooks/stripe`. Refunds are the owner's
manual dashboard action — there is no in-app refund flow. See
wss-payments-credits for webhook shapes, the welcome-credit design, and the
Aug 9 first-renewal watch.

## Remaining owner launch items (not code)
- **SMTP — DONE (Resend, 2026-07-17).** smtp.resend.com creds in
  `~/.wss-production.env`; verified sending domain send.whiskeysharesociety.com;
  first prod magic link verified delivered. Free tier 3k/month — see the
  wss-backlog cost-tracking watch item.
- **Google OAuth** — production redirect URI
  `https://whiskeysharesociety.com/users/auth/google_oauth2/callback` must be
  added in the Google console (button gates on real creds). See wss-auth.
- **Apple key** — renew/revoke the leaked signing key before enabling Apple
  sign-in.

## Launch sequence (docs/launch-checklist.md is the full runbook)
1. DONE — Cloudflare DNS/SSL Full, GitHub token, R2 bucket+token, Sentry DSN,
   Stripe live keys + 3 prices, Google prod redirect URI.
2. DONE — secrets exported to `~/.wss-production.env`.
3. DONE — first `kamal setup` (Docker on server, Postgres accessory, image, SSL).
4. DONE — smoke test (site loads, signup, R2 upload, `bin/kamal-deploy backup`, logs).
5. DONE — Stripe live webhook endpoint added, `whsec` in secrets.
6. PENDING — SMTP provider (above); watch Sentry day 1; confirm nightly backup;
   uptime monitor on `/up`.

## Gotchas / traps
- **Piped test runs hide failures** — gate on file + summary text, not pipe
  exit code (above).
- **`DATABASE_HOST` must be `wss-db`** — a host-less prod pg config dials a
  local Unix socket that doesn't exist and the app won't boot.
- **`.kamal/secrets` never holds values** — only `$VAR` refs; forgetting to
  `source ~/.wss-production.env` first deploys with empty secrets.
- **Losing `AR_ENCRYPTION_*` / `master.key` = losing all 2FA data.** Run
  `bin/backup-secrets` and keep the passphrase in a password manager.
- **Never re-add `ALLOW_MISSING_STRIPE`** once live keys are in — it silently
  lets payments break.
- **Jobs must be their own container** (`bin/jobs`); LibreOffice in the web
  container stalls page serving.
- **Mailer silently drops mail** while `SMTP_ADDRESS` is unset — no error,
  magic links just never arrive.
