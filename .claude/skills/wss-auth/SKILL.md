---
name: wss-auth
description: WSS authentication — magic links, Google/Apple OAuth setup and gating, 2FA encryption keys, session handling. Use for sign-in bugs, OAuth config, or anything touching credentials.
---

# WSS Auth

## The unified page (/auth)
One page for everything: Google button, Apple button (only when configured),
magic link (primary method), and optional password sign-in/up toggle.
Devise :sessions module is SKIPPED — sessions are hand-rolled in
AuthController (sign_in adds 2FA + remember-me handling). Helper routes
new_user_session_path / user_session_path still resolve (aliased in routes).

## Magic links (primary auth)
Auth::MagicLinkService — single-use, HMAC-digested tokens on dedicated
columns, 15-min expiry, deliver_later. Consuming signs in + logs :login
(method: magic_link). PRODUCTION DEPENDS ON EMAIL DELIVERY — no SMTP
configured yet (see wss-production-launch); magic links silently break in
prod until that's done.

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
  (links by provider/uid, then by email if no provider set).

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

## 2FA (TOTP + backup codes)
- Columns otp_secret_key + backup_codes are ENCRYPTED at rest (ActiveRecord
  encryption, `encrypts` in User). Keys = AR_ENCRYPTION_PRIMARY_KEY /
  _DETERMINISTIC_KEY / _KEY_DERIVATION_SALT in .env.
- **LOSING THESE KEYS = LOSING ALL 2FA SECRETS.** They must be backed up
  (owner's password manager) and provided to production as deploy secrets.
- support_unencrypted_data is on (pre-encryption rows readable). Never
  regenerate keys against a DB with encrypted data.

## Login activity
All three methods log ActivityLog :login with method metadata (password /
magic_link / google / apple). If you add an auth path, log it too.
