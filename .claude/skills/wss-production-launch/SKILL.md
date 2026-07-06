---
name: wss-production-launch
description: The WSS production launch runbook — current deploy state, host/storage/email decisions, Stripe/Google live config, secrets, and the ordered launch sequence. Use for anything deploy- or production-related.
---

# WSS Production Launch Runbook

## Current state (honest)
NOT yet deployed anywhere. config/deploy.yml is STOCK Kamal template
(placeholder IP, example.com). No production SMTP. ActiveStorage is
local-disk. Stripe is live-verified in TEST MODE only. The owner has no host
yet (as of July 2026).

## Architecture decisions (made with owner context — don't relitigate)
- **Host**: small VPS (Hetzner CX22-class or DO $6–12) + Kamal — the repo is
  already built for it. Render is the fallback if owner wants zero server ops
  (~$21/mo).
- **Storage**: Cloudflare R2 (owner already uses it elsewhere; zero egress
  fees matter for deck downloads + slide images). Wire an :r2 service in
  config/storage.yml (S3-compatible: endpoint, access_key_id, secret,
  bucket, region auto) and set config.active_storage.service = :r2 in
  production.rb.
- **Email**: Resend (free tier 3k/mo) via SMTP settings + 
  action_mailer.default_url_options host. **BLOCKING: magic links are the
  primary sign-in and silently break without this.**

## Secrets that must reach production (via .kamal/secrets, NEVER committed)
RAILS_MASTER_KEY · DATABASE/POSTGRES password · STRIPE live secret key +
publishable + webhook secret + 3 live price IDs · GOOGLE_CLIENT_ID/SECRET ·
AR_ENCRYPTION_* (the THREE 2FA keys — same values as dev if migrating data,
or fresh for a clean prod DB; owner must have them backed up) · R2 keys ·
RESEND/SMTP key · APPLE_* when renewed.

## Owner-only steps (cannot be done by an agent)
1. Create host account; server: Ubuntu 24.04, smallest tier, add SSH key;
   provide IP.
2. R2 bucket + API token. 3. Resend account + API key + domain DNS record.
4. Stripe: flip live, live keys, recreate 3 prices, dashboard webhook
   endpoint → https://DOMAIN/webhooks/stripe (yields prod whsec). Enable
   Apple Pay/payment methods in dashboard settings.
5. Google console: add production origin + redirect URI
   (https://DOMAIN/users/auth/google_oauth2/callback), publish consent
   screen. 6. DNS: domain → server IP (Cloudflare SSL mode "Full").
7. Approve Terms/Privacy page copy (must exist before charging strangers).

## Agent steps, in order (once owner delivers the above)
1. storage.yml :r2 + production.rb service switch + SMTP config + mailer host.
2. Rewrite config/deploy.yml: image/registry (ghcr.io), server IP, domain
   proxy ssl, **jobs server role running bin/jobs** (slide rendering must be
   its own container in prod exactly like dev), Postgres accessory with
   volume, env secret list. The Dockerfile (Debian) already includes
   libreoffice-impress + poppler-utils — required, don't slim it out.
3. kamal setup (first deploy) → db:prepare + queue schema → create owner
   admin user.
4. Smoke test ON PROD: magic-link email arrives · Google sign-in · deck
   import → slides render in jobs container · live-mode checkout reaches
   Stripe · webhook fulfillment grants access (StripeEvent row) · Present
   mode · society invite link.
5. Backups: nightly pg_dump (cron or Kamal accessory) shipped to R2.
6. Post-launch: revoke the leaked Apple key when membership renews; delete
   the lost Google secret (****JW_R) in console.

## Cost reality check
VPS ~$6 + R2 ~$0 + Resend $0 + domain = **≈$6–12/month** until real scale.
