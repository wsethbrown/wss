---
name: wss-admin
description: WSS admin panel — structure, layout traps, credit-adjustment rules, and the activity-tracking decisions. Use for admin UI changes or admin-reported issues.
---

# WSS Admin

## Structure
Char sidebar shell (layouts/admin.html.erb): Dashboard · Decks · Users ·
Subscriptions · Credits (+ /transactions ledger view) · Activity · Analytics.
Admin = users.is_admin (User#admin?). No UI exists to grant/revoke admin —
console only (deliberate until roles are designed).

## Layout traps
- Fixed sidebar + `main.ml-60.min-w-0`. NEVER flex-1 on main (overflows the
  viewport by the 240px sidebar width — clipped buttons/columns).
- Stylesheets: "tailwind" + "application" (a `:app` typo once shipped the
  whole panel unstyled).
- EasyMDE CSS is CDN-linked in the admin layout head.

## Rules with teeth
- **Credits are never edited on the user form.** The edit page shows balance
  read-only + a link to Credits→adjust (ledger write). :credits must stay OUT
  of user_params.
- Deck show page renders the story via render_markdown (never simple_format /
  raw dumps), slides as an order(:id) grid, recommendations as a parsed
  table, and a COMPLETE file inventory (every slot: filename+size or "not
  uploaded").
- Admin deck table: title cell truncates (max-w-xs); whitespace-nowrap on it
  once pushed Actions off-screen.

## Activity tracking (decision record — implemented)
ActivityLog is CURATED, not a firehose:
- Logged: login/logout (all auth methods), purchases, credits used/added,
  subscription created/canceled/paused/resumed, society join/leave,
  event RSVPs, profile updates.
- NOT logged (removed deliberately): presentation_viewed (was >half the
  table, per-view IP+UA, unused), downloads (DownloadLog is the single
  download record; download_count column also exists).
- **Trap**: ACTIVITY_TYPES inclusion validation SILENTLY discards unknown
  types (logger swallows errors). Adding a new log_activity call ⇒ add the
  type to ActivityLog::ACTIVITY_TYPES in the same commit, or it never
  records.
- IP/UA live in dedicated columns only (not duplicated into metadata JSON).
