# Content Security Policy: report-only (B18 / S15)

`config/initializers/content_security_policy.rb` sends `Content-Security-Policy-Report-Only`
on every response. Nothing is blocked. Browsers log what they would have blocked to the
console (and fire a `securitypolicyviolation` event). Do **not** flip
`content_security_policy_report_only` to `false` until the list below is empty.

Policy: `default-src 'self'`; scripts `'self'` + `https://maps.googleapis.com` (injected at
runtime by `location_autocomplete_controller.js`) + `https://challenges.cloudflare.com`
(Cloudflare Turnstile, injected by `turnstile_controller.js` with the page nonce, only when the
`TURNSTILE_*` keys are set) + a per-request nonce; frames `'self'` + `https://challenges.cloudflare.com`
(the Turnstile widget is an iframe); styles `'self'` +
`https:` (Google Fonts) + nonce; images `'self' https: data: blob:`; fonts `'self' https: data:`;
`object-src 'none'`; `base-uri 'self'`; `form-action 'self' https:` (Stripe Checkout redirects);
`frame-ancestors 'self'`; `connect-src 'self'` + Maps. The nonce is `SecureRandom.base64(16)`
per request. The importmap, module preloads and `csp_meta_tag` carry it already: **no
violations from `javascript_importmap_tags` on any page.**

## Checked

Ten pages, headless Chromium against a second dev server, signed out and as the full admin:
`/`, `/membership`, `/contact`, `/auth`, `/presentations`, `/presentations/:id`, `/societies`,
`/societies/:id`, `/reviews`, `/account`, `/admin`, `/admin/presentations`,
`/presentations/:id/present`. Every response carried the header. Violations recorded below
(line numbers are of the rendered HTML).

## What would break if enforced

| # | Directive | Where | Effect if enforced | Fix |
|---|---|---|---|---|
| 1 | `script-src-elem` | Layout timezone cookie script, `layouts/application.html.erb` (every page, ~line 92) | Browser time zone cookie never set; event times fall back to default zone | `javascript_tag nonce: true`, or move to a Stimulus controller |
| 2 | `style-src-elem` | Layout `<style>` block (sticky footer, smooth scroll), every page | Layout rules lost: sticky footer, anchors | Move into `application.css`, or `nonce: true` |
| 3 | `script-src-elem` | `auth/unified.html.erb:159` (`togglePasswordForms`) | **Password sign-in toggle dead** | Stimulus controller |
| 4 | `script-src-attr` | `onclick="togglePasswordForms()"` on `#password-toggle` (`auth/unified.html.erb:75`) | Same: the toggle button does nothing | `data-action` on a Stimulus controller |
| 5 | `script-src-elem` | `societies/new.html.erb:160`, `presentations/present.html.erb:26` (Present mode) | Society form helper and the deck player stop working | Stimulus controllers |
| 6 | `style-src-elem` | `presentations/present.html.erb:6`, `home/index.html.erb:37` (reveal keyframes with ERB timings), `admin/credits/adjust` | Present-mode layout and homepage animation lost | `nonce: true` (timings stay inline) or CSS custom properties |
| 7 | `script-src-attr` | `onchange="this.form.submit()"` on profile image upload (`account/_profile_panel.html.erb:17`), `onchange="this.form.requestSubmit()"` on reviews sort (`reviews/index.html.erb:24`) | Upload and sort no longer auto-submit | Stimulus `auto-submit` action |
| 8 | `script-src-attr` | `onclick` in `admin/credits/adjust`, `admin/credits/index`, `admin/subscriptions/edit` (quick-amount buttons), `subscriptions/plans` (clickable plan card) | Quick-amount buttons and plan-card click stop working | Stimulus |
| 9 | `style-src-attr` | ~21 `style="..."` attributes on `/`, 12 on `/admin`, 2 each on deck page, society page, `/account` | Those inline styles (mostly computed widths, delays and image positions) are dropped | Nonces do not cover attributes. Use classes, CSS custom properties set from a nonced `<style>`, or add `'unsafe-hashes'` |
| 10 | `script-src-elem` (type `application/ld+json`) | JSON-LD in the layout and `presentations/show.html.erb:8` | Not executed, so not blocked in practice: data blocks are exempt from `script-src`. Listed so nobody "fixes" it | None needed |

Also check before enforcing: Turnstile on `/auth` and `/users/sign_up` with the keys set (not
exercised in the browser run: it needs real keys; Cloudflare documents `script-src` and
`frame-src` on `challenges.cloudflare.com` as sufficient). Google Maps (`maps.googleapis.com` scripts, plus `maps.gstatic.com`
images under `img-src https:`) was not exercised in the browser run (needs a Maps key); mail
templates are unaffected (not served by Rails responses).

## To enforce

1. Work through rows 1 to 9, reload the pages above with the console open until silent.
2. Set `config.content_security_policy_report_only = false`.
3. Add `policy.report_uri` and a small endpoint first if you want production reports.
