# WSS Launch Runbook

Server: Hetzner `wss-prod` — `178.156.251.37` (resize to CPX21 if not done).
Everything below the "Your accounts" section is one terminal session on your Mac.

## 1 · Your accounts (one-time clicking)

- [ ] **Cloudflare DNS** — add `whiskeysharesociety.com` to Cloudflare (free plan).
      Records: `A @ → 178.156.251.37` (proxied ☁️ on) and `A www → 178.156.251.37`
      (proxied). SSL/TLS mode: **Full**.
- [ ] **GitHub token** — github.com → Settings → Developer settings → Personal
      access tokens (classic) → scopes: `write:packages`, `read:packages`.
      This is `KAMAL_REGISTRY_PASSWORD`.
- [ ] **R2** — Cloudflare dashboard → R2 → Create bucket `wss-production`.
      Then R2 → Manage API Tokens → Create token (Object Read & Write, this
      bucket). Note the Access Key ID, Secret, and the account endpoint
      (`https://<account-id>.r2.cloudflarestorage.com`).
- [ ] **Sentry** — sentry.io → new Rails project → copy the DSN.
- [ ] **Stripe live** — dashboard in Live mode: copy live secret + publishable
      keys; create the three live Prices (monthly/quarterly/yearly) and copy
      their price IDs. Webhook comes AFTER first deploy (step 5).
- [ ] **Google OAuth** — console.cloud.google.com → the WSS OAuth client →
      add authorized redirect URI:
      `https://whiskeysharesociety.com/users/auth/google_oauth2/callback`
- [ ] **SMTP provider** (password resets won't send without it) — e.g. Resend
      or Postmark, free tiers fine. Verify the domain, note SMTP host,
      username, password. Can be done post-launch; auth emails are the cost.

## 2 · Export secrets in your terminal

`.kamal/secrets` pulls from your shell env — nothing is stored in git.
In the terminal you'll deploy from (values in quotes, no spaces around `=`):

```sh
export KAMAL_REGISTRY_PASSWORD="ghp_..."
export WSS_DATABASE_PASSWORD="$(openssl rand -hex 24)"   # SAVE THIS somewhere safe
export AR_ENCRYPTION_PRIMARY_KEY="..."        # ┐
export AR_ENCRYPTION_DETERMINISTIC_KEY="..."  # ├ same values as dev .env
export AR_ENCRYPTION_KEY_DERIVATION_SALT="..."# ┘
export GOOGLE_CLIENT_ID="..." GOOGLE_CLIENT_SECRET="..."
export STRIPE_SECRET_KEY="sk_live_..." STRIPE_PUBLISHABLE_KEY="pk_live_..."
export STRIPE_MONTHLY_PRICE_ID="price_..." STRIPE_QUARTERLY_PRICE_ID="price_..." STRIPE_YEARLY_PRICE_ID="price_..."
export STRIPE_WEBHOOK_SECRET=""               # filled in at step 5
export SENTRY_DSN="https://...ingest.sentry.io/..."
export R2_ENDPOINT="https://<account-id>.r2.cloudflarestorage.com"
export R2_ACCESS_KEY_ID="..." R2_SECRET_ACCESS_KEY="..." R2_BUCKET="wss-production"
export SMTP_ADDRESS="" SMTP_USERNAME="" SMTP_PASSWORD=""   # fill when provider chosen
```

Tip: put these in a `~/.wss-production.env` file (chmod 600, OUTSIDE the repo)
and `source ~/.wss-production.env` before deploying.

## 3 · First deploy

```sh
cd ~/Documents/Coding/wss
gem install kamal            # once, on your Mac (or: bundle exec kamal ...)
kamal setup                  # installs Docker on the server, boots Postgres
                             # accessory, builds + pushes image, deploys, SSL
```

First build cross-compiles amd64 from your Mac — expect 10–20 minutes.
Migrations run automatically via bin/docker-entrypoint (db:prepare).

## 4 · Smoke test

- [ ] https://whiskeysharesociety.com loads with a padlock
- [ ] Sign up a fresh account (email + Google)
- [ ] `bin/kamal console` → `User.count` works
- [ ] Upload an image on a review → appears (proves R2)
- [ ] `bin/kamal backup` → then check R2 bucket for `db-backups/...`
- [ ] `bin/kamal logs` shows lograge lines

## 5 · Stripe live webhook (after the site is up)

Stripe dashboard (Live) → Developers → Webhooks → Add endpoint:
`https://whiskeysharesociety.com/webhooks/stripe` — subscribe to the same
events as the dev endpoint. Copy the signing secret, then:

```sh
export STRIPE_WEBHOOK_SECRET="whsec_..."
kamal env push && kamal app boot     # refresh env with the new secret
```

- [ ] Real end-to-end purchase with a live card (refund yourself after)

## 6 · Post-launch

- [ ] Watch Sentry for the first day's exceptions
- [ ] Confirm the nightly backup landed next morning (R2 → db-backups/)
- [ ] Uptime monitor (e.g. UptimeRobot free) pointed at https://whiskeysharesociety.com/up
