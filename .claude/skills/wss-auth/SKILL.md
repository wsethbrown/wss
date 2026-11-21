---
name: wss-auth
description: WSS authentication — magic links, Google/Apple OAuth setup and gating, session handling, the removed 2FA and its leftover encrypted columns. Use for sign-in bugs, OAuth config, or anything touching credentials.
---

# WSS Auth

## The unified page (/auth)
One page for everything: Google button, Apple button (only when configured),
magic link (primary method), and optional password sign-in/up toggle.
Devise :sessions module is SKIPPED — sessions are hand-rolled in
AuthController (sign_in adds remember-me handling). Helper routes
new_user_session_path / user_session_path still resolve (aliased in routes).

## Magic links (primary auth)
Auth::MagicLinkService — single-use, HMAC-digested tokens on dedicated
columns, 15-min expiry, deliver_later. Consuming signs in + logs :login
(method: magic_link). PRODUCTION EMAIL IS LIVE (2026-07-17): Resend SMTP
(smtp.resend.com, sending-scoped key in the prod env file), verified domain
send.whiskeysharesociety.com, every sender is
'Whiskey Share Society <noreply@send.whiskeysharesociety.com>' (senders MUST
stay on the verified subdomain or Resend rejects). First prod magic link
verified delivered end-to-end.

New addresses (November 2026, after the junk-account incident): requesting a
link for an email with no account creates NO users row. The pending sign-up
(email + return path) sits in Rails.cache under the hashed token for 15
minutes. Opening the link (GET /magic_links/:token) only renders
magic_links/confirm; the account is created by the POST from its button
(POST /magic_links/confirm, token in the body) via
MagicLinkService.complete_sign_up, which claims the entry with the cache
delete (single use). Why: between August and October a script typed ~89
harvested business addresses into /auth, and corporate mail scanners that
follow every link created an account for each one when the GET did it.
Existing accounts are unchanged: their link signs in on the GET. The visitor
sees the same redirect and flash for known and unknown addresses. Junk
accounts from before the fix: `rake users:purge_unused` (dry run unless
CONFIRM=1).

## Admin invitations (fourth sign-in path)
Auth::InvitationService (admin/invitations_controller, admin/users#resend_invitation,
InvitationsController#show at /invitations/:token). An admin creates the User and
emails a claim link: HMAC-digested single-use token on dedicated invitation columns,
14-day expiry, deliver_later. Accepting signs the invitee in once; afterwards they use
magic link or Google like everyone else. Same token discipline as magic links — never
log the raw token.

## Google OAuth
- Strategy registers with real env creds in production; with DUMMY fallbacks
  in dev/test (so routes + OmniAuth test mode always work). The button only
  renders when real creds exist (AuthHelper#google_sign_in_available?; in dev
  a dashed hint shows instead).
- Console (console.cloud.google.com, project "Whiskey Share Society", client
  "WSS Site"): Google shows client secrets ONCE at creation — if lost, Add
  Secret creates a second (two max; delete lost ones). Redirect URIs must
  include each environment's /users/auth/google_oauth2/callback.
- Users::OmniauthCallbacksController#handle_auth → User.from_omniauth
  (links by provider/uid, then by email if no provider set). A changed uid for
  the same provider on an existing email is rebound and logged at warn
  ("OAuth uid rebind", ids only). The Google strategy (omniauth-google-oauth2
  1.2.2) exposes auth.info.email_verified, and auth.info.email is already nil
  unless Google reports email_verified true, so email linking only sees verified
  addresses.

## Apple (LIVE in production since July 2026)
Strategy registers ONLY when all four APPLE_* env vars exist; they are set in
~/.wss-production.env (and the encrypted secrets backup), so prod renders the
Apple button; dev/test stay unconfigured (the 9 Apple tests keep skipping,
Apple forbids localhost return URLs, verify on prod). Portal facts: Team ID
2WUB78295H; Services ID com.whiskeysharesociety.web (= APPLE_CLIENT_ID) with
domain whiskeysharesociety.com + return URL /users/auth/apple/callback; key
"WSS Sign in with Apple 2026" id WYKKT43BGN. The ORIGINAL leaked key
(364BWT474N, once committed to the repo) was REVOKED 2026-07-17.
Verified working end-to-end 2026-07-17. THREE production bugs, don't regress:
(1) APPLE_PRIVATE_KEY is stored SINGLE-LINE with \n escapes (kamal's docker
env-file transport cannot carry multiline values AND doubles backslashes);
the devise.rb initializer normalizes with gsub(/\\+n/, newline) — any escape
depth. (2) /users/auth/failure must stay routed (params-based #failure action)
or provider errors render a bare 404. (3) Apple's callback is a CROSS-SITE
form POST: the OmniAuth setup hook sets the session cookie SameSite=None for
the apple phases only, else the state check fails csrf_detected. Hide My Email
creates @privaterelay.appleid.com users (expected; matching real email links
to the existing account instead).

## 2FA — REMOVED (B11, November 2026)
- It was half-built: no challenge step, so enabling it broke password sign-in
  while magic link, OAuth and invitations ignored it, and there was no UI to
  enable it. The owner approved removal. There is no 2FA on any sign-in path.
- The endpoints (account/setup_2fa, enable_2fa, disable_2fa,
  regenerate_backup_codes), the AuthController branch and the User helpers are
  gone. The rotp and rqrcode gems are now unused (Gemfile left alone).
- The columns otp_enabled, otp_secret_key, backup_codes are KEPT in the table
  and listed in User.ignored_columns until a later migration drops them. Some
  rows still hold data encrypted with the AR_ENCRYPTION_* keys, so keep those
  keys configured and backed up until the columns are dropped. Do not
  regenerate keys against a DB with encrypted data.
- If 2FA comes back, build it across all four sign-in paths, not just password.

## Login activity
All three methods log ActivityLog :login with method metadata (password /
magic_link / google / apple). If you add an auth path, log it too.
