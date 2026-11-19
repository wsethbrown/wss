# Account deletion — current state and what a real service must do

Task B4 (findings M6, S9). Written November 2026 against `db/schema.rb` and
`app/models/user.rb` at the time.

## Current behaviour (after B4)

Self-service deletion is **disabled**. `DELETE /users` (Devise registrations
`destroy`) is overridden in `Users::RegistrationsController#destroy`: it deletes
nothing, logs one `info` line with the user id, and redirects to `/contact` with a
notice. The "Cancel my account" button on `/users/edit` is replaced by a sentence
pointing to the contact page. Admins can still delete users from the admin panel
(full admins only, `can_delete?`), which has the same problems described below.

## Why the old behaviour was dangerous

`User#destroy` was reachable by any signed-in user and:

1. **Raised a foreign-key error (500) for most users.** Several tables reference
   `users` with an FK and the model declares no `dependent:` handling (see
   "Hard blockers" below). Anyone who had a download log, an event comment, hosted an
   event, created a bottle, proposed a bottle edit or invited another user could not
   be deleted.
2. **When it did succeed, it destroyed other members' data.** `societies`,
   `events` and `presentations` are `dependent: :destroy` on the creator/organizer/
   author. Deleting a society creator removes the society, its memberships, events,
   RSVPs, comments and activity for every other member. Deleting a deck author
   removes the deck and, via `user_presentations`, every buyer's lifetime access.
3. **Left billing running.** Nothing cancels the Stripe subscription or deletes the
   Stripe customer, so a deleted user could keep being charged.
4. **Erased the credit ledger** (`credit_transactions` is `dependent: :destroy`),
   which is the financial record of money and credits moving.

## Every foreign key to `users` (from `db/schema.rb`)

### Declared foreign keys (`add_foreign_key ... "users"`)

| Table.column | `User` association / dependent today | Effect of `user.destroy` today |
|---|---|---|
| `activity_logs.user_id` | `has_many :activity_logs, dependent: :destroy` | rows deleted |
| `bottle_edits.user_id` | **none** | FK violation, 500 |
| `bottle_edits.applied_by_id` | **none** | FK violation, 500 |
| `bottles.created_by_id` | **none** | FK violation, 500 |
| `credit_transactions.user_id` | `dependent: :destroy` | ledger deleted |
| `download_logs.user_id` | **none** | FK violation, 500 |
| `event_comments.user_id` | **none** | FK violation, 500 |
| `event_rsvps.user_id` | `dependent: :destroy` | rows deleted |
| `events.host_id` | **none** (`Event belongs_to :host, optional`) | FK violation, 500 |
| `events.organizer_id` | `has_many :events, foreign_key: :organizer_id, dependent: :destroy` | events deleted, taking RSVPs/comments/bottles; `reviews` use `restrict_with_error` on Event, so can abort |
| `favorites.user_id` | `dependent: :destroy` (plus `favorited_by_records`, polymorphic, destroyed) | rows deleted |
| `notifications.user_id` | `dependent: :destroy` | rows deleted |
| `notifications.actor_id` | `authored_notifications, dependent: :destroy` | other members' notifications about this user deleted |
| `presentation_reviews.user_id` | `dependent: :destroy` | rows deleted |
| `presentations.author_id` | `has_many :presentations, foreign_key: :author_id, dependent: :destroy` | **decks deleted**, cascading to buyers' `user_presentations` |
| `review_reports.user_id` | `dependent: :destroy` | rows deleted |
| `review_votes.user_id` | `dependent: :destroy` | rows deleted |
| `reviews.user_id` | `dependent: :destroy` | reviews deleted (event reviews other members see) |
| `shelf_items.user_id` | `dependent: :destroy` | rows deleted |
| `societies.creator_id` | `has_many :societies, foreign_key: :creator_id, dependent: :destroy` | **societies deleted** with all members' data |
| `society_activities.user_id` | `dependent: :destroy` | rows deleted |
| `society_activities.actor_id` | `authored_society_activities, dependent: :destroy` | other people's activity rows deleted |
| `society_applications.user_id` | `dependent: :destroy` | rows deleted |
| `society_invitations.user_id` | `dependent: :destroy` | rows deleted |
| `society_invitations.invited_by_id` | `sent_society_invitations, dependent: :destroy` | invitations sent to others deleted |
| `society_memberships.user_id` | `dependent: :destroy` | rows deleted |
| `user_presentations.user_id` | `dependent: :destroy` | ownership deleted |
| `user_tags.user_id` | `dependent: :destroy` | rows deleted |
| `users.invited_by_id` (self) | `belongs_to :invited_by, optional` — **no inverse `has_many`, no dependent** | FK violation if this user invited anyone, 500 |

### Hard blockers today (FK with no `dependent:` on User)

`bottle_edits.user_id`, `bottle_edits.applied_by_id`, `bottles.created_by_id`,
`download_logs.user_id`, `event_comments.user_id`, `events.host_id`,
`users.invited_by_id`.

### Columns that reference users with no foreign key

Searching `db/schema.rb` for `user_id`, `*_by_id`, `author_id`, `creator_id`,
`organizer_id`, `host_id`, `actor_id` finds **no plain column without an FK**: every
such column above is declared. The remaining references are by design not FKs:

- **Polymorphic references** that can point at a user and have no FK or cascade:
  `favorites.favoritable_type/_id` (a `User` is destroyed via the
  `favorited_by_records` association), `activity_logs.trackable_type/_id`,
  `notifications.notifiable_type/_id`. These can be left dangling.
- **Text identifiers**: `users.email`, `users.stripe_customer_id`,
  `users.stripe_subscription_id` (and Stripe-side data, see below). Also
  `stripe_events` rows and `ActiveStorage` attachments (`profile_image`, polymorphic
  `record_type/record_id`) hold user-related data with no FK. Attachments are purged
  by Active Storage's `has_one_attached` on destroy.
- Mailer queue rows (Solid Queue) and logs may contain the email address.

## What a real deletion service must do

Build as `Accounts::DeletionService` (one transaction for the database part, logged
at `info` with ids at each step, never logging tokens):

1. **Preconditions**: refuse (with a clear message) for admins and, per the owner's
   decision, for users who still founded societies or authored decks, until handled.
2. **Stripe first**: cancel the subscription immediately (not at period end) and
   delete or anonymise the Stripe customer. Fail closed: if Stripe fails, do not
   delete. Webhooks for a missing user must be ignored and logged (they currently
   look users up by `stripe_customer_id`).
3. **Founded societies** (`societies.creator_id`): transfer to another admin, or
   refuse deletion until ownership is transferred; never cascade-delete a society
   other members use.
4. **Hosted events** (`events.organizer_id`, `host_id`): reassign to the society
   admin, or null `host_id` and keep past events.
5. **Authored decks** (`presentations.author_id`): archive and reassign to an
   owner/system user; never delete a deck anyone owns (see M12/B7).
6. **Content other people see** (`reviews`, `event_comments`, `presentation_reviews`,
   `bottle_edits`, `bottles.created_by_id`, `society_activities`, `notifications.actor_id`):
   anonymise (point at a placeholder "deleted member" user, or make the columns
   nullable) rather than delete.
7. **Private data to remove**: `shelf_items`, `favorites` (both directions),
   `user_tags`, `notifications`, `event_rsvps`, `review_votes`, `review_reports`,
   `society_memberships`, `society_applications`, `society_invitations` (both
   directions), `activity_logs`, `download_logs`, profile image, and PII on the
   `users` row (email, names, OAuth uid, otp secret and backup codes, tokens).
8. **Financial records**: `credit_transactions`, `user_presentations` and Stripe
   events are financial history. Keep them, attached to an anonymised user row,
   for whatever retention period the owner chooses. This is the main reason to
   anonymise the `users` row instead of deleting it.
9. **Sign-out and session invalidation**, a confirmation email to the old address,
   and a short grace period (soft delete, then purge) so mistakes can be undone.
10. **Tests**: one per table in the FK list above, a society-founder case, a deck
    author with buyers, an active subscriber (Stripe stubbed), and the ledger
    invariant (`users.credits == sum(ledger)`) for any retained row.

## Decisions the owner must make

1. Delete the `users` row, or anonymise it and keep the financial history? (Advisor's
   recommendation: anonymise.)
2. Retention period for financial records and download logs.
3. What happens to a society whose founder leaves: transfer to the oldest admin,
   ask members, or block deletion?
4. What happens to decks a user authored (author is normally an admin, but the FK
   permits any user) and to the decks other users own?
5. Are reviews and comments deleted, or kept under "deleted member"?
6. Is a refund owed for unused credits or the current billing period?
7. Grace period before the purge, and whether the user can restore in that window.
8. Until the service exists, is "email us" acceptable, and who answers `/contact`?

## Related

Admin-initiated user deletion (`Admin::UsersController#destroy`) shares every
problem above and should call the same service when it exists.
