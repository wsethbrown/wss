# Review System Social Layer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans to run this task-by-task. `- [ ]` = tracked step.

**Goal:** Phase 3-social per the addendum in `docs/superpowers/specs/2026-07-06-review-system-design.md`: polymorphic `favorites` (Society|User) with toggle buttons + private own-profile section; circle sidebar on `/reviews` + `?feed=circle`; thumbs-up-only `review_votes` with counter cache reordering bottle tastings; `?feed=hot` (30-day trailing votes); Latest/Circle/Hot pills.

**Stack:** Rails 8.0.2, Postgres 15, Hotwire, Tailwind v4, Devise, Pundit, Minitest+fixtures.

## Global constraints

- Docker-only: `docker compose exec -T web bin/rails ...` for every migration/test/generator. Never run `bin/rails` on the host.
- **Schema dump rides with the migration commit.** After `db:migrate`, `git add db/schema.rb` in the same commit — parallel test workers build from `db/schema.rb`, not by replaying migrations; a stale dump false-greens single-file runs while breaking parallel ones.
- Baseline (verified 2026-07-07): **268 runs, 1041 assertions, 0 failures, 9 skips** (pre-existing, not ours). Stays green — same 9 skips, 0 failures — after every task. Each task ends with `docker compose exec -T web bin/rails test` at the stated expected count; a step that introduces new tests is red until its implementation step lands, per standard TDD red/green (not restated per-step below).
- `button_to` (Turbo, same-origin POST/DELETE) for every toggle/vote — no custom JS/Stimulus, matching the existing join/leave-society pattern.
- Design tokens: white/whiskey-50 surfaces, `.eyebrow` kickers, `font-display` headings. Card shape: `rounded-2xl border border-gray-200 bg-white shadow-sm` on index/bottle pages, `rounded-lg` cards on profile/society pages — match the page you're editing. "Standard whiskey button classes" = copy the class string off the nearest existing `button_to`/`link_to` on that same view rather than inventing new ones (primary tone is `bg-whiskey-600 hover:bg-whiskey-700 text-white`).
- Rating display: always `bottles/_rating` partial + `number_with_precision(value, precision: 2, strip_insignificant_zeros: true)`.
- **Privacy is load-bearing.** Favoriting a Society routes through `SocietyPolicy#show?` — enforced in the model validation (belt) and implied by controller `find` scoping (suspenders); a user must never favorite, or see a favorite of, a private society they can't see.
- Fixture landmines (Phase 1/2, do not trip): `bottles(:eagle_rare)` pinned at exactly 1 review (john, 4.0); `bottles(:lagavulin)` at 0 reviews; `societies(:whiskey_lovers)` membership pinned at 2 by `society_test`. This plan's new fixtures use `bottles(:ardbeg_10|glendronach_12|four_roses_sb)` (already reviewed under `spring_blind`) and new `favorites`/`review_votes` fixture files only.
- Canonical paths: `society_event_path(event.society, event)`, `profile_path(user)`, `society_path(society)`.

---

### Task 1: `favorites` — model, polymorphic guard, toggle buttons, own-profile section

**Files:** create `db/migrate/<ts>_create_favorites.rb`, `app/models/favorite.rb`, `app/controllers/favorites_controller.rb`, `app/views/favorites/_button.html.erb`, `test/fixtures/favorites.yml`, `test/models/favorite_test.rb`, `test/controllers/favorites_controller_test.rb`. Modify `app/models/user.rb`, `app/models/society.rb`, `config/routes.rb`, `app/controllers/profiles_controller.rb`, `app/views/societies/show.html.erb`, `app/views/profiles/show.html.erb`.

**Interfaces:** `Favorite belongs_to :user; belongs_to :favoritable, polymorphic: true`, unique on `(user_id, favoritable_type, favoritable_id)`. `User#favorite?(record)`. `favorites_path` (POST create, params `favoritable_type`/`favoritable_id`), `favorite_path(id)` (DELETE). `render "favorites/button", favoritable:` — hidden signed-out or on your own record.

- [ ] **Step 1 — failing model test.** Create `test/models/favorite_test.rb`:

```ruby
require "test_helper"

class FavoriteTest < ActiveSupport::TestCase
  test "a user can favorite a public society" do
    assert Favorite.new(user: users(:jane), favoritable: societies(:whiskey_lovers)).valid?
  end

  test "a user can favorite another user" do
    assert Favorite.new(user: users(:jane), favoritable: users(:john)).valid?
  end

  test "duplicate favorite is invalid" do
    Favorite.create!(user: users(:jane), favoritable: users(:john))
    dup = Favorite.new(user: users(:jane), favoritable: users(:john))
    assert_not dup.valid?
    assert_includes dup.errors[:favoritable_id], "has already been taken"
  end

  test "cannot favorite yourself" do
    fav = Favorite.new(user: users(:jane), favoritable: users(:jane))
    assert_not fav.valid?
    assert_includes fav.errors[:favoritable], "can't be yourself"
  end

  test "cannot favorite a private society you cannot see" do
    fav = Favorite.new(user: users(:john), favoritable: societies(:bourbon_club))
    assert_not fav.valid?
    assert_includes fav.errors[:favoritable], "isn't visible to you"
  end

  test "a member CAN favorite the private society they belong to" do
    assert Favorite.new(user: users(:jane), favoritable: societies(:bourbon_club)).valid? # jane is creator
  end
end
```

Run `docker compose exec -T web bin/rails test test/models/favorite_test.rb` — fails (no `Favorite`).

- [ ] **Step 2 — migration + model.**

```
docker compose exec -T web bin/rails generate model Favorite user:references favoritable:references{polymorphic}
```

Edit the generated migration:

```ruby
class CreateFavorites < ActiveRecord::Migration[8.0]
  def change
    create_table :favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :favoritable, polymorphic: true, null: false
      t.timestamps
    end
    add_index :favorites, [:user_id, :favoritable_type, :favoritable_id], unique: true, name: "index_favorites_on_user_and_favoritable"
  end
end
```

`app/models/favorite.rb`:

```ruby
# A user's private bookmark on a Society or User — visible only to the owner
# (ProfilesController only sets @favorites on your own profile). Favoriting a
# Society is gated by the same rule as viewing it (SocietyPolicy#show?).
class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :favoritable, polymorphic: true

  validates :favoritable_id, uniqueness: { scope: [:user_id, :favoritable_type] }
  validate :not_yourself
  validate :society_must_be_visible, if: -> { favoritable.is_a?(Society) }

  private

  def not_yourself
    errors.add(:favoritable, "can't be yourself") if favoritable.is_a?(User) && favoritable_id == user_id
  end

  def society_must_be_visible
    errors.add(:favoritable, "isn't visible to you") unless SocietyPolicy.new(user, favoritable).show?
  end
end
```

`app/models/user.rb` — add near existing `has_many`:

```ruby
has_many :favorites, dependent: :destroy
has_many :favorited_societies, -> { where(favorites: { favoritable_type: "Society" }) }, through: :favorites, source: :favoritable, source_type: "Society"
has_many :favorited_users, -> { where(favorites: { favoritable_type: "User" }) }, through: :favorites, source: :favoritable, source_type: "User"
has_many :favorited_by_records, class_name: "Favorite", as: :favoritable, dependent: :destroy # cleans up favorites OF this user

def favorite?(record) = favorites.exists?(favoritable: record)
```

`app/models/society.rb` — add: `has_many :favorites, as: :favoritable, dependent: :destroy`.

Run `docker compose exec -T web bin/rails db:migrate && git add db/schema.rb` (same commit).

`test/fixtures/favorites.yml`:

```yaml
jane_favorites_john:
  user: jane
  favoritable: john (User)

jane_favorites_single_malt:
  user: jane
  favoritable: single_malt (Society)

seth_favorites_whiskey_lovers:
  user: seth
  favoritable: whiskey_lovers (Society)
```

Run model test — green.

- [ ] **Step 3 — routes + controller.** Add to `config/routes.rb` after `resources :profiles, only: [:show]`: `resources :favorites, only: [:create, :destroy]`.

`test/controllers/favorites_controller_test.rb`:

```ruby
require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user favorites a public society" do
    sign_in users(:jane)
    assert_difference "Favorite.count", 1 do
      post favorites_path, params: { favoritable_type: "Society", favoritable_id: societies(:whiskey_lovers).id }
    end
    assert_redirected_to society_path(societies(:whiskey_lovers))
  end

  test "cannot favorite a private society you can't see" do
    sign_in users(:john)
    assert_no_difference "Favorite.count" do
      post favorites_path, params: { favoritable_type: "Society", favoritable_id: societies(:bourbon_club).id }
    end
  end

  test "unfavorite destroys the record" do
    sign_in users(:jane)
    assert_difference "Favorite.count", -1 do
      delete favorite_path(favorites(:jane_favorites_single_malt))
    end
  end

  test "cannot destroy someone else's favorite" do
    sign_in users(:john)
    assert_no_difference "Favorite.count" do
      delete favorite_path(favorites(:jane_favorites_single_malt))
    end
    assert_response :not_found
  end

  test "signed-out request redirects to sign in" do
    post favorites_path, params: { favoritable_type: "Society", favoritable_id: societies(:whiskey_lovers).id }
    assert_redirected_to new_user_session_path
  end
end
```

`app/controllers/favorites_controller.rb`:

```ruby
# create/destroy only — favorites render inline on the favoritable's page and
# in full on the owner's own profile (ProfilesController).
class FavoritesController < ApplicationController
  before_action :authenticate_user!

  def create
    favoritable = favoritable_class.find(params[:favoritable_id])
    current_user.favorites.build(favoritable: favoritable).save
    redirect_back_or_to favoritable
  end

  def destroy
    favorite = current_user.favorites.find(params[:id]) # scoped to current_user: 404s on someone else's row
    favoritable = favorite.favoritable
    favorite.destroy
    redirect_back_or_to favoritable
  end

  private

  def favoritable_class = params[:favoritable_type] == "User" ? User : Society
  def redirect_back_or_to(f) = redirect_to(f.is_a?(User) ? profile_path(f) : society_path(f))
end
```

Run controller test — green.

- [ ] **Step 4 — toggle button + wiring.** `app/views/favorites/_button.html.erb` (locals: `favoritable`):

```erb
<% if user_signed_in? && favoritable != current_user %>
  <% existing = current_user.favorites.find_by(favoritable: favoritable) %>
  <% if existing %>
    <%= button_to "★ Favorited", favorite_path(existing), method: :delete,
        class: "inline-flex cursor-pointer items-center rounded-xl border border-whiskey-300 bg-whiskey-50 px-4 py-2 text-sm font-semibold text-whiskey-800 transition hover:bg-whiskey-100" %>
  <% else %>
    <%= button_to "☆ Favorite", favorites_path(favoritable_type: favoritable.class.name, favoritable_id: favoritable.id), method: :post,
        class: "inline-flex cursor-pointer items-center rounded-xl border border-gray-300 px-4 py-2 text-sm font-semibold text-gray-700 transition hover:border-whiskey-300 hover:text-whiskey-700" %>
  <% end %>
<% end %>
```

`app/views/societies/show.html.erb` — inside the "Membership state / actions" flex div (~line 53-74), add as a sibling chip after the `if user_signed_in? ... else ... end` block: `<%= render "favorites/button", favoritable: @society %>`.

`app/views/profiles/show.html.erb` — after the header's `<div class="flex-1">...</div>` closes (~line 42):

```erb
<% unless @user == current_user %>
  <div class="mt-4"><%= render "favorites/button", favoritable: @user %></div>
<% end %>
```

`app/controllers/profiles_controller.rb#show` — add (filters stale favorites of societies you've lost visibility into):

```ruby
@favorites = @user == current_user ? current_user.favorites.includes(:favoritable).order(created_at: :desc).select { |f| f.favoritable.is_a?(User) || Pundit.policy(current_user, f.favoritable).show? } : []
```

`app/views/profiles/show.html.erb` — after the Societies section's closing `</div>` (~line 119), still inside `lg:col-span-2`:

```erb
<% if @user == current_user && @favorites.any? %>
  <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
    <h2 class="text-xl font-semibold text-gray-900 mb-4">Favorites</h2>
    <div class="divide-y divide-gray-100">
      <% @favorites.each do |favorite| %>
        <% record = favorite.favoritable %>
        <div class="flex items-center justify-between py-3 first:pt-0 last:pb-0">
          <% if record.is_a?(User) %>
            <%= link_to record.full_name, profile_path(record), class: "font-medium text-gray-900 hover:text-whiskey-700" %>
          <% else %>
            <%= link_to record.name, society_path(record), class: "font-medium text-gray-900 hover:text-whiskey-700" %>
          <% end %>
          <%= button_to "Remove", favorite_path(favorite), method: :delete,
              class: "cursor-pointer text-sm font-semibold text-gray-400 hover:text-red-600" %>
        </div>
      <% end %>
    </div>
  </div>
<% end %>
```

Run full suite — expect **279 runs** (268 + 6 model + 5 controller), 0 failures, 9 skips.

- [ ] **Step 5 — commit.**

```
git add -A
git commit -m "Add favorites: polymorphic Society/User bookmarks with privacy guard"
```

---

### Task 2: `review_votes` — thumbs-up, counter cache, bottle-page ordering

**Files:** create `db/migrate/<ts>_create_review_votes.rb`, `app/models/review_vote.rb`, `app/controllers/review_votes_controller.rb`, `app/views/review_votes/_button.html.erb`, `test/fixtures/review_votes.yml`, `test/models/review_vote_test.rb`, `test/controllers/review_votes_controller_test.rb`. Modify `app/models/review.rb`, `app/models/user.rb`, `config/routes.rb`, `app/controllers/bottles_controller.rb`, `app/views/bottles/show.html.erb`, `app/views/reviews/show.html.erb`.

**Interfaces:** `ReviewVote belongs_to :user; belongs_to :review, counter_cache: :votes_count`, unique on `(user_id, review_id)`, blocks self-vote. `reviews.votes_count` int, default 0. `review_votes_path` (POST), `review_vote_path(id)` (DELETE). Bottle show `@reviews` orders `votes_count: :desc, created_at: :desc`.

- [ ] **Step 1 — failing model test.** `test/models/review_vote_test.rb`:

```ruby
require "test_helper"

class ReviewVoteTest < ActiveSupport::TestCase
  test "a user can vote for someone else's review" do
    assert ReviewVote.new(user: users(:seth), review: reviews(:john_eagle_rare)).valid?
  end

  test "cannot vote for your own review" do
    vote = ReviewVote.new(user: users(:john), review: reviews(:john_eagle_rare))
    assert_not vote.valid?
    assert_includes vote.errors[:base], "You can't vote for your own review"
  end

  test "duplicate vote is invalid" do
    ReviewVote.create!(user: users(:seth), review: reviews(:john_eagle_rare))
    dup = ReviewVote.new(user: users(:seth), review: reviews(:john_eagle_rare))
    assert_not dup.valid?
    assert_includes dup.errors[:review_id], "has already been taken"
  end

  test "voting increments the counter cache" do
    review = reviews(:john_eagle_rare)
    assert_difference -> { review.reload.votes_count }, 1 do
      ReviewVote.create!(user: users(:seth), review: review)
    end
  end

  test "unvoting decrements the counter cache" do
    vote = ReviewVote.create!(user: users(:seth), review: reviews(:john_eagle_rare))
    assert_difference -> { reviews(:john_eagle_rare).reload.votes_count }, -1 do
      vote.destroy
    end
  end
end
```

Run — fails (no `ReviewVote`, no column).

- [ ] **Step 2 — migration + model.**

```
docker compose exec -T web bin/rails generate model ReviewVote user:references review:references
```

Edit the generated migration:

```ruby
class CreateReviewVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :review_votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :review, null: false, foreign_key: true
      t.timestamps
    end
    add_index :review_votes, [:user_id, :review_id], unique: true
    add_column :reviews, :votes_count, :integer, null: false, default: 0
  end
end
```

`app/models/review_vote.rb`:

```ruby
# A thumbs-up on a review. No downvotes. Maintains reviews.votes_count via
# counter_cache for bottle-page ordering; the hot feed's 30-day window still
# needs a real join (Review.hot_ranked) since this cache is lifetime-total.
class ReviewVote < ApplicationRecord
  belongs_to :user
  belongs_to :review, counter_cache: :votes_count

  validates :review_id, uniqueness: { scope: :user_id }
  validate :not_own_review

  private

  def not_own_review
    errors.add(:base, "You can't vote for your own review") if review && review.user_id == user_id
  end
end
```

`app/models/review.rb` — add near the top associations: `has_many :review_votes, dependent: :destroy`.
`app/models/user.rb` — add: `has_many :review_votes, dependent: :destroy`.

Run `docker compose exec -T web bin/rails db:migrate && git add db/schema.rb`.

`test/fixtures/review_votes.yml`:

```yaml
seth_votes_john_eagle_rare:
  user: seth
  review: john_eagle_rare
```

Run model test — green.

- [ ] **Step 3 — routes + controller.** Add to `config/routes.rb` after `resources :favorites, ...`: `resources :review_votes, only: [:create, :destroy]`.

`test/controllers/review_votes_controller_test.rb`:

```ruby
require "test_helper"

class ReviewVotesControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user votes for a review" do
    sign_in users(:seth)
    assert_difference "ReviewVote.count", 1 do
      post review_votes_path, params: { review_id: reviews(:john_eagle_rare).id }
    end
    assert_redirected_to review_path(reviews(:john_eagle_rare))
  end

  test "cannot vote for your own review" do
    sign_in users(:john)
    assert_no_difference "ReviewVote.count" do
      post review_votes_path, params: { review_id: reviews(:john_eagle_rare).id }
    end
  end

  test "unvoting destroys the record" do
    sign_in users(:seth)
    assert_difference "ReviewVote.count", -1 do
      delete review_vote_path(review_votes(:seth_votes_john_eagle_rare))
    end
  end

  test "cannot destroy someone else's vote" do
    sign_in users(:john)
    assert_no_difference "ReviewVote.count" do
      delete review_vote_path(review_votes(:seth_votes_john_eagle_rare))
    end
    assert_response :not_found
  end
end
```

`app/controllers/review_votes_controller.rb`:

```ruby
class ReviewVotesController < ApplicationController
  before_action :authenticate_user!

  def create
    review = Review.find(params[:review_id])
    current_user.review_votes.build(review: review).save
    redirect_to review_path(review)
  end

  def destroy
    vote = current_user.review_votes.find(params[:id])
    review = vote.review
    vote.destroy
    redirect_to review_path(review)
  end
end
```

Run controller test — green.

- [ ] **Step 4 — thumb button, wiring, bottle ordering.** `app/views/review_votes/_button.html.erb` (locals: `review`):

```erb
<% if user_signed_in? && review.user_id != current_user.id %>
  <% existing = current_user.review_votes.find_by(review: review) %>
  <% if existing %>
    <%= button_to "👍 #{review.votes_count}", review_vote_path(existing), method: :delete,
        class: "inline-flex cursor-pointer items-center gap-1 rounded-full border border-whiskey-300 bg-whiskey-50 px-3 py-1 text-sm font-semibold text-whiskey-800 transition hover:bg-whiskey-100" %>
  <% else %>
    <%= button_to "👍 #{review.votes_count}", review_votes_path(review_id: review.id), method: :post,
        class: "inline-flex cursor-pointer items-center gap-1 rounded-full border border-gray-300 px-3 py-1 text-sm font-semibold text-gray-600 transition hover:border-whiskey-300 hover:text-whiskey-700" %>
  <% end %>
<% else %>
  <span class="inline-flex items-center gap-1 rounded-full border border-gray-200 px-3 py-1 text-sm font-semibold text-gray-500">👍 <%= review.votes_count %></span>
<% end %>
```

`app/controllers/bottles_controller.rb#show` — change:

```ruby
@reviews = @bottle.reviews.includes(:user, event: [:society, :event_bottles]).order(votes_count: :desc, created_at: :desc)
```

`app/views/bottles/show.html.erb` — inside each review `<article>` (~line 63+), add near the header row: `<div class="mt-3"><%= render "review_votes/button", review: review %></div>`.

`app/views/reviews/show.html.erb` — after the rating/date `<p class="mt-3 text-cream/70">...</p>` closes (~line 25), still inside the centered header div: `<div class="mt-4 flex justify-center"><%= render "review_votes/button", review: @review %></div>`.

Run full suite — expect **288 runs** (279 + 5 model + 4 controller), 0 failures, 9 skips.

- [ ] **Step 5 — commit.**

```
git add -A
git commit -m "Add review_votes: thumbs-up with counter cache, reorder bottle tastings"
```

---

### Task 3: Circle sidebar on `/reviews` + `?feed=circle`

**Files:** create `app/views/reviews/_circle_row.html.erb`, `app/views/reviews/_circle_sidebar.html.erb`. Modify `app/models/review.rb`, `app/controllers/reviews_controller.rb`, `app/views/reviews/index.html.erb`, `test/controllers/reviews_controller_test.rb` (create if absent).

**Interfaces:** `Review.for_circle(user, limit: 5)` — latest reviews by `user.favorited_users` unioned with reviews whose `event.society` is favorited, deduped, newest first. `@circle_reviews` (index, signed-in, limit 5, sidebar). `params[:feed] == "circle"` → `@feed`, `@circle_feed_reviews` (limit 50, replaces the sidebar column with the full list — "beside the existing sort control, not replacing it," per addendum, applied here too).

- [ ] **Step 1 — failing test.** Create or extend `test/controllers/reviews_controller_test.rb`:

```ruby
require "test_helper"

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  test "signed-out index has no circle sidebar data" do
    get reviews_path
    assert_nil assigns(:circle_reviews)
  end

  test "signed-in index builds the circle feed from favorited users and societies" do
    sign_in users(:jane) # favorites john (User) and single_malt (Society)
    get reviews_path
    assert_response :success
    assert_includes assigns(:circle_reviews), reviews(:john_eagle_rare)
    assert_includes assigns(:circle_reviews), reviews(:john_spring_ardbeg) # tied to single_malt's spring_blind
  end

  test "circle feed excludes reviews outside the favorited set" do
    sign_in users(:john) # favorites nobody
    get reviews_path
    assert_empty assigns(:circle_reviews)
  end

  test "?feed=circle renders the full circle feed" do
    sign_in users(:jane)
    get reviews_path(feed: "circle")
    assert_response :success
    assert_select "h2", text: /circle/i
  end
end
```

Run — fails (`Review.for_circle` undefined).

- [ ] **Step 2 — `Review.for_circle` + controller.** `app/models/review.rb` — add near `scope :recent_first`:

```ruby
# Reviews from bookmarked people/societies: latest by favorited users, plus
# reviews tied to favorited societies' events. Deduped.
def self.for_circle(user, limit: 5)
  user_ids, society_ids = user.favorited_users.ids, user.favorited_societies.ids
  return none if user_ids.empty? && society_ids.empty?

  by_user = user_ids.any? ? where(user_id: user_ids) : none
  by_society = society_ids.any? ? joins(:event).where(events: { society_id: society_ids }) : none
  where(id: by_user.or(by_society).select(:id)).includes(:user, :bottle, event: [:society, :event_bottles]).recent_first.limit(limit)
end
```

`app/controllers/reviews_controller.rb#index` — after `@recent_reviews = ...`:

```ruby
@circle_reviews = current_user ? Review.for_circle(current_user) : nil
@feed = params[:feed] if %w[circle hot].include?(params[:feed])
@circle_feed_reviews = Review.for_circle(current_user, limit: 50) if @feed == "circle" && current_user
```

(`hot` case is inert until Task 4 defines `Review.hot_ranked`.)

- [ ] **Step 3 — sidebar partial + index layout.** `app/views/reviews/_circle_row.html.erb` (locals: `review` — shared by sidebar and full feed):

```erb
<%= link_to review_path(review), class: "block rounded-xl border border-gray-100 p-3 transition hover:border-whiskey-200 hover:bg-whiskey-50" do %>
  <div class="flex items-baseline justify-between gap-2">
    <span class="truncate font-semibold text-gray-900"><%= review.bottle.display_name %></span>
    <%= render "bottles/rating", value: review.rating.to_f %>
  </div>
  <p class="mt-1 text-sm text-gray-500"><%= review.user.first_name %> · <%= time_ago_in_words(review.created_at) %> ago</p>
  <%= render "reviews/event_line", review: review %>
<% end %>
```

`app/views/reviews/_circle_sidebar.html.erb` (locals: `circle_reviews`):

```erb
<div class="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
  <p class="eyebrow text-whiskey-600">From your circle</p>
  <h2 class="mb-4 mt-1 font-display text-lg font-semibold text-gray-900">Circle</h2>
  <% if circle_reviews.any? %>
    <div class="space-y-4"><%= render partial: "reviews/circle_row", collection: circle_reviews, as: :review %></div>
    <%= link_to "See all →", reviews_path(feed: "circle"), class: "mt-4 block text-sm font-semibold text-whiskey-700 hover:text-whiskey-600" %>
  <% else %>
    <p class="text-sm text-gray-500">Favorite a society or a fellow taster to see their pours here.</p>
    <%= link_to "Browse societies", reviews_path, class: "mt-2 inline-block text-sm font-semibold text-whiskey-700 hover:text-whiskey-600" %>
  <% end %>
</div>
```

`app/views/reviews/index.html.erb` — turn the page into a 3-col grid when signed in. Change the opening wrapper (~line 12-13):

```erb
  <div class="mx-auto max-w-6xl <%= 'grid gap-8 lg:grid-cols-3' if user_signed_in? %>">
    <div class="<%= 'lg:col-span-2' if user_signed_in? %>">
```

Close that extra div right before the final `</div></section>`, adding the third column:

```erb
    </div>
    <% if user_signed_in? %>
      <div class="mt-10 lg:mt-0">
        <% if @feed == "circle" %>
          <div class="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
            <p class="eyebrow text-whiskey-600">From your circle</p>
            <h2 class="mb-4 mt-1 font-display text-lg font-semibold text-gray-900">Your full circle feed</h2>
            <% if @circle_feed_reviews.any? %>
              <div class="space-y-4"><%= render partial: "reviews/circle_row", collection: @circle_feed_reviews, as: :review %></div>
            <% else %>
              <p class="text-sm text-gray-500">Favorite a society or a fellow taster to see their pours here.</p>
            <% end %>
            <%= link_to "← Back to all tastings", reviews_path, class: "mt-4 block text-sm font-semibold text-whiskey-700 hover:text-whiskey-600" %>
          </div>
        <% else %>
          <%= render "reviews/circle_sidebar", circle_reviews: @circle_reviews %>
        <% end %>
      </div>
    <% end %>
  </div>
</section>
```

The "Your full circle feed" `h2` satisfies the `?feed=circle` test's `assert_select "h2", text: /circle/i`.

Run full suite — expect **292 runs** (288 + 4), 0 failures, 9 skips.

- [ ] **Step 4 — commit.**

```
git add -A
git commit -m "Circle sidebar on /reviews: latest tastings from favorited users and societies"
```

---

### Task 4: `?feed=hot` (30-day trailing votes) + Latest/Circle/Hot pills

**Files:** create `app/views/reviews/_review_card.html.erb` (extracted from existing inline markup). Modify `app/models/review.rb`, `app/controllers/reviews_controller.rb`, `app/views/reviews/index.html.erb`, `test/controllers/reviews_controller_test.rb`, `test/models/review_test.rb` (extend if present, else fold cases into `review_vote_test.rb`'s file as a sibling class-less block — check first with `docker compose exec -T web bin/rails test test/models/review_test.rb 2>&1 | head -5`).

**Interfaces:** `Review.hot_ranked(since: 30.days.ago, limit: 30)` — LEFT JOIN to `review_votes` created within the window, grouped, ordered by window-vote-count DESC then `reviews.created_at DESC` (zero-vote rows included via LEFT JOIN, sorted last; ties newest-first per addendum). `@hot_reviews` when `@feed == "hot"`. Pills: Latest (no `feed` param) / Circle (signed-in only) / Hot, `link_to`, active pill highlighted, placed above the tastings heading.

- [ ] **Step 1 — failing tests.** Append to `test/models/review_test.rb`:

```ruby
test "hot_ranked orders by votes within the window, ties newest first" do
  old_review, new_review = reviews(:john_eagle_rare), reviews(:john_spring_ardbeg)
  ReviewVote.create!(user: users(:seth), review: old_review)
  ReviewVote.where(review: old_review).update_all(created_at: 45.days.ago) # push outside the window
  ReviewVote.create!(user: users(:jane), review: new_review) # in-window

  ranked = Review.hot_ranked.to_a
  assert_operator ranked.index(new_review), :<, ranked.index(old_review)
end

test "hot_ranked includes zero-vote reviews (LEFT JOIN)" do
  assert_includes Review.hot_ranked.to_a, reviews(:seth_spring_glendronach)
end
```

Append to `test/controllers/reviews_controller_test.rb`:

```ruby
test "?feed=hot renders hot tastings ranked by recent votes" do
  get reviews_path(feed: "hot")
  assert_response :success
  assert_select "h2", text: /hot/i
end

test "feed pills appear near the tastings heading" do
  get reviews_path
  assert_select "a", text: "Latest"
  assert_select "a", text: "Hot"
end
```

Run — fails (`Review.hot_ranked` undefined, no pills).

- [ ] **Step 2 — `Review.hot_ranked`.** `app/models/review.rb` — add near `for_circle`:

```ruby
# Tastings ranked by thumbs-up received in the trailing window — a delta
# ranking, distinct from the lifetime votes_count counter cache used on
# bottle pages. LEFT JOIN keeps zero-vote reviews (sorted last); ties break
# newest-first per the addendum.
def self.hot_ranked(since: 30.days.ago, limit: 30)
  select("reviews.*, COUNT(recent_votes.id) AS recent_votes_count")
    .joins("LEFT JOIN review_votes recent_votes ON recent_votes.review_id = reviews.id AND recent_votes.created_at >= #{sanitize_sql([since])}")
    .group("reviews.id")
    .order("recent_votes_count DESC, reviews.created_at DESC")
    .includes(:user, :bottle, event: [:society, :event_bottles])
    .limit(limit)
end
```

Run model tests — green.

- [ ] **Step 3 — controller + pills, DRY the card partial.** `app/controllers/reviews_controller.rb` — extend the `@feed` block: `@hot_reviews = Review.hot_ranked if @feed == "hot"`.

Extract the existing inline review-card markup (index.html.erb's "Fresh pours" `each` block, the `link_to review_path(review) do ... end`) into `app/views/reviews/_review_card.html.erb` (locals: `review`), adding one line for the hot feed's vote count:

```erb
<%= link_to review_path(review), class: "group flex h-56 flex-col rounded-2xl border border-gray-200 bg-white p-6 shadow-sm transition hover:border-whiskey-300 hover:shadow-md" do %>
  <div class="flex flex-wrap items-baseline justify-between gap-2">
    <span class="font-display text-lg font-semibold text-gray-900 group-hover:text-whiskey-800"><%= review.bottle.display_name %></span>
    <%= render "bottles/rating", value: review.rating.to_f %>
  </div>
  <% if review.notes.present? %>
    <p class="mt-3 line-clamp-4 text-gray-600"><%= review.notes %></p>
  <% elsif (peek = { "Nose" => review.nose, "Palate" => review.palate, "Finish" => review.finish }.compact_blank).any? %>
    <p class="mt-3 line-clamp-4 text-gray-600"><%= peek.map { |l, t| "#{l}: #{t}" }.join(" · ") %></p>
  <% end %>
  <%= render "reviews/event_line", review: review %>
  <div class="mt-auto flex items-center justify-between pt-4">
    <span class="text-sm text-gray-400">
      <% if review.respond_to?(:recent_votes_count) %>👍 <%= review.recent_votes_count %> this month · <% end %><%= review.user.first_name %> · <%= time_ago_in_words(review.created_at) %> ago
    </span>
    <span class="text-sm font-semibold text-whiskey-700">Read the tasting →</span>
  </div>
<% end %>
```

(`respond_to?(:recent_votes_count)` is true only for `Review.hot_ranked` rows, whose raw SQL `select` adds that column — Latest-feed rows fall back to the plain text.)

In `index.html.erb`, add pills above the "Fresh pours" section (~line 109) and gate that whole section on `@feed`, both branches rendering the shared partial:

```erb
<div class="mt-16">
  <div class="mb-4 flex items-center gap-2">
    <% { "Latest" => nil, "Circle" => "circle", "Hot" => "hot" }.each do |label, key| %>
      <% next if key == "circle" && !user_signed_in? %>
      <%= link_to label, reviews_path(request.query_parameters.merge(feed: key).compact_blank),
          class: "rounded-full px-4 py-1.5 text-sm font-semibold transition #{@feed == key ? 'bg-whiskey-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}" %>
    <% end %>
  </div>

  <% if @feed == "hot" %>
    <p class="eyebrow text-whiskey-600">Getting thumbs</p>
    <h2 class="mb-6 mt-1 font-display text-2xl font-semibold text-gray-900">Hot tastings</h2>
    <div class="grid gap-4 sm:grid-cols-2"><%= render partial: "reviews/review_card", collection: @hot_reviews, as: :review %></div>
  <% elsif @recent_reviews.any? && (params[:q].blank? || @tags.any? || @distillery) %>
    <p class="eyebrow text-whiskey-600">Fresh pours</p>
    <h2 class="mb-6 mt-1 font-display text-2xl font-semibold text-gray-900"><%= if @tags.any? then "Tastings of #{@tags.join(" + ")}" elsif @distillery then "Tastings from #{@distillery}" else "Latest tastings" end %></h2>
    <div class="grid gap-4 sm:grid-cols-2"><%= render partial: "reviews/review_card", collection: @recent_reviews, as: :review %></div>
  <% end %>
</div>
```

This replaces the old `<% if @recent_reviews.any? && ... %>...<% end %>` block in place (same wrapping `<div class="mt-16">`).

Run full suite — expect **296 runs** (292 + 4), 0 failures, 9 skips.

- [ ] **Step 4 — commit.**

```
git add -A
git commit -m "Hot feed (?feed=hot): 30-day trailing votes ranking; add feed pills"
```

---

### Task 5: Demo seeds + spec bookkeeping + push

**Files:** modify `db/seeds.rb`, `docs/superpowers/specs/2026-07-06-review-system-design.md`. No new code paths — data + docs only.

- [ ] **Step 1 — seed data.** In `db/seeds.rb`, after the existing review-seeding block, append (matching whichever local variable names `seeds.rb` actually uses for its users/societies/reviews — read the file first; this is illustrative):

```ruby
jane.favorites.find_or_create_by!(favoritable: john)
jane.favorites.find_or_create_by!(favoritable: single_malt)
seth.favorites.find_or_create_by!(favoritable: whiskey_lovers)

[john_eagle_rare_review, john_spring_ardbeg_review].compact.each do |review|
  [jane, seth].each { |voter| voter.review_votes.find_or_create_by!(review: review) unless review.user_id == voter.id }
end
```

Run `docker compose exec -T web bin/rails db:seed` — idempotent (`find_or_create_by!`), no errors.

- [ ] **Step 2 — spec bookkeeping.** Append to the end of the "Addendum (2026-07-07, owner-approved): the social layer (Phase 3-social)" section in `docs/superpowers/specs/2026-07-06-review-system-design.md`:

```markdown

**Implemented 2026-07-07.** See `docs/superpowers/plans/2026-07-07-review-system-social.md`.
```

- [ ] **Step 3 — final verification.** `docker compose exec -T web bin/rails test` — expect **296 runs, 0 failures, 9 skips** (268 baseline + 11 favorites + 9 review_votes + 4 circle + 4 hot).

- [ ] **Step 4 — commit + push.**

```
git add -A
git commit -m "Seed favorites/votes demo data; mark social-layer addendum implemented"
git push
```

---

## Ambiguities resolved

1. **Route shape:** addendum says "toggle buttons," no REST shape specified. Resolved to explicit `create`/`destroy` (mirrors the existing join/leave-society pattern) over a single toggle action.
2. **Circle sidebar vs. `?feed=circle`:** sidebar renders inline in the index's third grid column; `?feed=circle` swaps that column's content to the full (50-cap) list rather than navigating away — keeps search/sort/bottle-list visible throughout, consistent with the addendum's "beside the existing sort control, not replacing it."
3. **Hot feed scope:** addendum mentions vote-count ordering for both bottle-page tastings (lifetime `votes_count`) and the `/reviews` hot feed (30-day delta). Resolved: `?feed=hot` ranks **review records**, rendered in the same card grid as Latest — an addition alongside `Bottle::SORTS`, not a replacement for it.
4. **Self-favoriting:** not addressed in the addendum. Resolved: blocked, mirroring the "no self-vote" rule for review_votes.
5. **Stale favorites on revoked access** (e.g., removed from a private society you'd favorited): resolved by filtering at render time via `Pundit#show?` on the profile's own Favorites section, rather than a destroy-on-membership-change callback.
