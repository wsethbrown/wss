# Redesign gallery

Every HTML route walked in D11 (November 2026), at 1440px and 390px, as the viewer it matters for. Each image is the first screen of the page (viewport capture, JPEG). `scrollWidth` is `document.documentElement.scrollWidth` at that width: it equals the viewport width on every page, so nothing scrolls sideways. Full-page captures were kept outside the repo.

Records used: deck 4 (The Honest Bottle, rendered slides), deck 1 (no cover), society 1 (public, member), society 2 (member is admin), society 3 (private, non-member), event 1 and 3, bottle ardbeg-10-ardbeg, review 2 (someone else's) and 4 (the member's own).

Not included: download, present-mode, health, sitemap and other non-HTML routes; token routes (magic link, invitations, email RSVP, mute) except an invalid invite link; `/events/:id/reviews/new`, which needs a bottle from the event's pours to render.

## Signed out

| Route | 1440px | 390px | scrollWidth |
|---|---|---|---|
| `/` | [1440](gallery/out-home-1440.jpg) | [390](gallery/out-home-390.jpg) | 1440 / 390 |
| `/presentations` | [1440](gallery/out-presentations-1440.jpg) | [390](gallery/out-presentations-390.jpg) | 1440 / 390 |
| `/presentations/4` | [1440](gallery/out-presentations_4-1440.jpg) | [390](gallery/out-presentations_4-390.jpg) | 1440 / 390 |
| `/presentations/1` | [1440](gallery/out-presentations_1-1440.jpg) | [390](gallery/out-presentations_1-390.jpg) | 1440 / 390 |
| `/societies` | [1440](gallery/out-societies-1440.jpg) | [390](gallery/out-societies-390.jpg) | 1440 / 390 |
| `/societies/1` | [1440](gallery/out-societies_1-1440.jpg) | [390](gallery/out-societies_1-390.jpg) | 1440 / 390 |
| `/societies/3` (→ `/societies`) | [1440](gallery/out-societies_3-1440.jpg) | [390](gallery/out-societies_3-390.jpg) | 1440 / 390 |
| `/reviews` | [1440](gallery/out-reviews-1440.jpg) | [390](gallery/out-reviews-390.jpg) | 1440 / 390 |
| `/reviews/2` | [1440](gallery/out-reviews_2-1440.jpg) | [390](gallery/out-reviews_2-390.jpg) | 1440 / 390 |
| `/bottles/ardbeg-10-ardbeg` | [1440](gallery/out-bottles_ardbeg-10-ardbeg-1440.jpg) | [390](gallery/out-bottles_ardbeg-10-ardbeg-390.jpg) | 1440 / 390 |
| `/membership` | [1440](gallery/out-membership-1440.jpg) | [390](gallery/out-membership-390.jpg) | 1440 / 390 |
| `/contact` | [1440](gallery/out-contact-1440.jpg) | [390](gallery/out-contact-390.jpg) | 1440 / 390 |
| `/auth` | [1440](gallery/out-auth-1440.jpg) | [390](gallery/out-auth-390.jpg) | 1440 / 390 |
| `/users/password/new` | [1440](gallery/out-users_password_new-1440.jpg) | [390](gallery/out-users_password_new-390.jpg) | 1440 / 390 |
| `/profiles/1` (→ `/users/sign_in`) | [1440](gallery/out-profiles_1-1440.jpg) | [390](gallery/out-profiles_1-390.jpg) | 1440 / 390 |
| `/invite/BADTOKEN` (→ `/`) | [1440](gallery/out-invite_BADTOKEN-1440.jpg) | [390](gallery/out-invite_BADTOKEN-390.jpg) | 1440 / 390 |

## Member (test@example.com)

| Route | 1440px | 390px | scrollWidth |
|---|---|---|---|
| `/` | [1440](gallery/member-home-1440.jpg) | [390](gallery/member-home-390.jpg) | 1440 / 390 |
| `/dashboard` | [1440](gallery/member-dashboard-1440.jpg) | [390](gallery/member-dashboard-390.jpg) | 1440 / 390 |
| `/presentations` | [1440](gallery/member-presentations-1440.jpg) | [390](gallery/member-presentations-390.jpg) | 1440 / 390 |
| `/presentations/4` | [1440](gallery/member-presentations_4-1440.jpg) | [390](gallery/member-presentations_4-390.jpg) | 1440 / 390 |
| `/presentations/1` | [1440](gallery/member-presentations_1-1440.jpg) | [390](gallery/member-presentations_1-390.jpg) | 1440 / 390 |
| `/presentations/1/purchases/new` | [1440](gallery/member-presentations_1_purchases_new-1440.jpg) | [390](gallery/member-presentations_1_purchases_new-390.jpg) | 1440 / 390 |
| `/societies` | [1440](gallery/member-societies-1440.jpg) | [390](gallery/member-societies-390.jpg) | 1440 / 390 |
| `/societies/1` | [1440](gallery/member-societies_1-1440.jpg) | [390](gallery/member-societies_1-390.jpg) | 1440 / 390 |
| `/societies/2` | [1440](gallery/member-societies_2-1440.jpg) | [390](gallery/member-societies_2-390.jpg) | 1440 / 390 |
| `/societies/3` (→ `/societies`) | [1440](gallery/member-societies_3-1440.jpg) | [390](gallery/member-societies_3-390.jpg) | 1440 / 390 |
| `/societies/1/activity` (→ `/societies`) | [1440](gallery/member-societies_1_activity-1440.jpg) | [390](gallery/member-societies_1_activity-390.jpg) | 1440 / 390 |
| `/societies/2/edit` | [1440](gallery/member-societies_2_edit-1440.jpg) | [390](gallery/member-societies_2_edit-390.jpg) | 1440 / 390 |
| `/societies/new` | [1440](gallery/member-societies_new-1440.jpg) | [390](gallery/member-societies_new-390.jpg) | 1440 / 390 |
| `/societies/1/events/1` | [1440](gallery/member-societies_1_events_1-1440.jpg) | [390](gallery/member-societies_1_events_1-390.jpg) | 1440 / 390 |
| `/societies/2/events/3` | [1440](gallery/member-societies_2_events_3-1440.jpg) | [390](gallery/member-societies_2_events_3-390.jpg) | 1440 / 390 |
| `/societies/2/events/new` | [1440](gallery/member-societies_2_events_new-1440.jpg) | [390](gallery/member-societies_2_events_new-390.jpg) | 1440 / 390 |
| `/societies/2/events/3/edit` | [1440](gallery/member-societies_2_events_3_edit-1440.jpg) | [390](gallery/member-societies_2_events_3_edit-390.jpg) | 1440 / 390 |
| `/reviews` | [1440](gallery/member-reviews-1440.jpg) | [390](gallery/member-reviews-390.jpg) | 1440 / 390 |
| `/reviews/start` | [1440](gallery/member-reviews_start-1440.jpg) | [390](gallery/member-reviews_start-390.jpg) | 1440 / 390 |
| `/reviews/2` | [1440](gallery/member-reviews_2-1440.jpg) | [390](gallery/member-reviews_2-390.jpg) | 1440 / 390 |
| `/reviews/4/edit` | [1440](gallery/member-reviews_4_edit-1440.jpg) | [390](gallery/member-reviews_4_edit-390.jpg) | 1440 / 390 |
| `/bottles/ardbeg-10-ardbeg` | [1440](gallery/member-bottles_ardbeg-10-ardbeg-1440.jpg) | [390](gallery/member-bottles_ardbeg-10-ardbeg-390.jpg) | 1440 / 390 |
| `/bottles/new` | [1440](gallery/member-bottles_new-1440.jpg) | [390](gallery/member-bottles_new-390.jpg) | 1440 / 390 |
| `/bottles/ardbeg-10-ardbeg/reviews/new` | [1440](gallery/member-bottles_ardbeg-10-ardbeg_reviews_new-1440.jpg) | [390](gallery/member-bottles_ardbeg-10-ardbeg_reviews_new-390.jpg) | 1440 / 390 |
| `/bottles/ardbeg-10-ardbeg/edits/new` | [1440](gallery/member-bottles_ardbeg-10-ardbeg_edits_new-1440.jpg) | [390](gallery/member-bottles_ardbeg-10-ardbeg_edits_new-390.jpg) | 1440 / 390 |
| `/bottles/ardbeg-10-ardbeg/verdicts/1` | [1440](gallery/member-bottles_ardbeg-10-ardbeg_verdicts_1-1440.jpg) | [390](gallery/member-bottles_ardbeg-10-ardbeg_verdicts_1-390.jpg) | 1440 / 390 |
| `/account` | [1440](gallery/member-account-1440.jpg) | [390](gallery/member-account-390.jpg) | 1440 / 390 |
| `/account?tab=subscription` | [1440](gallery/member-account_tab_subscription-1440.jpg) | [390](gallery/member-account_tab_subscription-390.jpg) | 1440 / 390 |
| `/notifications` | [1440](gallery/member-notifications-1440.jpg) | [390](gallery/member-notifications-390.jpg) | 1440 / 390 |
| `/users/edit` | [1440](gallery/member-users_edit-1440.jpg) | [390](gallery/member-users_edit-390.jpg) | 1440 / 390 |
| `/subscriptions/plans` (→ `/`) | [1440](gallery/member-subscriptions_plans-1440.jpg) | [390](gallery/member-subscriptions_plans-390.jpg) | 1440 / 390 |
| `/profiles/1` | [1440](gallery/member-profiles_1-1440.jpg) | [390](gallery/member-profiles_1-390.jpg) | 1440 / 390 |
| `/membership` | [1440](gallery/member-membership-1440.jpg) | [390](gallery/member-membership-390.jpg) | 1440 / 390 |
| `/contact` | [1440](gallery/member-contact-1440.jpg) | [390](gallery/member-contact-390.jpg) | 1440 / 390 |

## Admin (admin@whiskeysharesociety.com)

| Route | 1440px | 390px | scrollWidth |
|---|---|---|---|
| `/admin` | [1440](gallery/admin-admin-1440.jpg) | [390](gallery/admin-admin-390.jpg) | 1440 / 390 |
| `/admin/users` | [1440](gallery/admin-admin_users-1440.jpg) | [390](gallery/admin-admin_users-390.jpg) | 1440 / 390 |
| `/admin/users/1` | [1440](gallery/admin-admin_users_1-1440.jpg) | [390](gallery/admin-admin_users_1-390.jpg) | 1440 / 390 |
| `/admin/users/1/edit` | [1440](gallery/admin-admin_users_1_edit-1440.jpg) | [390](gallery/admin-admin_users_1_edit-390.jpg) | 1440 / 390 |
| `/admin/subscriptions` | [1440](gallery/admin-admin_subscriptions-1440.jpg) | [390](gallery/admin-admin_subscriptions-390.jpg) | 1440 / 390 |
| `/admin/subscriptions/1/edit` | [1440](gallery/admin-admin_subscriptions_1_edit-1440.jpg) | [390](gallery/admin-admin_subscriptions_1_edit-390.jpg) | 1440 / 390 |
| `/admin/credits` | [1440](gallery/admin-admin_credits-1440.jpg) | [390](gallery/admin-admin_credits-390.jpg) | 1440 / 390 |
| `/admin/credits/transactions` | [1440](gallery/admin-admin_credits_transactions-1440.jpg) | [390](gallery/admin-admin_credits_transactions-390.jpg) | 1440 / 390 |
| `/admin/credits/1/adjust` | [1440](gallery/admin-admin_credits_1_adjust-1440.jpg) | [390](gallery/admin-admin_credits_1_adjust-390.jpg) | 1440 / 390 |
| `/admin/presentations` | [1440](gallery/admin-admin_presentations-1440.jpg) | [390](gallery/admin-admin_presentations-390.jpg) | 1440 / 390 |
| `/admin/presentations/4` | [1440](gallery/admin-admin_presentations_4-1440.jpg) | [390](gallery/admin-admin_presentations_4-390.jpg) | 1440 / 390 |
| `/admin/presentations/4/edit` | [1440](gallery/admin-admin_presentations_4_edit-1440.jpg) | [390](gallery/admin-admin_presentations_4_edit-390.jpg) | 1440 / 390 |
| `/admin/presentations/new` | [1440](gallery/admin-admin_presentations_new-1440.jpg) | [390](gallery/admin-admin_presentations_new-390.jpg) | 1440 / 390 |
| `/admin/bottles` | [1440](gallery/admin-admin_bottles-1440.jpg) | [390](gallery/admin-admin_bottles-390.jpg) | 1440 / 390 |
| `/admin/bottles/ardbeg-10-ardbeg` | [1440](gallery/admin-admin_bottles_ardbeg-10-ardbeg-1440.jpg) | [390](gallery/admin-admin_bottles_ardbeg-10-ardbeg-390.jpg) | 1440 / 390 |
| `/admin/bottles/ardbeg-10-ardbeg/edit` | [1440](gallery/admin-admin_bottles_ardbeg-10-ardbeg_edit-1440.jpg) | [390](gallery/admin-admin_bottles_ardbeg-10-ardbeg_edit-390.jpg) | 1440 / 390 |
| `/admin/moderation` | [1440](gallery/admin-admin_moderation-1440.jpg) | [390](gallery/admin-admin_moderation-390.jpg) | 1440 / 390 |
| `/admin/invitations/new` | [1440](gallery/admin-admin_invitations_new-1440.jpg) | [390](gallery/admin-admin_invitations_new-390.jpg) | 1440 / 390 |
| `/admin/activities` | [1440](gallery/admin-admin_activities-1440.jpg) | [390](gallery/admin-admin_activities-390.jpg) | 1440 / 390 |
| `/admin/analytics/downloads` | [1440](gallery/admin-admin_analytics_downloads-1440.jpg) | [390](gallery/admin-admin_analytics_downloads-390.jpg) | 1440 / 390 |
| `/admin/analytics/reviews` | [1440](gallery/admin-admin_analytics_reviews-1440.jpg) | [390](gallery/admin-admin_analytics_reviews-390.jpg) | 1440 / 390 |
