---
name: wss-production-launch
description: WSS deploy + operations runbook — prod architecture (one VPS, Kamal, R2, Postgres accessory), the relaunch script for a new server, how to deploy from the Mac with no local Ruby, the test gate, secrets flow, backups, and remaining launch items. Use for anything deploy-, secrets-, or production-related.
---

# WSS Deploy & Operations Runbook

**Status:** the original Hetzner server (178.156.251.37) was lost around
27 October 2026 and the site went down. It is brought back on a new VPS with
`bin/relaunch-production` (runbook: `docs/relaunch.md`). Do not assume the site
is up: check `curl -s -o /dev/null -w '%{http_code}' https://whiskeysharesociety.com/up`.
Original first-deploy runbook: `docs/launch-checklist.md`.
This skill is the operator's map + the traps.

## Relaunching on a new server — `bin/relaunch-production`
A re-runnable wizard on the Mac (bash 3.2 safe). Ten steps, each detects real
state and skips itself when done; `--from <step>`, `--only <step>`,
`--dry-run`, `--help`: preflight (Docker, clean pushed repo, env file complete
by NAME, SSH key, gh) → server (root login, or copy the key from OVHcloud's
`ubuntu` user; swap; ufw 22/80/443) → config (IP into deploy.yml, commit,
push) → masterkey (regenerate if lost, see below) → database (`kamal server
bootstrap`, `kamal accessory boot db`, load a dump from the downloaded bucket
in one transaction, ownership lines stripped; refuses a non-empty DB without
the phrase `REPLACE PRODUCTION DATA`) → deploy (`bin/kamal-deploy setup`, waits
for /up inside the web container, before DNS) → purge (`users:purge_unused`,
dry run, then typed `DELETE <n> ACCOUNTS`) → turnstile (keys into the env
file, `kamal app boot`) → dns (owner edits Cloudflare; script polls https) →
aftercare (smoke, test magic link to the owner, jobs, recurring backup, a
backup now checked in R2). Non-secret state (IP, skipped steps) lives in
`~/.wss-relaunch-state`. Tests: `test/bin/relaunch_production_test.sh`
(stubbed ssh/kamal/docker/curl; real Postgres load).

## Current prod architecture (verified config/deploy.yml)
- **Host:** one VPS (OVHcloud VPS-2 from the November 2026 relaunch; Hetzner
  before), Kamal service `wss`. Its IP is the one under `servers:` in
  `config/deploy.yml` (also `servers.job.hosts` and `accessories.db.host`);
  never hard-code it elsewhere. Kamal logs in as `root`.
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
`STRIPE_{MONTHLY,QUARTERLY,YEARLY}_PRICE_ID`, the two founding price ids,
`SENTRY_DSN`, the four `R2_*`, `SMTP_{ADDRESS,USERNAME,PASSWORD}`, the Apple
four, `GOOGLE_MAPS_API_KEY` and `TURNSTILE_{SITE,SECRET}_KEY`. Production
refuses to boot without the three `AR_ENCRYPTION_*`, the four `R2_*`, the three
price ids (production_config_guard.rb) and the three Stripe keys (stripe.rb).
`RAILS_MASTER_KEY` comes from `config/master.key` via `.kamal/secrets`.
First deploy on a new server is `setup` not `deploy` (setup is not CI-gated).
Migrations run automatically on boot. To push changed secrets without a
rebuild: `bin/kamal-deploy app boot` (Kamal 2 uploads the env on every boot;
there is no `kamal env push` in Kamal 2).

**Kamal aliases** (deploy.yml:71-76 — `bin/kamal-deploy <alias>`):
`console` · `shell` · `logs` · `dbc` (dbconsole) · `backup`. Note `backup` is
`app exec --reuse` without `--roles`, so it runs once per role (web and job:
two dumps). For one: `bin/kamal-deploy app exec --roles=web --reuse "bin/rails
runner DatabaseBackupJob.perform_now"`. The wrapper passes
ANY args straight to Kamal (`exec … kamal "$@"`), so every built-in works too —
notably **`bin/kamal-deploy rollback [VERSION]`** to revert a bad deploy and
`bin/kamal-deploy app version`.

**A deploy ships the last local COMMIT, not the working tree.** With no
`builder.context` in deploy.yml, Kamal 2 builds from a git clone of the local
repo at HEAD (Kamal::Configuration::Builder#git_clone?), so uncommitted edits do
NOT ship — including a regenerated `config/credentials.yml.enc`: commit it.
`bin/kamal-deploy deploy` also refuses unless HEAD is pushed and CI is green.

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
password manager** (the DR copy). The `AR_ENCRYPTION_*` trio is
**UNRECOVERABLE if lost**: the leftover encrypted 2FA columns (2FA itself was
removed in B11) become unreadable. Keep offline copies.

**master.key was lost (October 2026)** and is regenerated by the relaunch
script: a new `config/master.key` (git-ignored, never committed) and a new
`config/credentials.yml.enc` holding only `secret_key_base`. Regenerating signs
everyone out once and voids emailed links; nothing else lives in credentials.
Keep the new key in the password manager and in `bin/backup-secrets`.

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

## Junk accounts and Turnstile
`bin/rails users:purge_unused` (app/services/unused_accounts.rb) reports accounts
nobody used (dry run by default, ids and dates only, never emails); `CONFIRM=1`
deletes them. Run it in ONE container: `bin/kamal-deploy app exec --roles=web
--reuse "bin/rails users:purge_unused"`. Turnstile (wss-auth) is off until both
`TURNSTILE_*` keys are in `~/.wss-production.env` and the app is rebooted.

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

## Original launch sequence, July 2026 (docs/launch-checklist.md)
For a new server use `bin/relaunch-production` instead.
1. DONE — Cloudflare DNS/SSL Full, GitHub token, R2 bucket+token, Sentry DSN,
   Stripe live keys + 3 prices, Google prod redirect URI.
2. DONE — secrets exported to `~/.wss-production.env`.
3. DONE — first `kamal setup` (Docker on server, Postgres accessory, image, SSL).
4. DONE — smoke test (site loads, signup, R2 upload, `bin/kamal-deploy backup`, logs).
5. DONE — Stripe live webhook endpoint added, `whsec` in secrets.
6. PENDING — SMTP provider (above); watch Sentry day 1; confirm nightly backup;
   uptime monitor on `/up`.

## Restoring a production backup locally — `bin/restore-production-snapshot`
Use when production data is needed on the Mac (the server is gone, or real
decks/users are needed to debug). Input is the R2 bucket downloaded as a
folder: `db-backups/wss_*.sql.gz` plus every Active Storage object at its key.
```sh
bin/restore-production-snapshot tmp/r2-backup                      # newest dump
bin/restore-production-snapshot tmp/r2-backup --dump wss_20261020_090000.sql.gz
bin/restore-production-snapshot tmp/r2-backup --admin-email you@example.com --set-password
```
Needs the Docker stack up (`./wss up`); never reads `~/.wss-production.env`.
It refuses to run if development mail is not `:file` or the local
`STRIPE_SECRET_KEY` is a live key. Then: backs up the current
`wss_development` to `tmp/dev-db-before-restore-<stamp>.sql.gz` → stops web
and jobs → drops/recreates the database and loads the dump (ownership lines
stripped, every other psql error fatal, one transaction) → sets
`ar_internal_metadata.environment` to development, creates the Solid Queue
tables if the dump lacks them, runs `db:migrate` (schema dump goes to `tmp/`,
`db/schema.rb` is not rewritten) → copies blobs into `storage/` (Disk layout,
nothing deleted) and moves blobs from `cloudflare_r2` to `local`, reporting
missing files and checksum mismatches → truncates Solid Queue tables →
restarts, waits for `/up`, prints a summary and the exact commands to reload
the pre-restore backup. Re-runnable. A data-transforming migration that fails
on real data (e.g. two users sharing a `stripe_customer_id`) stops the run
with the error; fix the rows and re-run. Local sign-in afterwards: the
password set by `--set-password`, or a magic link from `tmp/mail`
(`bin/magic-links`); Google is not configured locally.

## Gotchas / traps
- **Piped test runs hide failures** — gate on file + summary text, not pipe
  exit code (above).
- **`DATABASE_HOST` must be `wss-db`** — a host-less prod pg config dials a
  local Unix socket that doesn't exist and the app won't boot.
- **`.kamal/secrets` never holds values** — only `$VAR` refs; forgetting to
  `source ~/.wss-production.env` first deploys with empty secrets.
- **Losing `AR_ENCRYPTION_*` = the leftover encrypted 2FA columns become
  unreadable** (2FA was removed; keep the keys until a migration drops the
  columns). Losing `master.key` only costs a regenerated `secret_key_base`
  (everyone signed out once). Run `bin/backup-secrets` and keep the passphrase
  in a password manager.
- **Never rewrite `127.0.0.1` in deploy.yml**: the db accessory's
  `port: "127.0.0.1:5432:5432"` is what keeps Postgres off the internet. Only
  the server IPs change when the host moves.
- **Never re-add `ALLOW_MISSING_STRIPE`** once live keys are in — it silently
  lets payments break.
- **Jobs must be their own container** (`bin/jobs`); LibreOffice in the web
  container stalls page serving.
- **Mailer silently drops mail** while `SMTP_ADDRESS` is unset — no error,
  magic links just never arrive.

## Google Search Console (verified July 2026)

Property: URL-prefix `https://whiskeysharesociety.com/`, verified by the
`google-site-verification` meta tag in `app/views/layouts/application.html.erb`.
**Removing that tag un-verifies the property** — leave it in the head. The
sitemap (`/sitemap.xml`) is submitted and reading Success; Google re-reads it
periodically, so new decks/societies get picked up without resubmitting.
