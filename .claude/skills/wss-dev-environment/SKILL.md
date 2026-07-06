---
name: wss-dev-environment
description: Run, restart, and debug the WSS dev stack — Docker services, the ./wss CLI, environment reload gotchas, and known failure signatures. Use when the app won't start, behaves stale, or a container dies.
---

# WSS Dev Environment

## The stack (docker-compose.yml)
- **web** — Rails via foreman (Procfile.dev: `web` puma on :3000 + `css`
  tailwindcss:watch). http://localhost:3000, plain HTTP.
- **jobs** — SEPARATE container running `rake solid_queue:start`. Slide
  rendering (LibreOffice) happens here ONLY. It has `restart: unless-stopped`
  because soffice can crash it; that's by design.
- **db** — Postgres 15 (wss_development; test uses wss_test on same server).
- **redis** — present but app cache/queue are DB-backed (Solid*).

## Daily commands (./wss CLI, Compose v2)
    ./wss up | down | restart | status
    ./wss logs [web|jobs]     # follow logs
    ./wss console             # Rails console
    ./wss test                # full suite against test DB
    ./wss db migrate|seed|reset|console

## CRITICAL gotcha: .env changes need force-recreate
`docker compose restart web` does NOT re-read .env. After ANY .env change:
    docker compose up -d --force-recreate web jobs
Symptom of forgetting: new keys "not working", old behavior persists.

## Dev-only cache gotcha
Dev cache is per-process memory. `Rails.cache.delete` from a runner does NOT
clear the web process's cache (bit us with cached Stripe fallback pricing).
Restart web to drop in-process cache.

## Known failure signatures (match these before debugging blind)
- **web container exits 0 with "sending SIGTERM to all processes"** — one
  foreman child died (usually memory pressure) and foreman killed the rest.
  If it correlates with deck imports: someone ran LibreOffice in the web
  container. Renders belong in jobs (DeckSlideRenderJob).
- **ActiveStorage::IntegrityError on save with attachments** — an IO was read
  twice (checksum of one read, upload of another). Rule: read uploads ONCE
  into memory, give every consumer its own StringIO. See
  Admin::PresentationsController#import for the pattern.
- **Admin pages render unstyled** — a stylesheet_link_tag references a
  nonexistent bundle. Valid names: "tailwind", "application".
- **GET returns 204 No Content** — controller action exists but its template
  is missing (Rails renders nothing). Add the view.
- **position: sticky doesn't stick** — see wss-design-system (ancestor
  overflow/height traps).
- **"log writing failed. Resource deadlock avoided"** in jobs logs — harmless
  noise from two containers sharing log/development.log.
- **Events/records silently not created with no error** — check model
  validation + a rescue swallowing it (ActivityLog's type-inclusion validation
  silently discarded events for months).

## Dev data facts
- test@example.com (password login) and wsethbrown@gmail.com (Google) both
  have is_admin: true — dev convenience, granted manually, not seeded.
- Local Stripe keys in .env are REAL TEST-MODE keys for the "Whiskey Share
  Society sandbox". The stripe CLI listener must be started with
  `--api-key $STRIPE_SECRET_KEY` or it may pair to the wrong account and
  webhooks silently never arrive.
- AR_ENCRYPTION_* keys in .env encrypt 2FA columns — see wss-auth. NEVER
  regenerate them casually.
