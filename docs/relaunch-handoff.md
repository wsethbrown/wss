# Handoff: relaunching the live site (for a Claude session on the owner's Mac)

Written 22 November 2026 by the cloud session that did the preceding work. That session
cannot reach the owner's Mac or browser, which is why this is being handed over. Read this
first, then `CLAUDE.md`, `.claude/skills/wss-orientation`, `.claude/skills/wss-production-launch`
and `docs/relaunch.md`.

## The goal

Get whiskeysharesociety.com working again on a new server for no more than $20 a month,
keeping the domain. The owner has asked for the browser steps to be driven for them where
possible.

## Where things stand

- **Production is down.** The old Hetzner server (178.156.251.37) is gone; the site has been
  down since about 27 October 2026.
- **What survived:** the domain on Cloudflare; the Cloudflare R2 bucket with every upload and
  14 nightly database dumps (newest `db-backups/wss_20261027_090000.sql.gz`); the secrets file
  `~/.wss-production.env`; Stripe (live), Resend, Google OAuth, GHCR.
- **Lost:** `config/master.key`. The app uses credentials only for `secret_key_base`, so the
  key and `config/credentials.yml.enc` can be regenerated. Sign-ins and signed links reset;
  nothing else is affected.
- **On the Mac:** the repo is at `~/Documents/wss`, running in Docker (`./wss up`), with the
  27 October production data restored into local development. A copy of the R2 bucket is at
  `~/Documents/wss/tmp/r2-backup` and `~/Documents/WSS-R2-backup-2026-11-21`.
- **Code:** everything is on branch `claude/sleepy-thompson-wfneis`, pull request
  wsethbrown/wss#39 (draft, CI green at the time of writing). It is NOT merged to `main`. The
  relaunch should deploy this work. Merging is the owner's decision; ask before merging.

## The chosen server

OVHcloud US, plan **VPS-2**: 4 vCores, 8 GB RAM, 75 GB NVMe, Ubuntu 24.04, a US data centre,
about $8.50–$10 a month. Order page: https://us.ovhcloud.com/vps/ . Confirm the price on the
page. Hetzner's US prices rose to about $38–$74 a month in 2026, which is why it is not used.
OVH's default login is user `ubuntu` with sudo, not root; Kamal here deploys as root.

## What you should do

1. **Order the server (browser).** Drive the OVH order form with the owner watching. The
   owner creates the account, enters payment details and confirms the purchase themselves:
   never type a card number, a password or a one-time code, and never click the final
   pay button for them. Add the Mac's public SSH key if the form offers it
   (`pbcopy < ~/.ssh/id_ed25519.pub`, or `id_rsa.pub`; create one with `ssh-keygen -t ed25519`
   if neither exists). Note the server's IPv4 address when it is ready.
2. **Pull the code.** `git fetch origin && git checkout claude/sleepy-thompson-wfneis && git pull`.
3. **Run the relaunch script.** `bin/relaunch-production` is an interactive wizard that checks
   the Mac and the server, points `config/deploy.yml` at the new address, regenerates the
   master key, restores the 27 October dump into the new database, deploys with Kamal, removes
   the junk accounts, sets up the sign-up human check and walks through the DNS change.
   Both `bin/relaunch-production` and `docs/relaunch.md` are on the branch (`bin/relaunch-production --help` lists the steps). The script was tested
   against stand-ins only, never against a real server or Kamal, so expect to debug it. It is
   written to be re-run from any step.
4. **Cloudflare (browser), when the script asks.**
   - Turnstile: account sidebar → Turnstile → Add widget → hostname `whiskeysharesociety.com`,
     mode Managed. The script prompts for the site key and the secret key.
   - DNS: A records for the apex and `www` pointed at the new address, proxied, SSL mode Full.
     The owner signs in to Cloudflare themselves.
5. **After it is up:** confirm sign-in works with the owner's own account, check the Resend
   dashboard for bounces and complaints since August, and confirm the nightly backup runs.

## Things that must be true before the site takes sign-ups

- **Junk accounts removed.** Production's 27 October data contains about 89 accounts created
  between 3 August and 14 October 2026 by mail scanners opening magic links that a bot
  requested. `bin/rails users:purge_unused` reports them (dry run by default; `CONFIRM=1`
  deletes; it prints ids and dates, never addresses). It was run on the owner's local copy and
  deleted exactly 89. If production's dry run reports a very different number, stop and ask.
- **Sign-up hardening deployed.** On this branch a new address gets no account until a person
  presses a button on the confirmation page, and the Turnstile check guards the magic-link
  form and password sign-up once both `TURNSTILE_SITE_KEY` and `TURNSTILE_SECRET_KEY` are set.

## Rules that apply to you

- **Secrets:** never print, log or paste the contents of `~/.wss-production.env`,
  `config/master.key`, or any key or token. Check that variables exist by name only.
- **Customer data:** real customers' data is on this Mac. Do not print email addresses or
  send them anywhere. Development mail goes to `tmp/mail` only; the local Stripe key must be a
  test key.
- **Money and logins are the owner's:** purchases, card details, passwords, two-factor codes,
  and the final confirmation of anything that costs money.
- **Confirm before** anything destructive or outward-facing: wiping a database, deleting
  accounts, changing DNS, merging the pull request, deploying.
- **House rules** in `CLAUDE.md` apply: tests first, logging with ids and never secrets, never
  write `users.credits`, commit and push finished work, push only to this branch.
- **How the owner likes to work:** short, exact instructions; one command at a time; say
  plainly when something does not exist yet. They are not a command-line person, and earlier
  multi-step terminal instructions in this project went badly.

## Other work in flight (not part of the relaunch, for context)

- **Decks.** Four decks are rebuilt in the new look with sources in `tools/decks/sources/` and
  `tools/decks/examples/`: Mint Julep, Whisky From Japan (Hakata), A Story Someone Else Wrote
  (Value vs. Prestige), and The Rye From Lawrenceburg. The owner has approved the look and the
  rewritten slide text of the first three. Skills: `wss-deck-creation`, `wss-deck-outline`,
  `wss-deck-speaker-notes`. A slate of 30 story candidates is in `tools/decks/SLATE.md`,
  awaiting the owner's picks.
- **Keynote cannot open the built `.pptx` files** ("The file format is invalid"). They open in
  Google Slides and LibreOffice. Cause unknown. Seven probe files were sent to the owner to
  isolate it; results are outstanding. One fault is already fixed (the slide-size label). A
  session on the Mac can test this directly: build a deck with
  `python3 -I tools/decks/build.py tools/decks/sources/mint-julep <out dir>` and open the
  result in Keynote, then bisect. Do not put the decks in front of customers until this is
  solved.
- **Admin deck pages.** A review is in `tmp/review/admin-decks/REVIEW.md` on the cloud side
  (not in git). Built and on the branch: the re-render crash fix; uploading a deck package as
  a zip from the admin, including "Replace with a package" on an existing deck (keeps price,
  published state and owners); unpublished decks staying open to their owners; and a guard
  against publishing at $0. The three redone decks replace the live ones through that upload
  once the Keynote problem is solved.
- **Open owner decisions:** merging the pull request; the deck name (Value vs. Prestige / A
  Story Someone Else Wrote / Value vs Hype); whether the bottle photos in that deck are cleared
  for use; whether free decks should exist; what the public "story" text on a deck page should
  be; deck pricing; which stories to build from the slate.
