# Programme hand-over — 2026-11-19

Branch `claude/redesign-programme`, draft PR wsethbrown/wss#37 against
`claude/sleepy-thompson-wfneis`. Every task in `TASKS.md` is done except the
two blocked on the owner (B11, B12). Final gates: `1172 runs, 4143 assertions,
0 failures, 0 errors, 10 skips` (the skips are the Apple OAuth tests);
`bin/rubocop` clean; Brakeman 0 errors with one warning, the Rails 8.0 end-of-life
notice (fixed by #36). axe found no serious or critical issues on the main pages:
36 of 36 page-and-width runs passed. 71 routes × 2 widths have no horizontal
scroll (`GALLERY.md`).

## 1. Merge order and deploy checklist

1. **Merge wsethbrown/wss#36 first.** It carries the dependency security fixes
   (79 advisories on the current lockfile, one Critical; `DEPENDENCY_AUDIT.md`).
   This PR changes no gems. After #36 merges, merge the base into this branch and
   re-run the suite on Rails 8.1.
2. CI: the new `audit_gems` job will stay red until #36 is in. The new
   `system_test` job has never run anywhere (no compatible ChromeDriver in the
   build container); watch its first run.
3. Before the deploy that runs the migrations:
   - Take a database backup. The B7 migration deletes duplicate deck-ownership
     rows, and that cannot be undone.
   - Count `User.where(subscription_status: "cancelled")`. B6 rewrites those rows
     to `canceled`; it is idempotent, and its `down` does not restore the old spelling.
   - Run `rake events:zones`. B15 set every existing event to America/New_York; set
     the zone by hand for societies outside US Eastern time.
4. Deploy config changed: `config/deploy.yml` sets `proxy: forward_headers: true`.
   After deploy, check a production log line shows real visitor IPs for
   `remote_ip` and the boot line "Trusted proxies: N Cloudflare ranges loaded".
   Verify `config/initializers/trusted_proxies.rb` against cloudflare.com/ips-v4
   and /ips-v6, because the list was written from memory.
5. The jobs container now runs a second Solid Queue worker (`renders`, one
   thread): about 150–250 MB more. This affects I7, the memory caps.
6. Existing images have no preprocessed variants yet; each is generated on first
   view. Paid files shared earlier through permanent blob links keep working until
   re-uploaded (B9 notes).
7. After deploy, email-RSVP and invite links open a confirm page. Email-change
   links issued before the B8 migration stop working.

## 2. Open owner decisions

| # | Question | Default applied |
|---|---|---|
| 1 | ~~Homepage direction~~ **Answered:** keep the homepage; the glass (advisor's redraw from the logo) and the verdict go where their data lives, plus the homepage's fourth slide (G1) | Done in G1; `/?design=next4` kept as a study |
| 2 | May signed-in non-members RSVP to **public** society events? | Yes (unchanged); one constant flips it: `Event::PUBLIC_EVENTS_OPEN_TO_NON_MEMBERS` |
| 3 | Back-pay quarterly/yearly members the monthly credits `rake credits:owed` reports? | No back-pay |
| 4 | When a direct purchase replaces a credit unlock, return the credit? | Not returned; logged |
| 5 | Two-factor sign-in (B11): remove or build properly? An admin "reset 2FA" control belongs to this decision | Blocked |
| 6 | Account deletion (B12): the decisions in `ACCOUNT_DELETION.md` | Self-service deletion disabled |
| 7 | Keep `SocietyApplication` (self-serve join requests) or remove it? | Kept |
| 8 | Terms of Service / Privacy Policy links on sign-up go to `#`. Write the documents or remove the implied agreement? | Untouched |
| 9 | CLAUDE.md "Admin Panel Development" tells people to update `admin_panel_todo.md`, which does not exist: reword or drop | Untouched |
| 10 | Magic-link sign-in click-to-confirm (protects against mail scanners)? | Not done |
| 11 | Per-society event-email muting (today the mute is the global preference) | Possible feature, not built |
| 12 | A full review-board page for societies (the board is capped at 15 with a count) | Not built |
| 13 | Devise `:lockable` hard lockout | Not enabled (per-email rate limit instead) |
| 14 | Magic-link per-email limit of 3 per 15 minutes: too tight? | Kept |
| 15 | Confirm the yearly and quarterly Stripe price intervals (M1), and which payment methods are enabled (M15) | — |
| 16 | Any production user with `otp_enabled = true`? (S7) | — |

## 3. Ops items (also in `TASKS.md`)

I7 memory caps for web and jobs containers · I10 separate R2 bucket and a
write-only token for backups · I11 dead-man's switch on the nightly backup ·
M1/M15/S7 checks above · CSP enforcement needs the template and JS fixes listed
in `CSP_REPORT_ONLY.md` (report-only today) · a Cloudflare rate-limiting rule
on `/magic_links` as the outer layer.

## 4. New user-facing copy for approval

Collected from every task; case-only changes are listed in the D11 commit.

- **Error pages:**
  - 404: "That page doesn't exist" / "You may have mistyped the address, or the page may have moved."
  - 422: "That change was rejected" / "Please check the request and try again."
  - 500: "Something went wrong" / "We're sorry. Please try again in a moment."
  - 400: "That request couldn't be processed" / "Please check the request and try again."
  - 406: "Your browser is not supported" / "Please upgrade your browser to continue."
  - All five: "Back to the home page".
- **Rate limit:** "Too many attempts. Please wait a few minutes and try again."
- **Account deletion:** "To delete your account, please contact us." (notice, and the sentence on the edit page).
- **Admin email:**
  - Hint: "Changing the email signs the member out of remembered sessions and cancels any pending sign-in or invitation link."
  - Refusals: "Only full administrators can change email addresses." and "You can't change another administrator's email."
  - A read-only "Email" label.
- **Admin deck delete refused:** "This deck has owners or credit history, so it can't be deleted. Unpublish it instead."
- **Admin import notice (.ppt/.pdf):** "Draft imported. The deck's text and slide previews are being extracted and will appear shortly. Review each section, set a price, then publish."
- **Admin shell:**
  - Sidebar groups "Content", "People", "Reports".
  - "Skip to content".
  - Screen-reader "Menu" and "Actions".
  - "Nothing here yet."
  - "Joined".
  - Revenue rows joined with commas.
  - "billed monthly / quarterly / annually" on the create-subscription cards.
- **Library and deck page:**
  - Heading "Pick *a deck*" (was "Whiskey Presentations").
  - "A taste of the writing" for non-owners and "The story" for owners, plus "N min read".
  - "Downloads".
  - "About the author".
- **Societies:**
  - "Back to <society>".
  - "You're invited" in the invite-peek meta line.
  - "Showing the top 15 of N bottles."
- **Events:**
  - "N unanswered" and "See the deck →".
  - "Edit event", "Changing the details of <title>.", "Update event".
  - Time notes: "· 7:29 PM EST at the event" and "Times in PST".
- **Email change:**
  - Flash: "A verification link has been sent to {new email}. Please check that inbox and click the link to confirm the email change."
  - Notice email: subject "Your email address is being changed", heading "Your email is being changed", and the lines "The change only takes effect once it is confirmed from that address." and "If you didn't request this change, change your password and contact us."
  - Devise refusal: "To change your email address, use the Email address section of your account page."
  - Devise edit "Email" label.
- **Event mute:**
  - "Turn off event emails" (heading, button and email link).
  - "Society events (new events, changes, reminders) for <email>."
  - "Event emails are off"
  - "You can turn them back on any time in your account settings."
  - "Account settings"
  - The fallback zone is America/New_York.
- **Notifications:** screen-reader "Unread".
- **G1 (glass):** "The table" (event attendees heading, replaces "Attending"; "Attending · N" stays below), "The verdict", "Ranked by the room.", count line "N going · N maybe · N unanswered", "+N" for seats beyond 12, sr-only "Pour N," and " out of 5".
- **`/?design=next4` study (preview only):**
  - "RSVP for the night", "Meet the society", "On deck", "<host> presents".
  - "The pours", "The table", "The verdict", "Pour <n> took the night: <bottle>."
  - "Ranked by the room", "of 5 · N reviews", "That's the whole *ritual.*".

## 5. TASKS.md items not done, and why

- **B11 two-factor and B12 account deletion:** blocked on the owner (§2).
- **B5 back-pay:** not done by design; `rake credits:owed` only reports.
- **D11 full-bleed layout list:** left as a documented simplification (SECTION_NOTES §1). About a dozen views would change together.
- **B19 dependency bump:** not done here, by the advisor's ruling; #36 does it.
- **Deferred by the owner earlier:** moving webhook processing to a job.
- **Not verifiable in this container:**
  - The CI `system_test` job.
  - The real R2 behaviour of the 5-minute download URLs.
  - Google Maps under the CSP.
- **Known pre-existing issues** are listed in SECTION_NOTES §15.
