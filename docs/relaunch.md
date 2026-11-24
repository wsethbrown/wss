# Relaunching production on a new server

The production server (Hetzner, 178.156.251.37) is gone; the site has been down
since about 27 October 2026. Everything else survived: the domain on Cloudflare,
the R2 bucket (every upload plus 14 nightly database dumps), the secrets file on
the Mac, Stripe, Resend, Google sign-in and the GitHub image registry.

One script does the relaunch. It explains each step, does it, checks it, and
stops with a plain fix when something is wrong. Running it again is always safe:
finished steps are detected and skipped.

## Before you start

- **The new server.** OVHcloud US VPS-2 (4 vCores, 8 GB, 75 GB, Ubuntu 24.04),
  and its IPv4 address from the control panel or the welcome email. When ordering,
  add your Mac's SSH public key if offered (`cat ~/.ssh/id_ed25519.pub`, paste it).
  If you did not, run this once with the password OVHcloud emailed you:
  `ssh-copy-id ubuntu@<the IP>`.
- **The Mac:** Docker Desktop running; the repo at `~/Documents/Coding/wss`,
  clean and pushed; the dev stack able to start (`./wss up` has worked before).
- **`~/.wss-production.env`** (private, `chmod 600`). The script lists by name
  anything missing.
- **The downloaded bucket:** `~/Documents/wss/tmp/r2-backup` or
  `~/Documents/WSS-R2-backup-2026-11-21` (the script looks in both).
- **Logins in a browser:** Cloudflare (DNS and Turnstile) and, for the after-care
  checks, Stripe, Resend and Sentry.
- About an hour. The first build alone takes 10 to 25 minutes.

## The one command

```sh
cd ~/Documents/Coding/wss
bin/relaunch-production
```

Other forms: `bin/relaunch-production --help` (lists the steps),
`--dry-run` (checks and says what it would do, changes nothing),
`--from <step>` (resume, e.g. `--from dns`), `--only <step>` (one step).

## What each step does

1. **preflight**: Docker running, repo clean and on GitHub, the secrets file
   private and complete, an SSH key, `gh` (needed later for normal deploys).
   Changes nothing.
2. **server**: asks for the IP and logs in. If only the `ubuntu` login works
   (OVHcloud's default), it asks, then copies your key to root (Kamal logs in as
   root). Checks Ubuntu, memory and disk; adds 2 GB swap; turns on the firewall
   with only ports 22, 80, 443 open.
3. **config**: puts the new IP in `config/deploy.yml` (web, jobs, database),
   shows the change, commits and pushes it after asking.
4. **masterkey**: `config/master.key` was lost, so it makes a new key and a new
   `config/credentials.yml.enc` (it only holds `secret_key_base`). Effect:
   everyone is signed out once, and links already emailed stop working. Nothing
   else. The old file is kept in a temp folder; the new `.enc` is committed (the
   key never is). Then store the key: `bin/backup-secrets`, and paste the key into
   your password manager.
5. **database**: installs Docker on the server, starts Postgres alone, and loads
   a nightly dump (newest by default; you can pick an older one) in one
   transaction. Prints users, decks, ownerships and ledger rows. It will not
   overwrite a database that already has data unless you type
   `REPLACE PRODUCTION DATA`.
6. **deploy**: `kamal setup`: builds the app, starts it with HTTPS. Migrations
   run on the first boot. Waits until the app answers on the server itself
   (before DNS moves). On failure it shows the app's log with secrets masked.
7. **purge**: removes the junk accounts a script created through the sign-up
   form (about 89, created 3 Aug to 14 Oct). Shows a dry run first; deletes only
   after you type `DELETE <n> ACCOUNTS`. If the count is far from 89 it says so:
   stop and ask.
8. **turnstile**: the "are you human" check on sign-up. Tells you the four
   Cloudflare clicks, asks for the two keys (typing is hidden), saves them in
   the secrets file and restarts the app. You can skip it, but sign-up has no bot
   check until it is done.
9. **dns**: tells you exactly what to change in Cloudflare (the two A records to
   the new IP, proxied; SSL mode Full), then waits until https works.
10. **aftercare**: smoke test of the main pages, a test sign-in email to your
    own address, the jobs container and nightly backup schedule, a backup taken
    now and checked in R2, and the list of things to look at by hand (Stripe
    webhook failures from the downtime, Resend bounces, Sentry, uptime monitor).

## When a step fails

The script stops and prints three lines: what went wrong, the fix, and the
command to continue (`bin/relaunch-production --from <step>`). Do the fix, run
that command. Nothing is half-done: the database load is all-or-nothing, and
each step re-checks the real state before doing anything.

Common ones:

| Message | What to do |
|---|---|
| cannot log in as root or ubuntu | Check the IP; run `ssh-copy-id ubuntu@<IP>` with OVHcloud's password |
| missing values: NAME ... | Add `export NAME='value'` lines to `~/.wss-production.env` |
| could not run Ruby in the Docker dev stack | `./wss up` once, then re-run |
| kamal setup failed | Read the first red lines of Kamal's output; often a registry token (`KAMAL_REGISTRY_PASSWORD`) or an SSH problem |
| the app did not answer /up | The masked log shows why: usually a missing variable or a failed migration |
| https does not answer yet | Check both Cloudflare records say the new IP and are Proxied, SSL mode Full |

After the relaunch, everyday deploys are the usual
`source ~/.wss-production.env && bin/kamal-deploy deploy`; roll back with
`bin/kamal-deploy rollback`; logs with `bin/kamal-deploy logs`.

## Monthly cost

| | Cost |
|---|---|
| OVHcloud VPS-2 | the price on your order (under $20 a month) |
| Cloudflare (DNS, proxy, Turnstile) | free plan |
| Cloudflare R2 (uploads + backups) | free up to 10 GB stored |
| Resend (email) | free up to 3,000 emails a month (100 a day) |
| Sentry (error alerts) | free developer plan |
| GitHub image registry | within the GitHub plan |
| Stripe | per-payment fees only |
| Domain | the yearly renewal at the registrar |

Google Maps (place autocomplete) has a $10 budget alert; see `wss-backlog`.
