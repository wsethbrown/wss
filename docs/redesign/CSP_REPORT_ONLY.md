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
| 2 | `style-src-elem` | ~~Layout `<style>` block (sticky footer, smooth scroll), every page~~ | **Fixed (issue #46, November 2026):** the rules are in `app/assets/stylesheets/layout.css`, linked from `layouts/application.html.erb` only. Before, the block had no nonce, so it reported on every full load and again on every Turbo Drive visit (Turbo parses the next page under the current policy) | Done |
| 3 | `script-src-elem` | `auth/unified.html.erb:159` (`togglePasswordForms`) | **Password sign-in toggle dead** | Stimulus controller |
| 4 | `script-src-attr` | `onclick="togglePasswordForms()"` on `#password-toggle` (`auth/unified.html.erb:75`) | Same: the toggle button does nothing | `data-action` on a Stimulus controller |
| 5 | `script-src-elem` | `societies/new.html.erb:160`, `presentations/present.html.erb:26` (Present mode) | Society form helper and the deck player stop working | Stimulus controllers |
| 6 | `style-src-elem` | `presentations/present.html.erb`, and the homepage's three blocks (`home/index`, `home/_story_glass`, `home/_story_frame`) on a Turbo Drive visit | **Fixed (issue #46, November 2026).** None of these pages sends a `<style>` element now: the CSS is in stylesheets served from `'self'` (`app/assets/stylesheets/present.css`, and `home/index.css`, `home/story_frame.css`, `home/story_glass.css`, each linked from its own view with `stylesheet_link_tag`). The homepage blocks used to carry the request nonce, which covered only a full page load: the policy in force is the first response's, and a Turbo Drive visit brought `<style nonce>` with another request's nonce, reported twice per block (once when Turbo parses the response, once when it copies the head). Measured in Chromium, `/membership` to `/` by the nav link: 7 `style-src-elem` reports before (3 blocks x 2, plus the layout block), 0 after (also 0 on the way back by the browser's Back button); 0 on full loads of `/`, `/membership`, `/contact`, `/auth`, `/presentations`, `/societies` and `/reviews`. The one computed part, the hero reel's keyframes (their offsets depend on how many slides it shows), is now one keyframe pair per length from 2 to `HomeHelper::HERO_REEL_MAX` (12) in `home/index.css`, chosen by a class (`.reel--3`, `.ticks--reel-3`); a deck previewing more slides shows the first 12 in the hero reel. A session-derived nonce was the alternative: rejected, since it ties the nonce to the session, needs a full page load at every sign-in and sign-out, and keeps 40KB of CSS uncached in every homepage response. `admin/credits/adjust` (named here before) has no `<style>` block. The admin-only design studies (`home/index_next.html.erb`, `index_next2`, `index_next4`, at `/?design=next...`) still carry un-nonced `<style>` blocks: studies kept for reference, not live pages | Done for live pages; the studies would need the same move if they are ever kept |
| 7 | `script-src-attr` | `onchange="this.form.submit()"` on profile image upload (`account/_profile_panel.html.erb:17`), `onchange="this.form.requestSubmit()"` on reviews sort (`reviews/index.html.erb:24`) | Upload and sort no longer auto-submit | Stimulus `auto-submit` action |
| 8 | `script-src-attr` | `onclick` in `admin/credits/adjust`, `admin/credits/index`, `admin/subscriptions/edit` (quick-amount buttons), `subscriptions/plans` (clickable plan card) | Quick-amount buttons and plan-card click stop working | Stimulus |
| 9 | `style-src-attr` | 28 `style="..."` attributes on `/` (counted November 2026, issue #46) (the hero reel's delays, avatars, the palate wheel's `--from`/`--d`; the story frame sets its styles from JS, which the policy allows), 12 on `/admin`, 2 each on deck page, society page, `/account` | Those inline styles (mostly computed widths, delays and image positions) are dropped | Nonces do not cover attributes. Use classes (the hero reel's per-length classes in `home/index.css` show the pattern), CSS custom properties set from JS, or add `'unsafe-hashes'`. Not custom properties set from a nonced `<style>`: that fails on a Turbo Drive visit, as row 6 did |
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
