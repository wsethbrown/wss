---
name: wss-societies
description: WSS societies — the privacy model, invite links, member management, events/RSVPs, and profile visibility rules. Use for any society, event, or member/role change (the SocietyMembership join table). NOT for paid membership — see wss-membership-model.
---

# WSS Societies

## Naming collision — read first
`SocietyMembership` (this skill's join table: roles `member|officer|admin`,
status active/etc.) is UNRELATED to paid **membership** / Stripe subscription.
"Member of a society" ≠ "paying member." For the paid model see
wss-membership-model.

## The creation paywall (SocietyPolicy#create?)
Creating/running a society is a PAID benefit — `create?` (society_policy.rb:39)
returns true only for `user.admin? || user.has_active_subscription?`. `new?`
aliases `create?`. JOINING a public society stays FREE (see join? below). See
wss-membership-model for the free-vs-paid split.

## The privacy model (every layer enforces it — keep it that way)
- **Scope** (SocietyPolicy::Scope): anonymous → public only; signed-in →
  public + private ones they created or actively belong to. (Once leaked all
  private societies into listings.)
- **show?**: private → creator/manager/global-admin/active member only.
- **join?**: PUBLIC only. Private societies are invite-only — anyone once
  could POST /societies/:id/join past the privacy flag; that hole is closed.
- **Profiles**: a user's society list shows public ones + private ones the
  VIEWER shares with them (fellow members already know); own profile shows
  all. Never list a private membership to an outsider.

## Invites (the only door into a private society)
- societies.invite_token (unique, lazily generated via invite_token!).
- GET /invite/:token → join_by_invite: signed-in + valid token joins (works
  for private — the link IS the invite); already-member and bad-token paths
  redirect gracefully; signed-out → auth first.
- Managers see the invite-link card on the society page; "Generate new link"
  (regenerate_invite) REVOKES all previously shared links.

## Member management (SocietyMembershipsController)
- Guarded by SocietyPolicy#manage_members? (creator, society admins/officers,
  global admin).
- PATCH role: member ↔ officer only. DELETE removes a member.
- **The founder (creator) is untouchable** — no role change, no removal.
- UI: controls inline in the society page Members panel, hidden from
  non-managers.

## Events
- Nested under societies; creating from a society page pre-pins society_id.
- RSVP yes/maybe/no with turbo_stream updates; logs :event_rsvp activity.
- "Table talk" comments (EventComment, owner-approved July 2026): society
  members/organizer/global admin may post (EventPolicy#comment?); window is
  event creation → end_time + 7 days, enforced in the MODEL so it can't be
  bypassed; authors + Event#managed_by? delete. Flat, event-scoped chatter —
  deliberately NOT the rejected forum; don't generalize it into one.
- **Event hosts (owner-approved July 2026):** `events.host_id` (nullable, a
  User). Assigned from the Host card on the event page by `policy(event).update?`
  holders (organizer/society admins) via `PATCH assign_host` — must be an
  ACTIVE society member; blank clears. The host gets EXACTLY two powers:
  the "RSVP replies" sidebar panel (statuses + notes; gate is
  `EventPolicy#view_rsvps?` = managers OR host) and a seat on rsvp_received
  emails (both RSVP paths fan out to [organizer, host].compact.uniq, skipping
  self + muted). NO edit/delete/reassign rights — don't add host to
  update?/managed_by?. This is the member half of the approved deck-reviews
  host field; free-text host_name + events.presentation_id come with that
  feature (see the deck-reviews spec notes) — extend, don't parallel-build.
- Society page sidebar = "Next tasting" card (next event + RSVP link, or a
  schedule prompt for managers). A redundant "Society Stats" card was removed
  deliberately — counts live in the masthead; don't bring it back.

## Deliberate non-features
- Forums/chat: REJECTED — real societies coordinate in their existing group
  chats; an empty in-app forum loses to iMessage. The Forum model was deleted.
- SocietyApplication (apply-to-join flow): model existed, was never built,
  invites replaced the need. Build only if the owner asks.

## Masthead pattern
One unified char masthead (banner-image aware) — there were once two
duplicated header variants with dead links; never fork the header again.
