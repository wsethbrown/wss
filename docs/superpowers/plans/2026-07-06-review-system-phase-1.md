# Review System Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the public bottle database — bottle catalog with user-added bottles, solo reviews, public bottle pages with aggregate scores, and a searchable bottles section.

**Architecture:** Two new tables (`bottles`, `reviews`) per the approved spec at `docs/superpowers/specs/2026-07-06-review-system-design.md`. `reviews.event_id` exists from day one (with both uniqueness indexes) but no Phase-1 UI sets it — event flows are Phase 2. Aggregates are computed queries, never stored. All pages follow the existing paper-surface design system (eyebrows, whiskey tokens, Fraunces display headings).

**Tech Stack:** Rails 8.0.2, PostgreSQL 15, Hotwire (Turbo/Stimulus), Tailwind v4 tokens already defined, Devise auth, Minitest with fixtures.

## Global Constraints

- Run everything through Docker: `docker compose exec -T web bin/rails ...` (tests, migrations, generators). The `jobs` container is irrelevant to this plan.
- Rating values: 0.5–5.0 in 0.5 steps, stored as `decimal(2,1)`. Free-form review text column is `notes` — NOT `body` (avoids colliding with the `body_notes` tasting field).
- One review per user per bottle per context: unique index on `(user_id, bottle_id, event_id)` PLUS partial unique index on `(user_id, bottle_id) WHERE event_id IS NULL`.
- Bottle name is required; distillery/region/style/abv optional. No hard uniqueness on bottles — near-match warning at creation instead.
- Copy is topic-generic where possible, but this feature is whiskey-first: "bottle" is the right noun.
- The existing suite (177 runs) must stay green after every task.
- Design system: white/whiskey-50 surfaces, `.eyebrow` for kickers, `font-display` for headings, `rounded-2xl border border-gray-200 bg-white shadow-sm` for cards, `bg-whiskey-600 hover:bg-whiskey-700` for primary buttons.

---

### Task 1: Bottle model

**Files:**
- Create: `db/migrate/<timestamp>_create_bottles.rb` (via generator)
- Create: `app/models/bottle.rb`
- Create: `test/fixtures/bottles.yml`
- Test: `test/models/bottle_test.rb`

**Interfaces:**
- Produces: `Bottle` with `name` (required), `distillery`, `region`, `style`, `abv`, `slug` (auto-generated, used in URLs via `to_param`), `created_by` (User, optional), `Bottle.search(term)` scope, `display_name` (name + distillery).

- [ ] **Step 1: Write the failing model test**

Create `test/models/bottle_test.rb`:

```ruby
require "test_helper"

class BottleTest < ActiveSupport::TestCase
  test "requires a name" do
    bottle = Bottle.new(name: "")
    assert_not bottle.valid?
    assert_includes bottle.errors[:name], "can't be blank"
  end

  test "generates a slug from name and distillery" do
    bottle = Bottle.create!(name: "Eagle Rare 10", distillery: "Buffalo Trace")
    assert_equal "eagle-rare-10-buffalo-trace", bottle.slug
    assert_equal bottle.slug, bottle.to_param
  end

  test "deduplicates slugs with a numeric suffix" do
    Bottle.create!(name: "Lagavulin 16")
    second = Bottle.create!(name: "Lagavulin 16")
    assert_equal "lagavulin-16-2", second.slug
  end

  test "search matches name and distillery case-insensitively" do
    eagle = bottles(:eagle_rare)
    assert_includes Bottle.search("eagle"), eagle
    assert_includes Bottle.search("BUFFALO"), eagle
    assert_not_includes Bottle.search("laphroaig"), eagle
  end

  test "display_name combines name and distillery" do
    assert_equal "Eagle Rare 10 — Buffalo Trace", bottles(:eagle_rare).display_name
    assert_equal "Housemade Amaro", Bottle.new(name: "Housemade Amaro").display_name
  end
end
```

Create `test/fixtures/bottles.yml`:

```yaml
eagle_rare:
  name: Eagle Rare 10
  distillery: Buffalo Trace
  region: Kentucky
  style: Bourbon
  abv: 45.0
  slug: eagle-rare-10-buffalo-trace

lagavulin:
  name: Lagavulin 16
  distillery: Lagavulin
  region: Islay
  style: Single Malt Scotch
  abv: 43.0
  slug: lagavulin-16-lagavulin
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose exec -T web bin/rails test test/models/bottle_test.rb`
Expected: FAIL — `NameError: uninitialized constant BottleTest::Bottle` (or table missing).

- [ ] **Step 3: Generate the migration and write the model**

Run: `docker compose exec -T web bin/rails generate migration CreateBottles --no-timestamps=false`

Replace the generated migration body (`db/migrate/<timestamp>_create_bottles.rb`):

```ruby
class CreateBottles < ActiveRecord::Migration[8.0]
  def change
    create_table :bottles do |t|
      t.string :name, null: false
      t.string :distillery
      t.string :region
      t.string :style
      t.decimal :abv, precision: 4, scale: 1
      t.string :slug, null: false
      t.references :created_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :bottles, :slug, unique: true
    # Case-insensitive lookup for autocomplete and near-match warnings.
    add_index :bottles, "lower(name), lower(coalesce(distillery, ''))",
              name: "index_bottles_on_lower_name_distillery"
  end
end
```

Create `app/models/bottle.rb`:

```ruby
class Bottle < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  has_many :reviews, dependent: :destroy

  validates :name, presence: true, length: { maximum: 200 }
  validates :distillery, :region, :style, length: { maximum: 200 }
  validates :abv, numericality: { greater_than: 0, less_than: 100 }, allow_nil: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  # Public URLs use the slug ("/bottles/eagle-rare-10-buffalo-trace").
  def to_param = slug

  def self.search(term)
    q = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where("bottles.name ILIKE :q OR bottles.distillery ILIKE :q", q: q)
  end

  def display_name
    [name, distillery].compact_blank.join(" — ")
  end

  private

  def generate_slug
    return if slug.present? || name.blank?

    base = [name, distillery].compact_blank.join(" ").parameterize
    candidate = base
    n = 1
    candidate = "#{base}-#{n += 1}" while Bottle.exists?(slug: candidate)
    self.slug = candidate
  end
end
```

- [ ] **Step 4: Migrate and run the test**

Run: `docker compose exec -T web bin/rails db:migrate && docker compose exec -T web bin/rails test test/models/bottle_test.rb`
Expected: PASS (5 tests).

- [ ] **Step 5: Run the full suite, then commit**

Run: `docker compose exec -T web bin/rails test`
Expected: 182 runs, 0 failures.

```bash
git add db/ app/models/bottle.rb test/models/bottle_test.rb test/fixtures/bottles.yml
git commit -m "Bottle catalog: model, slugs, case-insensitive search"
```

---

### Task 2: Review model + bottle aggregation

**Files:**
- Create: `db/migrate/<timestamp>_create_reviews.rb` (via generator)
- Create: `app/models/review.rb`
- Modify: `app/models/user.rb` (add `has_many :reviews`)
- Create: `test/fixtures/reviews.yml`
- Test: `test/models/review_test.rb`

**Interfaces:**
- Consumes: `Bottle` from Task 1.
- Produces: `Review` (`user`, `bottle`, optional `event`, `rating`, `notes`, `nose`, `palate`, `finish`, `body_notes`, `solo?`), `Bottle#average_rating` (Float or nil, latest review per user), `Bottle#reviewer_count` (Integer), `user.reviews`.

- [ ] **Step 1: Write the failing model test**

Create `test/models/review_test.rb`:

```ruby
require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  test "valid solo review saves" do
    review = Review.new(user: users(:jane), bottle: bottles(:lagavulin), rating: 4.5,
                        notes: "Peat and honey.")
    assert review.valid?, review.errors.full_messages.to_sentence
  end

  test "rating must be a half step between 0.5 and 5.0" do
    review = reviews(:john_eagle_rare)
    [0.0, 5.5, 4.3, -1].each do |bad|
      review.rating = bad
      assert_not review.valid?, "#{bad} should be invalid"
    end
    [0.5, 3.0, 4.5, 5.0].each do |good|
      review.rating = good
      assert review.valid?, "#{good} should be valid"
    end
  end

  test "one solo review per user per bottle" do
    dup = Review.new(user: users(:john), bottle: bottles(:eagle_rare), rating: 3.0)
    assert_not dup.valid?
    assert_includes dup.errors[:bottle_id], "already has your review — edit it instead"
  end

  test "solo? distinguishes event-tagged reviews" do
    assert reviews(:john_eagle_rare).solo?
  end

  test "average_rating uses each user's latest review" do
    bottle = bottles(:eagle_rare) # fixture review: john at 4.0
    Review.create!(user: users(:jane), bottle: bottle, rating: 5.0)
    assert_in_delta 4.5, bottle.average_rating, 0.001
    assert_equal 2, bottle.reviewer_count
  end

  test "average_rating is nil with no reviews" do
    assert_nil bottles(:lagavulin).average_rating
    assert_equal 0, bottles(:lagavulin).reviewer_count
  end
end
```

Create `test/fixtures/reviews.yml`:

```yaml
john_eagle_rare:
  user: john
  bottle: eagle_rare
  rating: 4.0
  notes: Cherry and oak, long finish.
  nose: Toffee, orange peel
  palate: Cherry, leather
  finish: Long, drying oak
  body_notes: Medium, silky
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose exec -T web bin/rails test test/models/review_test.rb`
Expected: FAIL — `uninitialized constant ReviewTest::Review`.

- [ ] **Step 3: Generate the migration, write the model, wire associations**

Run: `docker compose exec -T web bin/rails generate migration CreateReviews`

Replace the migration body:

```ruby
class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :bottle, null: false, foreign_key: true
      # Present from day one; no Phase-1 UI sets it. Event flows are Phase 2.
      t.references :event, null: true, foreign_key: true
      t.decimal :rating, precision: 2, scale: 1, null: false
      t.text :notes
      t.string :nose
      t.string :palate
      t.string :finish
      t.string :body_notes

      t.timestamps
    end

    # One review per tasting context...
    add_index :reviews, [:user_id, :bottle_id, :event_id], unique: true
    # ...and NULL event_id rows are all "solo", so they need their own guard
    # (Postgres treats NULLs as distinct in the index above).
    add_index :reviews, [:user_id, :bottle_id], unique: true,
              where: "event_id IS NULL", name: "index_reviews_solo_uniqueness"
  end
end
```

Create `app/models/review.rb`:

```ruby
class Review < ApplicationRecord
  VALID_RATINGS = (1..10).map { |n| n / 2.0 }.freeze # 0.5 .. 5.0 in half steps

  belongs_to :user
  belongs_to :bottle
  belongs_to :event, optional: true

  validates :rating, presence: true, inclusion: { in: VALID_RATINGS }
  validates :notes, length: { maximum: 5_000 }
  validates :nose, :palate, :finish, :body_notes, length: { maximum: 500 }
  validates :bottle_id, uniqueness: {
    scope: [:user_id, :event_id],
    message: "already has your review — edit it instead"
  }

  scope :recent_first, -> { order(created_at: :desc) }

  # A tasting outside any event. Event-tagged reviews arrive in Phase 2.
  def solo? = event_id.nil?
end
```

Add to `app/models/bottle.rb`, below `display_name`:

```ruby
  # The public score: each reviewer counts once, via their latest tasting
  # (re-tastes at events arrive in Phase 2 and refresh their contribution).
  def average_rating
    latest_per_user.average(:rating)&.to_f&.round(2)
  end

  def reviewer_count
    reviews.distinct.count(:user_id)
  end

  private

  def latest_per_user
    reviews.where(
      id: reviews.select("DISTINCT ON (user_id) id").order(:user_id, created_at: :desc)
    )
  end
```

(Keep `generate_slug` inside `private` as well — one `private` section.)

Add to `app/models/user.rb` beside the other `has_many` declarations:

```ruby
  has_many :reviews, dependent: :destroy
```

- [ ] **Step 4: Migrate and run the test**

Run: `docker compose exec -T web bin/rails db:migrate && docker compose exec -T web bin/rails test test/models/review_test.rb`
Expected: PASS (6 tests).

- [ ] **Step 5: Run the full suite, then commit**

Run: `docker compose exec -T web bin/rails test`
Expected: 188 runs, 0 failures.

```bash
git add db/ app/models/ test/models/review_test.rb test/fixtures/reviews.yml
git commit -m "Reviews: solo tastings with per-context uniqueness; bottle score = latest per reviewer"
```

---

### Task 3: Bottles section — index, search endpoint, bottle page

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/bottles_controller.rb`
- Create: `app/views/bottles/index.html.erb`
- Create: `app/views/bottles/show.html.erb`
- Create: `app/views/bottles/_rating.html.erb`
- Test: `test/integration/bottles_test.rb`

**Interfaces:**
- Consumes: `Bottle.search`, `Bottle#average_rating`, `#reviewer_count`, `#display_name`, `Review#solo?`, `reviews.recent_first`.
- Produces: routes `bottles_path`, `bottle_path(bottle)` (slug), `search_bottles_path(format: :json)`; partial `bottles/rating` with local `value:`; `@bottle` lookup by slug.

- [ ] **Step 1: Write the failing integration test**

Create `test/integration/bottles_test.rb`:

```ruby
require "test_helper"

class BottlesTest < ActionDispatch::IntegrationTest
  test "index lists bottles and recent reviews, signed out" do
    get bottles_path
    assert_response :success
    assert_select "h1", text: /The bottle library/i
    assert_match "Eagle Rare 10", response.body
    assert_match "Cherry and oak", response.body # recent review feed
  end

  test "index filters by search term" do
    get bottles_path(q: "lagavulin")
    assert_response :success
    assert_match "Lagavulin 16", response.body
    assert_no_match "Eagle Rare 10", response.body
  end

  test "search endpoint returns JSON matches" do
    get search_bottles_path(q: "eagle", format: :json)
    assert_response :success
    names = response.parsed_body.map { |b| b["name"] }
    assert_includes names, "Eagle Rare 10"
  end

  test "bottle page shows score, reviews, and slug routing" do
    get bottle_path(bottles(:eagle_rare))
    assert_response :success
    assert_match "Eagle Rare 10", response.body
    assert_match "4.0", response.body            # aggregate from the one fixture review
    assert_match "Cherry and oak", response.body # the review feed
  end

  test "unknown slug 404s" do
    get bottle_path(id: "not-a-bottle")
    assert_response :not_found
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose exec -T web bin/rails test test/integration/bottles_test.rb`
Expected: FAIL — `NameError: undefined local variable or method 'bottles_path'`.

- [ ] **Step 3: Routes and controller**

In `config/routes.rb`, next to the other public resources (near `resources :presentations`):

```ruby
  resources :bottles, only: [:index, :show, :new, :create], param: :id do
    collection { get :search }
    resources :reviews, only: [:new, :create], module: :bottles
  end
  resources :reviews, only: [:edit, :update, :destroy]
```

(The nested `reviews` routes are used in Task 5; declaring them now keeps routing in one commit. The `module: :bottles` scoping gives `Bottles::ReviewsController`.)

Create `app/controllers/bottles_controller.rb`:

```ruby
class BottlesController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create]

  def index
    @bottles = Bottle.order(:name)
    @bottles = @bottles.search(params[:q]) if params[:q].present?
    @recent_reviews = Review.includes(:user, :bottle).recent_first.limit(10)
  end

  def show
    @bottle = Bottle.find_by!(slug: params[:id])
    @reviews = @bottle.reviews.includes(:user).recent_first
    @my_review = current_user && @bottle.reviews.find_by(user: current_user, event_id: nil)
  end

  def search
    bottles = Bottle.search(params[:q]).order(:name).limit(8)
    render json: bottles.map { |b|
      { name: b.name, display_name: b.display_name, url: bottle_path(b) }
    }
  end

  # new/create arrive in Task 4; stubs keep the routes honest until then.
  def new
    @bottle = Bottle.new(name: params[:name])
  end

  def create
    head :unprocessable_entity
  end
end
```

- [ ] **Step 4: Views**

Create `app/views/bottles/_rating.html.erb` (renders a score like `★★★★½`):

```erb
<%# locals: value (Float 0.5..5.0 or nil) %>
<% if value %>
  <span class="whitespace-nowrap text-whiskey-600" aria-label="<%= value %> out of 5">
    <%= "★" * value.floor %><%= "½" if (value % 1) >= 0.5 %><span class="text-whiskey-200"><%= "★" * (5 - value.ceil) %></span>
  </span>
<% else %>
  <span class="text-sm text-gray-400">No tastings yet</span>
<% end %>
```

Create `app/views/bottles/index.html.erb`:

```erb
<% content_for :title, "Bottles - Whiskey Share Society" %>

<section class="w-full bg-char px-4 py-16 text-center">
  <p class="eyebrow mb-4 text-whiskey-300/90">The pours, on the record</p>
  <h1 class="font-display text-4xl font-semibold text-cream sm:text-5xl">The bottle library</h1>
  <p class="mx-auto mt-4 max-w-2xl text-cream/80">
    Every bottle the society has tasted and rated — add yours, and say what you found in the glass.
  </p>
</section>

<section class="w-full bg-white px-4 py-14">
  <div class="mx-auto max-w-6xl">
    <div class="mb-10 flex flex-wrap items-center justify-between gap-4"
         data-controller="bottle-search" data-bottle-search-url-value="<%= search_bottles_path %>">
      <%= form_with url: bottles_path, method: :get, class: "relative w-full max-w-xl" do %>
        <input type="search" name="q" value="<%= params[:q] %>" placeholder="Search bottles or distilleries…"
               autocomplete="off"
               data-bottle-search-target="input" data-action="input->bottle-search#query"
               class="w-full rounded-xl border border-gray-300 px-4 py-3 focus:outline-none focus:ring-2 focus:ring-whiskey-500">
        <div data-bottle-search-target="results"
             class="absolute inset-x-0 top-full z-20 mt-1 hidden overflow-hidden rounded-xl border border-gray-200 bg-white shadow-lg"></div>
      <% end %>
      <% if user_signed_in? %>
        <%= link_to "Add a bottle", new_bottle_path, class: "rounded-xl bg-whiskey-600 px-5 py-3 font-semibold text-white transition hover:bg-whiskey-700" %>
      <% end %>
    </div>

    <p class="mb-8 text-gray-600">
      <%= pluralize(@bottles.count, "bottle") %><%= " matching “#{params[:q]}”" if params[:q].present? %>
    </p>

    <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
      <% @bottles.each do |bottle| %>
        <%= link_to bottle_path(bottle), class: "group rounded-2xl border border-gray-200 bg-white p-6 shadow-sm transition hover:border-whiskey-300 hover:shadow-md" do %>
          <p class="eyebrow text-whiskey-600"><%= [bottle.style, bottle.region].compact_blank.join(" · ").presence || "Bottle" %></p>
          <h2 class="mt-2 font-display text-xl font-semibold text-gray-900 group-hover:text-whiskey-800"><%= bottle.name %></h2>
          <% if bottle.distillery.present? %><p class="mt-1 text-sm text-gray-500"><%= bottle.distillery %></p><% end %>
          <div class="mt-4 flex items-center justify-between">
            <%= render "bottles/rating", value: bottle.average_rating %>
            <% if bottle.reviewer_count.positive? %>
              <span class="text-sm text-gray-500"><%= pluralize(bottle.reviewer_count, "reviewer") %></span>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>

    <% if @recent_reviews.any? && params[:q].blank? %>
      <div class="mt-16">
        <p class="eyebrow text-whiskey-600">Fresh pours</p>
        <h2 class="mb-6 mt-1 font-display text-2xl font-semibold text-gray-900">Latest tastings</h2>
        <div class="space-y-4">
          <% @recent_reviews.each do |review| %>
            <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
              <div class="flex flex-wrap items-baseline justify-between gap-2">
                <%= link_to review.bottle.display_name, bottle_path(review.bottle), class: "font-display text-lg font-semibold text-gray-900 hover:text-whiskey-700" %>
                <%= render "bottles/rating", value: review.rating.to_f %>
              </div>
              <% if review.notes.present? %><p class="mt-2 text-gray-600"><%= truncate(review.notes, length: 200) %></p><% end %>
              <p class="mt-2 text-sm text-gray-400"><%= review.user.first_name %> · <%= time_ago_in_words(review.created_at) %> ago</p>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</section>
```

Create `app/views/bottles/show.html.erb`:

```erb
<% content_for :title, "#{@bottle.name} - Whiskey Share Society" %>

<section class="w-full bg-char px-4 py-16">
  <div class="mx-auto max-w-3xl text-center">
    <p class="eyebrow mb-4 text-whiskey-300/90">
      <%= [@bottle.style, @bottle.region, (@bottle.abv && "#{@bottle.abv.to_f % 1 == 0 ? @bottle.abv.to_i : @bottle.abv}% ABV")].compact_blank.join(" · ").presence || "Bottle" %>
    </p>
    <h1 class="font-display text-4xl font-semibold text-cream sm:text-5xl"><%= @bottle.name %></h1>
    <% if @bottle.distillery.present? %><p class="mt-3 text-lg text-cream/80"><%= @bottle.distillery %></p><% end %>
    <div class="mt-6 flex items-center justify-center gap-3 text-xl">
      <%= render "bottles/rating", value: @bottle.average_rating %>
      <% if @bottle.average_rating %>
        <span class="font-semibold text-cream"><%= number_with_precision(@bottle.average_rating, precision: 1) %></span>
        <span class="text-cream/60">· <%= pluralize(@bottle.reviewer_count, "reviewer") %></span>
      <% end %>
    </div>
    <div class="mt-8">
      <% if !user_signed_in? %>
        <%= link_to "Sign in to review this bottle", new_user_session_path, class: "inline-flex rounded-xl bg-whiskey-500 px-6 py-3 font-semibold text-white transition hover:bg-whiskey-400" %>
      <% elsif @my_review %>
        <%= link_to "Update your review", edit_review_path(@my_review), class: "inline-flex rounded-xl bg-whiskey-500 px-6 py-3 font-semibold text-white transition hover:bg-whiskey-400" %>
      <% else %>
        <%= link_to "Review this bottle", new_bottle_review_path(@bottle), class: "inline-flex rounded-xl bg-whiskey-500 px-6 py-3 font-semibold text-white transition hover:bg-whiskey-400" %>
      <% end %>
    </div>
  </div>
</section>

<section class="w-full bg-white px-4 py-14">
  <div class="mx-auto max-w-3xl">
    <p class="eyebrow text-whiskey-600">On the record</p>
    <h2 class="mb-8 mt-1 font-display text-2xl font-semibold text-gray-900">Tastings</h2>

    <% if @reviews.none? %>
      <p class="text-gray-600">No one has reviewed this bottle yet. Be the first pour.</p>
    <% end %>

    <div class="space-y-6">
      <% @reviews.each do |review| %>
        <article class="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
          <div class="flex flex-wrap items-baseline justify-between gap-2">
            <span class="font-semibold text-gray-900"><%= review.user.first_name %> <%= review.user.last_name %></span>
            <%= render "bottles/rating", value: review.rating.to_f %>
          </div>
          <%# Provenance badges (event/society/deck) arrive in Phase 2 — solo only here. %>
          <% if review.notes.present? %><p class="mt-3 whitespace-pre-line text-gray-700"><%= review.notes %></p><% end %>
          <% tasting = { "Nose" => review.nose, "Palate" => review.palate, "Finish" => review.finish, "Body" => review.body_notes }.compact_blank %>
          <% if tasting.any? %>
            <dl class="mt-4 grid grid-cols-2 gap-x-6 gap-y-3 border-t border-gray-100 pt-4 sm:grid-cols-4">
              <% tasting.each do |label, text| %>
                <div><dt class="eyebrow text-whiskey-700"><%= label %></dt><dd class="mt-1 text-sm text-gray-600"><%= text %></dd></div>
              <% end %>
            </dl>
          <% end %>
          <div class="mt-3 flex items-center justify-between">
            <p class="text-sm text-gray-400"><%= review.created_at.strftime("%B %-d, %Y") %></p>
            <% if review.user == current_user %>
              <%= link_to "Edit", edit_review_path(review), class: "text-sm font-semibold text-whiskey-700 hover:text-whiskey-600" %>
            <% end %>
          </div>
        </article>
      <% end %>
    </div>
  </div>
</section>
```

- [ ] **Step 5: Run the integration test**

Run: `docker compose exec -T web bin/rails test test/integration/bottles_test.rb`
Expected: PASS (5 tests). The 404 test passes because `find_by!` raises `RecordNotFound`, which Rails maps to 404 in integration tests.

- [ ] **Step 6: Run the full suite, then commit**

Run: `docker compose exec -T web bin/rails test`
Expected: 193 runs, 0 failures.

```bash
git add config/routes.rb app/controllers/bottles_controller.rb app/views/bottles test/integration/bottles_test.rb
git commit -m "Bottle library: public index with search, JSON autocomplete endpoint, bottle pages"
```

---

### Task 4: Add-a-bottle flow with near-match warning + autocomplete dropdown

**Files:**
- Modify: `app/controllers/bottles_controller.rb` (replace the `new`/`create` stubs)
- Create: `app/views/bottles/new.html.erb`
- Create: `app/javascript/controllers/bottle_search_controller.js`
- Test: `test/integration/bottle_creation_test.rb`

**Interfaces:**
- Consumes: routes from Task 3 (`new_bottle_path`, `bottles_path`, `search_bottles_path`).
- Produces: working `POST /bottles` with `confirmed_duplicate` param contract; the `bottle-search` Stimulus controller used by the index page markup from Task 3.

- [ ] **Step 1: Write the failing integration test**

Create `test/integration/bottle_creation_test.rb`:

```ruby
require "test_helper"

class BottleCreationTest < ActionDispatch::IntegrationTest
  test "requires sign in" do
    get new_bottle_path
    assert_redirected_to new_user_session_path
  end

  test "creates a bottle and lands on its page" do
    sign_in users(:jane)
    assert_difference "Bottle.count", 1 do
      post bottles_path, params: { bottle: {
        name: "Redbreast 12", distillery: "Midleton", region: "Ireland",
        style: "Single Pot Still", abv: 40.0
      } }
    end
    bottle = Bottle.find_by!(name: "Redbreast 12")
    assert_equal users(:jane), bottle.created_by
    assert_redirected_to bottle_path(bottle)
  end

  test "near-match warns instead of creating, then creates when confirmed" do
    sign_in users(:jane)
    assert_no_difference "Bottle.count" do
      post bottles_path, params: { bottle: { name: "Eagle Rare" } }
    end
    assert_response :unprocessable_entity
    assert_match "Eagle Rare 10", response.body # the existing near-match, offered as a link

    assert_difference "Bottle.count", 1 do
      post bottles_path, params: { bottle: { name: "Eagle Rare" }, confirmed_duplicate: "1" }
    end
  end

  test "invalid bottle re-renders the form" do
    sign_in users(:jane)
    assert_no_difference "Bottle.count" do
      post bottles_path, params: { bottle: { name: "" } }
    end
    assert_response :unprocessable_entity
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose exec -T web bin/rails test test/integration/bottle_creation_test.rb`
Expected: FAIL — the `create` stub returns 422 with no body, so the "creates a bottle" test fails.

- [ ] **Step 3: Implement new/create with the near-match warning**

In `app/controllers/bottles_controller.rb`, replace the `new` and `create` stubs:

```ruby
  def new
    @bottle = Bottle.new(name: params[:name])
    @near_matches = []
  end

  def create
    @bottle = Bottle.new(bottle_params)
    @bottle.created_by = current_user

    # Soft dedup: same search the autocomplete uses. The user can click an
    # existing bottle instead, or confirm theirs is genuinely different.
    @near_matches = params[:confirmed_duplicate] == "1" ? [] : Bottle.search(@bottle.name).limit(5)
    if @near_matches.any?
      render :new, status: :unprocessable_entity
      return
    end

    if @bottle.save
      redirect_to bottle_path(@bottle), notice: "#{@bottle.name} is on the shelf — add your tasting."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def bottle_params
    params.require(:bottle).permit(:name, :distillery, :region, :style, :abv)
  end
```

- [ ] **Step 4: The form view**

Create `app/views/bottles/new.html.erb`:

```erb
<% content_for :title, "Add a bottle - Whiskey Share Society" %>

<section class="w-full bg-whiskey-50 px-4 py-14">
  <div class="mx-auto max-w-xl">
    <p class="eyebrow text-whiskey-600">The bottle library</p>
    <h1 class="mb-8 mt-1 font-display text-3xl font-semibold text-gray-900">Add a bottle</h1>

    <% if @near_matches.any? %>
      <div class="mb-6 rounded-2xl border border-amber-200 bg-amber-50 p-5">
        <p class="font-semibold text-amber-900">Is it one of these?</p>
        <ul class="mt-3 space-y-2">
          <% @near_matches.each do |match| %>
            <li><%= link_to match.display_name, bottle_path(match), class: "font-medium text-whiskey-700 underline-offset-2 hover:underline" %></li>
          <% end %>
        </ul>
        <p class="mt-3 text-sm text-amber-800">If yours is genuinely different, save again and it'll go through.</p>
      </div>
    <% end %>

    <%= form_with model: @bottle, class: "space-y-5 rounded-2xl border border-gray-200 bg-white p-6 shadow-sm" do |form| %>
      <% if @bottle.errors.any? %>
        <div class="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          <%= @bottle.errors.full_messages.to_sentence %>
        </div>
      <% end %>
      <% if @near_matches.any? %><input type="hidden" name="confirmed_duplicate" value="1"><% end %>

      <div>
        <%= form.label :name, "Bottle name", class: "mb-2 block text-sm font-medium text-gray-700" %>
        <%= form.text_field :name, placeholder: "e.g., Eagle Rare 10", class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
      </div>
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
        <div>
          <%= form.label :distillery, class: "mb-2 block text-sm font-medium text-gray-700" %>
          <%= form.text_field :distillery, placeholder: "e.g., Buffalo Trace", class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
        </div>
        <div>
          <%= form.label :region, class: "mb-2 block text-sm font-medium text-gray-700" %>
          <%= form.text_field :region, placeholder: "e.g., Kentucky · Islay", class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
        </div>
        <div>
          <%= form.label :style, class: "mb-2 block text-sm font-medium text-gray-700" %>
          <%= form.text_field :style, placeholder: "e.g., Bourbon · Single Malt", class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
        </div>
        <div>
          <%= form.label :abv, "ABV %", class: "mb-2 block text-sm font-medium text-gray-700" %>
          <%= form.number_field :abv, step: 0.1, min: 0, max: 99, placeholder: "45.0", class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
        </div>
      </div>

      <div class="flex items-center gap-3 pt-2">
        <%= form.submit "Add the bottle", class: "cursor-pointer rounded-xl bg-whiskey-600 px-6 py-3 font-semibold text-white transition hover:bg-whiskey-700" %>
        <%= link_to "Cancel", bottles_path, class: "rounded-xl bg-gray-100 px-6 py-3 font-semibold text-gray-700 transition hover:bg-gray-200" %>
      </div>
    <% end %>
  </div>
</section>
```

- [ ] **Step 5: The autocomplete Stimulus controller**

Create `app/javascript/controllers/bottle_search_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

// Live search over the bottle catalog. Renders matches as links plus an
// "add a new bottle" escape hatch so the flow never dead-ends.
export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  query() {
    clearTimeout(this.timer)
    const q = this.inputTarget.value.trim()
    if (q.length < 2) { this.resultsTarget.classList.add("hidden"); return }
    this.timer = setTimeout(() => this.fetch(q), 200)
  }

  async fetch(q) {
    const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
      headers: { Accept: "application/json" }
    })
    if (!response.ok) return
    this.render(await response.json(), q)
  }

  render(matches, q) {
    this.resultsTarget.textContent = ""
    for (const match of matches) {
      const link = document.createElement("a")
      link.href = match.url
      link.textContent = match.display_name
      link.className = "block px-4 py-2.5 text-gray-800 hover:bg-whiskey-50"
      this.resultsTarget.appendChild(link)
    }
    const add = document.createElement("a")
    add.href = `/bottles/new?name=${encodeURIComponent(q)}`
    add.textContent = `+ Add “${q}” as a new bottle`
    add.className = "block border-t border-gray-100 px-4 py-2.5 font-medium text-whiskey-700 hover:bg-whiskey-50"
    this.resultsTarget.appendChild(add)
    this.resultsTarget.classList.remove("hidden")
  }

  disconnect() { clearTimeout(this.timer) }
}
```

- [ ] **Step 6: Run the test, then the suite**

Run: `docker compose exec -T web bin/rails test test/integration/bottle_creation_test.rb`
Expected: PASS (4 tests).

Run: `docker compose exec -T web bin/rails test`
Expected: 197 runs, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/bottles_controller.rb app/views/bottles/new.html.erb app/javascript/controllers/bottle_search_controller.js test/integration/bottle_creation_test.rb
git commit -m "Add-a-bottle: near-match warning before create, autocomplete dropdown with add-new escape"
```

---

### Task 5: Solo review CRUD

**Files:**
- Create: `app/controllers/bottles/reviews_controller.rb`
- Create: `app/controllers/reviews_controller.rb`
- Create: `app/views/bottles/reviews/new.html.erb`
- Create: `app/views/reviews/edit.html.erb`
- Create: `app/views/reviews/_form.html.erb`
- Test: `test/integration/reviews_test.rb`

**Interfaces:**
- Consumes: routes declared in Task 3 (`new_bottle_review_path(bottle)`, `bottle_reviews_path(bottle)`, `edit_review_path(review)`, `review_path(review)`); `Review::VALID_RATINGS`.
- Produces: full solo-review lifecycle; the shared `reviews/form` partial with locals `review:` and `url:`.

- [ ] **Step 1: Write the failing integration test**

Create `test/integration/reviews_test.rb`:

```ruby
require "test_helper"

class ReviewsTest < ActionDispatch::IntegrationTest
  test "review requires sign in" do
    get new_bottle_review_path(bottles(:lagavulin))
    assert_redirected_to new_user_session_path
  end

  test "creates a solo review" do
    sign_in users(:jane)
    assert_difference "Review.count", 1 do
      post bottle_reviews_path(bottles(:lagavulin)), params: { review: {
        rating: "4.5", notes: "Campfire and sea spray.", nose: "Peat smoke",
        palate: "Brine, vanilla", finish: "Endless smoke", body_notes: "Oily"
      } }
    end
    review = Review.last
    assert_equal users(:jane), review.user
    assert review.solo?
    assert_redirected_to bottle_path(bottles(:lagavulin))
  end

  test "second solo review of the same bottle is rejected" do
    sign_in users(:john) # fixture john_eagle_rare exists
    assert_no_difference "Review.count" do
      post bottle_reviews_path(bottles(:eagle_rare)), params: { review: { rating: "3.0" } }
    end
    assert_response :unprocessable_entity
  end

  test "author can edit their review" do
    sign_in users(:john)
    patch review_path(reviews(:john_eagle_rare)), params: { review: { rating: "3.5", notes: "Revisited: softer than I remembered." } }
    assert_redirected_to bottle_path(bottles(:eagle_rare))
    assert_equal 3.5, reviews(:john_eagle_rare).reload.rating.to_f
  end

  test "non-author cannot edit or destroy" do
    sign_in users(:jane)
    patch review_path(reviews(:john_eagle_rare)), params: { review: { rating: "1.0" } }
    assert_response :not_found
    assert_equal 4.0, reviews(:john_eagle_rare).reload.rating.to_f
  end

  test "author can delete their review" do
    sign_in users(:john)
    assert_difference "Review.count", -1 do
      delete review_path(reviews(:john_eagle_rare))
    end
    assert_redirected_to bottle_path(bottles(:eagle_rare))
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose exec -T web bin/rails test test/integration/reviews_test.rb`
Expected: FAIL — `uninitialized constant Bottles::ReviewsController` (routes exist from Task 3; the controller doesn't).

- [ ] **Step 3: Controllers**

Create `app/controllers/bottles/reviews_controller.rb`:

```ruby
# Creating a review in the context of a bottle (solo tastings — Phase 1).
# Event-tagged creation arrives in Phase 2 via the event page.
class Bottles::ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bottle

  def new
    @review = @bottle.reviews.new
  end

  def create
    @review = @bottle.reviews.new(review_params)
    @review.user = current_user

    if @review.save
      redirect_to bottle_path(@bottle), notice: "Your tasting is on the record."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_bottle
    @bottle = Bottle.find_by!(slug: params[:bottle_id])
  end

  def review_params
    params.require(:review).permit(:rating, :notes, :nose, :palate, :finish, :body_notes)
  end
end
```

Create `app/controllers/reviews_controller.rb`:

```ruby
# Editing/removing an existing review. Author-only: anyone else gets a 404
# (not a 403 — no need to confirm the review exists).
class ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_review

  def edit; end

  def update
    if @review.update(review_params)
      redirect_to bottle_path(@review.bottle), notice: "Review updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @review.destroy
    redirect_to bottle_path(@review.bottle), notice: "Review removed."
  end

  private

  def set_review
    @review = current_user.reviews.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:rating, :notes, :nose, :palate, :finish, :body_notes)
  end
end
```

- [ ] **Step 4: Views**

Create `app/views/reviews/_form.html.erb`:

```erb
<%# locals: review, url %>
<%= form_with model: review, url: url, class: "space-y-5 rounded-2xl border border-gray-200 bg-white p-6 shadow-sm" do |form| %>
  <% if review.errors.any? %>
    <div class="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
      <%= review.errors.full_messages.to_sentence %>
    </div>
  <% end %>

  <div>
    <%= form.label :rating, class: "mb-2 block text-sm font-medium text-gray-700" %>
    <%= form.select :rating,
        options_for_select(Review::VALID_RATINGS.reverse.map { |r| ["#{format('%g', r)} / 5", r] }, review.rating&.to_f),
        { include_blank: "Pick a rating" },
        { class: "w-full rounded-lg border border-gray-300 bg-white px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" } %>
  </div>

  <div>
    <%= form.label :notes, "Your tasting, in your words", class: "mb-2 block text-sm font-medium text-gray-700" %>
    <%= form.text_area :notes, rows: 5, placeholder: "What the pour was like, what it reminded you of, whether you'd pour it again…", class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
  </div>

  <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
    <% { nose: "Nose", palate: "Palate", finish: "Finish", body_notes: "Body" }.each do |field, label| %>
      <div>
        <%= form.label field, label, class: "mb-2 block text-sm font-medium text-gray-700" %>
        <%= form.text_field field, class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
      </div>
    <% end %>
  </div>

  <div class="flex items-center gap-3 pt-2">
    <%= form.submit class: "cursor-pointer rounded-xl bg-whiskey-600 px-6 py-3 font-semibold text-white transition hover:bg-whiskey-700" %>
    <%= link_to "Cancel", bottle_path(review.bottle), class: "rounded-xl bg-gray-100 px-6 py-3 font-semibold text-gray-700 transition hover:bg-gray-200" %>
  </div>
<% end %>
```

Create `app/views/bottles/reviews/new.html.erb`:

```erb
<% content_for :title, "Review #{@bottle.name} - Whiskey Share Society" %>

<section class="w-full bg-whiskey-50 px-4 py-14">
  <div class="mx-auto max-w-xl">
    <p class="eyebrow text-whiskey-600"><%= @bottle.display_name %></p>
    <h1 class="mb-8 mt-1 font-display text-3xl font-semibold text-gray-900">Your tasting</h1>
    <%= render "reviews/form", review: @review, url: bottle_reviews_path(@bottle) %>
  </div>
</section>
```

Create `app/views/reviews/edit.html.erb`:

```erb
<% content_for :title, "Edit review - Whiskey Share Society" %>

<section class="w-full bg-whiskey-50 px-4 py-14">
  <div class="mx-auto max-w-xl">
    <p class="eyebrow text-whiskey-600"><%= @review.bottle.display_name %></p>
    <h1 class="mb-8 mt-1 font-display text-3xl font-semibold text-gray-900">Edit your tasting</h1>
    <%= render "reviews/form", review: @review, url: review_path(@review) %>
    <%= button_to "Delete this review", review_path(@review), method: :delete,
        form: { data: { turbo_confirm: "Remove your review of #{@review.bottle.name}?" } },
        class: "mt-4 cursor-pointer text-sm font-semibold text-red-600 hover:text-red-700" %>
  </div>
</section>
```

- [ ] **Step 5: Run the test, then the suite**

Run: `docker compose exec -T web bin/rails test test/integration/reviews_test.rb`
Expected: PASS (6 tests).

Run: `docker compose exec -T web bin/rails test`
Expected: 203 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/reviews_controller.rb app/controllers/bottles app/views/reviews app/views/bottles/reviews test/integration/reviews_test.rb
git commit -m "Solo reviews: create from bottle page, author-only edit/delete"
```

---

### Task 6: Navigation, profile tastings, docs

**Files:**
- Modify: `app/views/layouts/application.html.erb` (nav, two places)
- Modify: `app/views/profiles/show.html.erb` (tastings section)
- Modify: `app/controllers/profiles_controller.rb` (load reviews)
- Modify: `.claude/skills/wss-orientation/SKILL.md` (mention the bottles section)
- Create: `.claude/skills/wss-reviews/SKILL.md`
- Test: `test/integration/bottles_test.rb` (extend), `test/integration/profile_tastings_test.rb`

**Interfaces:**
- Consumes: everything above.
- Produces: "Bottles" in both navs; profile "Tastings" section; `wss-reviews` skill documenting Phase 1 + pointers to the spec for Phases 2–3.

- [ ] **Step 1: Write the failing tests**

Create `test/integration/profile_tastings_test.rb`:

```ruby
require "test_helper"

class ProfileTastingsTest < ActionDispatch::IntegrationTest
  test "profile shows the member's tastings" do
    sign_in users(:jane)
    get profile_path(users(:john))
    assert_response :success
    assert_match "Eagle Rare 10", response.body
    assert_match "Tastings", response.body
  end

  test "nav links to the bottle library" do
    get root_path
    assert_select "nav a[href=?]", bottles_path
  end
end
```

Note: check `config/routes.rb` for the actual profile route helper before running — if profiles are routed as `profile_path(user)` this stands; if it's `user_profile_path` or similar, adjust the test to the real helper (`docker compose exec -T web bin/rails routes | grep profile`).

- [ ] **Step 2: Run to verify failure**

Run: `docker compose exec -T web bin/rails test test/integration/profile_tastings_test.rb`
Expected: FAIL — no "Tastings" text, no nav link.

- [ ] **Step 3: Nav links**

In `app/views/layouts/application.html.erb` line ~71, after the Decks link:

```erb
          <%= nav_link_to 'Bottles', bottles_path %>
```

And in the mobile menu (line ~111), after the Decks entry:

```erb
            <%= link_to 'Bottles', bottles_path, class: 'block rounded-xl px-4 py-2.5 font-medium text-cream/90 hover:bg-oak' %>
```

- [ ] **Step 4: Profile tastings section**

In `app/controllers/profiles_controller.rb#show`, add alongside the existing assigns:

```ruby
    @tastings = @user.reviews.includes(:bottle).recent_first.limit(20)
```

In `app/views/profiles/show.html.erb`, insert a new section directly before the `<!-- Societies Section -->` comment (line ~56):

```erb
        <!-- Tastings Section -->
        <% if @tastings.any? %>
          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 mb-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Tastings</h2>
            <div class="space-y-3">
              <% @tastings.each do |review| %>
                <div class="flex flex-wrap items-baseline justify-between gap-2 border-b border-gray-100 pb-3 last:border-0 last:pb-0">
                  <%= link_to review.bottle.display_name, bottle_path(review.bottle), class: "font-medium text-gray-900 hover:text-whiskey-700" %>
                  <span class="flex items-center gap-2 text-sm text-gray-500">
                    <%= render "bottles/rating", value: review.rating.to_f %>
                    <%# Event/society provenance badges arrive in Phase 2. %>
                    <%= review.created_at.strftime("%b %Y") %>
                  </span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
```

- [ ] **Step 5: Skill docs**

Create `.claude/skills/wss-reviews/SKILL.md`:

```markdown
---
name: wss-reviews
description: The review system — bottle catalog, solo reviews, aggregation rules, and the Phase 2/3 roadmap (event pours, society boards, deck ties)
---

# WSS Reviews

Spec: `docs/superpowers/specs/2026-07-06-review-system-design.md` (owner-approved;
read it before extending anything here).

## What exists (Phase 1)

- `Bottle` — public catalog, user-creatable. Slug URLs (`/bottles/<slug>`).
  No hard uniqueness; creation shows a near-match warning (`confirmed_duplicate=1`
  bypasses). `Bottle.search` is the one search used by the index, the JSON
  autocomplete (`GET /bottles/search.json?q=`), and the dedup warning.
- `Review` — user + bottle + **nullable event_id** + rating (decimal 2,1;
  half-steps 0.5–5.0, `Review::VALID_RATINGS`) + `notes` (free text — NOT
  `body`) + nose/palate/finish/body_notes. Two unique indexes:
  `(user_id, bottle_id, event_id)` and a partial `(user_id, bottle_id) WHERE
  event_id IS NULL` — one review per tasting context, one solo per bottle.
- Aggregation: `Bottle#average_rating` = mean of each user's LATEST review
  (`DISTINCT ON (user_id) ... ORDER BY user_id, created_at DESC`). Computed,
  never stored.
- Solo review CRUD: create nested under bottle (`Bottles::ReviewsController`),
  edit/delete top-level (`ReviewsController`, scoped `current_user.reviews` →
  404 for non-authors).

## What's next (do NOT improvise — the spec decides)

- Phase 2: `event_bottles` join + `events.pours_hidden_until_complete`
  (reveal at `end_time`), RSVP-gated event reviews, provenance badges with
  privacy veiling (private society → generic badge, no link), society board.
- Phase 3: `events.presentation_id`, deck pour-list ↔ bottle links, search by
  chapter, deck-page badges.

## Traps

- The event review, not the user's solo review, feeds event/society
  aggregates — regardless of creation date (owner decision, in the spec).
- Bottle public score uses latest-per-user ACROSS contexts.
- Never store society/deck on a review; always derive through the event.
```

Add one line to `.claude/skills/wss-orientation/SKILL.md` in its site-map/sections area (locate the list of public sections; add):

```markdown
- Bottles (`/bottles`): public bottle library + reviews — see wss-reviews skill.
```

- [ ] **Step 6: Run the new tests, then the full suite**

Run: `docker compose exec -T web bin/rails test test/integration/profile_tastings_test.rb test/integration/bottles_test.rb`
Expected: PASS.

Run: `docker compose exec -T web bin/rails test`
Expected: 205 runs, 0 failures.

- [ ] **Step 7: Visual pass, then commit**

Open `http://localhost:3000/bottles` in the browser: check the char hero, search dropdown (type "eag"), a bottle page, the review form, and a profile with tastings. Fix any spacing/contrast issues found (design-system tokens only).

```bash
git add app/views/layouts/application.html.erb app/views/profiles/show.html.erb app/controllers/profiles_controller.rb .claude/skills/ test/integration/
git commit -m "Bottle library in nav, tastings on profiles, wss-reviews skill"
git push
```

---

## Self-review notes

- **Spec coverage (Phase 1):** bottles table/model (T1), reviews table + both
  uniqueness indexes + event_id present-but-unused (T2), latest-per-user score
  (T2), bottle pages + review feed (T3), review section with search +
  recent-feed (T3), autocomplete + add-new + near-match (T4), solo review CRUD
  (T5), profile tastings (T6). "Tasted 2×" history is impossible in Phase 1
  (one solo review per bottle) — arrives with event contexts in Phase 2.
- **Deliberately out of scope:** everything in the spec's Phase 2/3 and
  deferred lists.
- **Type consistency check:** `bottle_path(bottle)` everywhere uses slug via
  `to_param`; nested lookup uses `params[:bottle_id]` as slug; JSON search
  returns `{name, display_name, url}` consumed by `bottle_search_controller`.
```
