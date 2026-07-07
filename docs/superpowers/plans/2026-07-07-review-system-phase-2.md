# Review System Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the events-and-societies layer of the review system — ordered pour lists on events (with the secret toggle), RSVP-gated event reviews, provenance event cards on every review surface (veiled for private societies), the night's group ratings on the event page, and the society review board.

**Architecture:** One new table (`event_bottles`) plus one new column (`events.pours_hidden_until_complete`), per the approved spec at `docs/superpowers/specs/2026-07-06-review-system-design.md`. `reviews.event_id` already exists (Phase 1) — Phase 2 is the first UI that sets it. Society and deck are always derived through the event, never stored on a review. All aggregates stay computed queries. Phase 3 (deck ties, `events.presentation_id`) is OUT of scope.

**Owner rendering directives (2026-07-07, binding — they refine the spec):**
1. A review tied to an event renders a compact clickable **event card** under the review body (event title, date, society name, pour count) linking to the event page — **only when the event's society is public**. Private society → the spec's unlinked generic badge "Tasted at a WSS society event". Applies on bottle pages, the /reviews feed, and profile tastings.
2. The event page gains **"The pours"**: each pour row shows the bottle link + the night's group mean (event-tagged reviews only) + an expandable list of the individual reviews (reviewer, rating, notes). RSVP'd ("going") members see a "Review this pour" button; an existing event review becomes an edit link.
3. The society page gains a **review board**: bottles ranked by the society's event-review mean with reviewer counts, rows linking to bottle pages, expandable to member reviews. Visible to whoever can see the society page (existing policy — no new gate).
4. **Secret pours:** `events.pours_hidden_until_complete` boolean; while true and `end_time` is in the future, the pour list is hidden from everyone except the organizer/society admins; auto-reveals after `end_time`; review buttons only post-reveal (even for the organizer).
5. Fixtures AND `db/seeds.rb` include a public society + completed event with 3 pours and 2 reviewers with cross-bottle event reviews, so the event card → event page → society board chain is demoable and testable end-to-end.

**Tech Stack:** Rails 8.0.2, PostgreSQL 15, Hotwire (Turbo/Stimulus), Tailwind v4 tokens, Devise auth, Pundit, Minitest with fixtures.

## Global Constraints

- Run everything through Docker: `docker compose exec -T web bin/rails ...` (tests, migrations, generators). The `jobs` container is irrelevant to this plan.
- **Schema dump is part of the migration commit.** Parallel test workers build their databases from `db/schema.rb`, not by replaying migrations. After `db:migrate`, `git add db/schema.rb` alongside the migration file — a stale dump makes every parallel worker error out while a single-file run still passes (false green).
- The suite is **212 runs, 0 failures, 9 skips** today (verified 2026-07-07). It must stay green after every task; the 9 skips persist and are not ours. Expected counts per task: 221 → 229 → 240 → 245 → 249 → 251.
- **Fixture landmines (do not trip):** existing tests pin `bottles(:eagle_rare)` at exactly one review (john, 4.0), `bottles(:lagavulin)` at zero reviews, and `societies(:whiskey_lovers)` membership counts (society_test creates jane/admin memberships on it and asserts `member_count == 2`). Phase 2 fixtures therefore use **`societies(:single_malt)`** as the demo public society and **three new bottles** for the reviewed pours. Never add reviews to eagle_rare/lagavulin or memberships to whiskey_lovers in fixtures.
- In `event_rsvps` fixtures, **quote the status**: `status: "yes"` — bare `yes` is YAML for boolean `true` and will not match the string enum.
- Fixtures bypass model validations (that's how RSVPs for past events and event reviews exist before the gates land in Task 3). Tests that *create* records must satisfy every validation.
- The canonical event URL is the society-nested one: `society_event_path(event.society, event)`. All new links and redirects use it (`event_path` stays as the legacy alias).
- Aggregation rules (spec table): bottle public score = latest review per user, any context; event group rating = only reviews tagged to that event; society board = only reviews tagged to that society's events. Never store an aggregate.
- Rating display convention (Phase 1): `bottles/_rating` partial for stars + `number_with_precision(value, precision: 2, strip_insignificant_zeros: true)` for the numeral.
- Design system: white/whiskey-50 surfaces, `.eyebrow` for kickers, `font-display` for headings, `rounded-2xl border border-gray-200 bg-white shadow-sm` (or the `rounded-lg` card style already used on event/society pages — match the page you're editing), `bg-whiskey-600 hover:bg-whiskey-700` primary buttons.

---

### Task 1: `event_bottles` + secret toggle — schema, models, reveal logic, demo fixtures

**Files:**
- Create: `db/migrate/<timestamp>_create_event_bottles.rb` (via generator)
- Create: `app/models/event_bottle.rb`
- Modify: `app/models/event.rb` (associations + pours API)
- Modify: `app/controllers/events_controller.rb` (destroy now surfaces restrict errors)
- Create: `test/fixtures/events.yml`, `test/fixtures/event_rsvps.yml`, `test/fixtures/event_bottles.yml`
- Modify: `test/fixtures/bottles.yml`, `test/fixtures/reviews.yml`, `test/fixtures/society_memberships.yml`
- Test: `test/models/event_bottle_test.rb`

**Interfaces:**
- Produces: `EventBottle` (`event`, `bottle`, `position`, `label`, `.ordered`, `#reviews` — that event's reviews of that bottle, `#group_average`), `Event#event_bottles`/`#pour_bottles`/`#reviews`, `Event#pours_revealed?`, `Event#pours_visible_to?(user)`, `Event#managed_by?(user)`; events/pours with reviews refuse `destroy`.
- Produces (fixtures): the demo chain — `events(:spring_blind)` (completed, public `single_malt`, 3 pours, 2 reviewers), `events(:mystery_flight)` (upcoming + secret), `events(:allocated_night)` (private `bourbon_club`, reviewed).

- [ ] **Step 1: Write the failing model test**

Create `test/models/event_bottle_test.rb`:

```ruby
require "test_helper"

class EventBottleTest < ActiveSupport::TestCase
  test "valid pour saves" do
    pour = EventBottle.new(event: events(:mystery_flight), bottle: bottles(:eagle_rare),
                           position: 2, label: "The closer")
    assert pour.valid?, pour.errors.full_messages.to_sentence
  end

  test "a bottle can appear only once per event" do
    dup = EventBottle.new(event: events(:spring_blind), bottle: bottles(:ardbeg_10), position: 9)
    assert_not dup.valid?
    assert_includes dup.errors[:bottle_id], "is already on this event's pour list"
  end

  test "ordered scope sorts by position" do
    assert_equal [bottles(:ardbeg_10), bottles(:glendronach_12), bottles(:four_roses_sb)],
                 events(:spring_blind).event_bottles.ordered.map(&:bottle)
  end

  test "pours are revealed whenever the secret toggle is off" do
    assert events(:spring_blind).pours_revealed? # past event
    upcoming = Event.new(start_time: 1.week.from_now, end_time: 1.week.from_now + 2.hours)
    assert upcoming.pours_revealed?              # upcoming but never secret
  end

  test "secret pours hide until end_time, then auto-reveal" do
    event = events(:mystery_flight)
    assert_not event.pours_revealed?
    event.end_time = 1.minute.ago
    assert event.pours_revealed?
  end

  test "secret pours are visible early only to the people who run the night" do
    event = events(:mystery_flight) # organizer: admin (also the society's admin)
    assert event.pours_visible_to?(users(:admin))    # organizer / society admin / global admin
    assert_not event.pours_visible_to?(users(:seth)) # RSVP'd member — still no peeking
    assert_not event.pours_visible_to?(users(:jane)) # outsider
    assert_not event.pours_visible_to?(nil)          # signed out
  end

  test "group_average counts only the night's event reviews" do
    pour = event_bottles(:spring_blind_pour_one)
    assert_in_delta 4.25, pour.group_average, 0.001 # john 4.5, seth 4.0
    Review.create!(user: users(:jane), bottle: bottles(:ardbeg_10), rating: 1.0) # solo — must not count
    assert_in_delta 4.25, pour.group_average, 0.001
  end

  test "a pour with reviews cannot be removed" do
    pour = event_bottles(:spring_blind_pour_one)
    assert_not pour.destroy
    assert_includes pour.errors[:base], "Can't remove a pour that has reviews"
    assert EventBottle.exists?(pour.id)
  end

  test "an event with reviews cannot be destroyed, an unreviewed one can" do
    assert_not events(:spring_blind).destroy
    assert Event.exists?(events(:spring_blind).id)
    assert events(:mystery_flight).destroy
  end
end
```

- [ ] **Step 2: Write the fixtures**

Create `test/fixtures/events.yml` (relative times keep "past" and "upcoming" true forever):

```yaml
# The demo chain (public society): a completed night with three pours,
# reviewed by john and seth. Society: single_malt — NOT whiskey_lovers,
# whose membership counts are pinned by society_test.
spring_blind:
  society: single_malt
  organizer: admin
  title: The Spring Blind Flight
  description: Three brown-bagged pours, scored before the reveal.
  location: The back room at The Old Pal
  start_time: <%= 3.weeks.ago.to_fs(:db) %>
  end_time: <%= (3.weeks.ago + 2.hours).to_fs(:db) %>

# Upcoming event with the secret toggle on — pours hidden until it ends.
mystery_flight:
  society: single_malt
  organizer: admin
  title: The Mystery Flight
  description: Brown bags only. No hints before the night.
  location: Online
  start_time: <%= 2.weeks.from_now.to_fs(:db) %>
  end_time: <%= (2.weeks.from_now + 2.hours).to_fs(:db) %>
  pours_hidden_until_complete: true

# A private society's completed night — exercises provenance veiling.
allocated_night:
  society: bourbon_club
  organizer: jane
  title: Allocated Bottles Night
  description: Private pours for the club.
  location: Louisville, KY
  start_time: <%= 2.weeks.ago.to_fs(:db) %>
  end_time: <%= (2.weeks.ago + 2.hours).to_fs(:db) %>
```

Create `test/fixtures/event_rsvps.yml` (statuses quoted — bare `yes` is a YAML boolean):

```yaml
john_spring_blind:
  user: john
  event: spring_blind
  status: "yes"

seth_spring_blind:
  user: seth
  event: spring_blind
  status: "yes"

seth_mystery_flight:
  user: seth
  event: mystery_flight
  status: "yes"

jane_allocated_night:
  user: jane
  event: allocated_night
  status: "yes"
```

Create `test/fixtures/event_bottles.yml`:

```yaml
spring_blind_pour_one:
  event: spring_blind
  bottle: ardbeg_10
  position: 1
  label: "Pour #1 — the blind"

spring_blind_pour_two:
  event: spring_blind
  bottle: glendronach_12
  position: 2

spring_blind_pour_three:
  event: spring_blind
  bottle: four_roses_sb
  position: 3

mystery_flight_pour_one:
  event: mystery_flight
  bottle: lagavulin
  position: 1

allocated_night_pour_one:
  event: allocated_night
  bottle: four_roses_sb
  position: 1
```

Append to `test/fixtures/bottles.yml` (three NEW bottles — eagle_rare and lagavulin aggregates are pinned by existing tests; slugs are explicit because fixtures skip callbacks):

```yaml
ardbeg_10:
  name: Ardbeg 10
  distillery: Ardbeg
  region: Islay
  style: Single Malt Scotch
  abv: 46.0
  slug: ardbeg-10-ardbeg

glendronach_12:
  name: GlenDronach 12
  distillery: GlenDronach
  region: Highlands
  style: Single Malt Scotch
  abv: 43.0
  slug: glendronach-12-glendronach

four_roses_sb:
  name: Four Roses Small Batch
  distillery: Four Roses
  region: Kentucky
  style: Bourbon
  abv: 45.0
  slug: four-roses-small-batch-four-roses
```

Append to `test/fixtures/reviews.yml` (event-tagged; fixtures bypass the gates that arrive in Task 3, which is fine — the data is consistent with them):

```yaml
john_spring_ardbeg:
  user: john
  bottle: ardbeg_10
  event: spring_blind
  rating: 4.5
  notes: Smoke first, then pears — the blind fooled nobody.

john_spring_glendronach:
  user: john
  bottle: glendronach_12
  event: spring_blind
  rating: 3.5
  notes: Sherry-sweet, a little thin on the finish.

john_spring_four_roses:
  user: john
  bottle: four_roses_sb
  event: spring_blind
  rating: 4.0
  notes: Rye spice over caramel. Crowd-pleaser.

seth_spring_ardbeg:
  user: seth
  bottle: ardbeg_10
  event: spring_blind
  rating: 4.0
  notes: Campfire in a glass. I said 4, I meant it.

seth_spring_glendronach:
  user: seth
  bottle: glendronach_12
  event: spring_blind
  rating: 3.0
  notes: Fine, but I came for the peat.

jane_allocated_four_roses:
  user: jane
  bottle: four_roses_sb
  event: allocated_night
  rating: 5.0
  notes: Even better from a private stash.
```

Append to `test/fixtures/society_memberships.yml` (john and seth join the demo society — single_malt has no membership assertions in existing tests):

```yaml
single_malt_john:
  user: john
  society: single_malt
  role: member
  status: active

single_malt_seth:
  user: seth
  society: single_malt
  role: member
  status: active
```

The resulting means the later tasks assert: Ardbeg 4.25 (john 4.5, seth 4.0), GlenDronach 3.25 (3.5, 3.0), Four Roses 4.0 at the event (john only; jane's 5.0 belongs to the private club's night).

- [ ] **Step 3: Run the test to verify it fails**

Run: `docker compose exec -T web bin/rails test test/models/event_bottle_test.rb`
Expected: FAIL — fixture loading errors (`events` table has no fixtures file counterpart columns / `uninitialized constant EventBottle`).

- [ ] **Step 4: Generate the migration and write the models**

Run: `docker compose exec -T web bin/rails generate migration CreateEventBottles`

Replace the migration body (`db/migrate/<timestamp>_create_event_bottles.rb`):

```ruby
class CreateEventBottles < ActiveRecord::Migration[8.0]
  def change
    create_table :event_bottles do |t|
      t.references :event, null: false, foreign_key: true
      t.references :bottle, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :label

      t.timestamps
    end

    add_index :event_bottles, [:event_id, :bottle_id], unique: true
    add_index :event_bottles, [:event_id, :position]

    # The secret toggle: while true and the event hasn't ended, the pour list
    # is hidden from everyone except the organizer/society admins.
    add_column :events, :pours_hidden_until_complete, :boolean, null: false, default: false
  end
end
```

Create `app/models/event_bottle.rb`:

```ruby
# A pour on an event's lineup, in order. Managed by the organizer or society
# admins; the reviews that reference it are the society's record of the night.
class EventBottle < ApplicationRecord
  belongs_to :event
  belongs_to :bottle

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :label, length: { maximum: 100 }
  validates :bottle_id, uniqueness: { scope: :event_id, message: "is already on this event's pour list" }

  scope :ordered, -> { order(:position, :id) }

  before_destroy :keep_reviewed_pours

  # The night's reviews of this pour: event-tagged only. Solo reviews of the
  # same bottle never count here (spec's aggregation table).
  def reviews
    event.reviews.where(bottle_id: bottle_id)
  end

  def group_average
    reviews.average(:rating)&.to_f&.round(2)
  end

  private

  def keep_reviewed_pours
    return if reviews.none?

    errors.add(:base, "Can't remove a pour that has reviews")
    throw :abort
  end
end
```

In `app/models/event.rb`, replace the associations block:

```ruby
  # Associations
  has_many :event_rsvps, dependent: :destroy
  has_many :attendees, through: :event_rsvps, source: :user
```

with (order matters — `reviews` is declared before `event_bottles` so the
restrict check aborts a destroy before any pours are touched):

```ruby
  # Associations
  has_many :event_rsvps, dependent: :destroy
  has_many :attendees, through: :event_rsvps, source: :user
  # Reviews are members' words — an event that has them can't be deleted.
  has_many :reviews, dependent: :restrict_with_error
  has_many :event_bottles, dependent: :destroy
  has_many :pour_bottles, through: :event_bottles, source: :bottle
```

Still in `app/models/event.rb`, add directly above the `private` keyword:

```ruby
  # --- Pours (review system Phase 2) ---

  # Secret pours auto-reveal once the night ends; non-secret pours are
  # always revealed (even before the event happens).
  def pours_revealed?
    !pours_hidden_until_complete? || (end_time.present? && end_time <= Time.current)
  end

  def pours_visible_to?(user)
    pours_revealed? || managed_by?(user)
  end

  # Mirrors EventPolicy#update? — the people who run the night.
  def managed_by?(user)
    return false unless user

    user.admin? || organizer_id == user.id || society.has_admin?(user)
  end
```

In `app/controllers/events_controller.rb`, replace the `destroy` action (it currently claims success even when `destroy` returns false):

```ruby
  def destroy
    authorize @event

    if @event.destroy
      redirect_to events_url, notice: 'Event was successfully deleted.'
    else
      redirect_to society_event_path(@event.society, @event), alert: @event.errors.full_messages.to_sentence
    end
  end
```

- [ ] **Step 5: Migrate and run the test**

Run: `docker compose exec -T web bin/rails db:migrate && docker compose exec -T web bin/rails test test/models/event_bottle_test.rb`
Expected: PASS (9 tests).

- [ ] **Step 6: Run the full suite, then commit (schema dump included)**

Run: `docker compose exec -T web bin/rails test`
Expected: 221 runs, 0 failures (9 skips persist).

```bash
git add db/migrate db/schema.rb app/models/event_bottle.rb app/models/event.rb app/controllers/events_controller.rb test/fixtures test/models/event_bottle_test.rb
git commit -m "Event pours: event_bottles + secret toggle, reveal logic, demo fixtures"
```

---

### Task 2: Event page "The pours" — rendering, organizer management, secret veil

**Files:**
- Modify: `config/routes.rb` (event_bottles nested under events)
- Create: `app/controllers/events/event_bottles_controller.rb`
- Modify: `app/controllers/events_controller.rb` (`show` loads pours; `update` permits the toggle)
- Modify: `app/controllers/bottles_controller.rb` (search JSON gains `id`; create honors safe `return_to`)
- Modify: `app/views/bottles/new.html.erb` (carries `return_to` through the form)
- Create: `app/views/events/_pours.html.erb`
- Modify: `app/views/events/show.html.erb` (render the partial)
- Modify: `app/javascript/controllers/bottle_search_controller.js` (fill mode for the pour picker)
- Test: `test/integration/event_pours_test.rb`

**Interfaces:**
- Consumes: `Event#pours_visible_to?`, `EventBottle.ordered`, `EventPolicy#update?`, `search_bottles_path` JSON, `bottle_path` (slug).
- Produces: routes `event_event_bottles_path(event)` / `event_event_bottle_path(event, pour)`; `@pours` + `@pours_visible` on events#show; `bottle-search` fill mode (hidden `bottleId` target + `returnTo` value); `POST /bottles` `return_to` contract (internal paths only); `event[pours_hidden_until_complete]` accepted by events#update.

- [ ] **Step 1: Write the failing integration test**

Create `test/integration/event_pours_test.rb`:

```ruby
require "test_helper"

class EventPoursTest < ActionDispatch::IntegrationTest
  test "event page lists the pours in order with labels and bottle links" do
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_response :success
    assert_match "The pours", response.body
    assert_match "Pour #1 — the blind", response.body
    body = response.body
    assert_operator body.index("Ardbeg 10"), :<, body.index("GlenDronach 12")
    assert_operator body.index("GlenDronach 12"), :<, body.index("Four Roses Small Batch")
    assert_select "a[href=?]", bottle_path(bottles(:ardbeg_10))
  end

  test "secret pours stay hidden from members and strangers until the night ends" do
    sign_in users(:seth) # RSVP'd member — still can't peek
    get society_event_path(societies(:single_malt), events(:mystery_flight))
    assert_response :success
    assert_match "The pours are a secret until the night ends", response.body
    assert_no_match "Lagavulin 16", response.body
  end

  test "the organizer sees secret pours early, flagged as secret" do
    sign_in users(:admin)
    get society_event_path(societies(:single_malt), events(:mystery_flight))
    assert_match "Lagavulin 16", response.body
    assert_match "Secret until the night ends", response.body
  end

  test "organizer adds a pour, appended at the end of the order" do
    sign_in users(:admin)
    event = events(:mystery_flight)
    assert_difference "EventBottle.count", 1 do
      post event_event_bottles_path(event),
           params: { event_bottle: { bottle_id: bottles(:eagle_rare).id, label: "The closer" } }
    end
    pour = event.event_bottles.ordered.last
    assert_equal bottles(:eagle_rare), pour.bottle
    assert_equal 2, pour.position
    assert_redirected_to society_event_path(event.society, event)
  end

  test "non-managers cannot touch the pour list" do
    sign_in users(:seth)
    assert_no_difference "EventBottle.count" do
      post event_event_bottles_path(events(:mystery_flight)),
           params: { event_bottle: { bottle_id: bottles(:eagle_rare).id } }
    end
    assert_response :redirect
  end

  test "organizer removes an unreviewed pour but not a reviewed one" do
    sign_in users(:admin)
    assert_difference "EventBottle.count", -1 do
      delete event_event_bottle_path(events(:mystery_flight), event_bottles(:mystery_flight_pour_one))
    end
    assert_no_difference "EventBottle.count" do
      delete event_event_bottle_path(events(:spring_blind), event_bottles(:spring_blind_pour_one))
    end
    assert_equal "Can't remove a pour that has reviews", flash[:alert]
  end

  test "organizer toggles the secret flag from the event page" do
    sign_in users(:admin)
    event = events(:mystery_flight)
    patch society_event_path(event.society, event),
          params: { event: { pours_hidden_until_complete: "false" } }
    assert_not event.reload.pours_hidden_until_complete?
  end

  test "add-a-bottle honors an internal return_to and ignores external ones" do
    sign_in users(:admin)
    event_page = society_event_path(societies(:single_malt), events(:mystery_flight))

    post bottles_path, params: { bottle: { name: "Springbank 10", distillery: "Springbank" },
                                 return_to: event_page }
    assert_redirected_to event_page

    post bottles_path, params: { bottle: { name: "Springbank 15", distillery: "Springbank" },
                                 return_to: "https://evil.example/phish" }
    assert_redirected_to bottle_path(Bottle.find_by!(name: "Springbank 15"))
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose exec -T web bin/rails test test/integration/event_pours_test.rb`
Expected: FAIL — `NameError: undefined local variable or method 'event_event_bottles_path'` and missing "The pours" markup.

- [ ] **Step 3: Routes and controllers**

In `config/routes.rb`, replace:

```ruby
  resources :events, only: [:show] do
    resources :event_rsvps, only: [:create, :update, :destroy]
  end
```

with:

```ruby
  resources :events, only: [:show] do
    resources :event_rsvps, only: [:create, :update, :destroy]
    # The pour list (organizer/society admins manage it; everyone reads it).
    resources :event_bottles, only: [:create, :destroy], module: :events
  end
```

Create `app/controllers/events/event_bottles_controller.rb`:

```ruby
# Pour-list management: the organizer (or society admins) builds the night's
# lineup. Position is append-only here; reordering is a later nicety.
class Events::EventBottlesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event

  def create
    authorize @event, :update?
    bottle = Bottle.find_by(id: params.dig(:event_bottle, :bottle_id))
    if bottle.nil?
      redirect_to event_page, alert: "Pick a bottle from the search results first."
      return
    end

    pour = @event.event_bottles.new(
      bottle: bottle,
      label: params.dig(:event_bottle, :label),
      position: (@event.event_bottles.maximum(:position) || 0) + 1
    )

    if pour.save
      redirect_to event_page, notice: "#{bottle.name} is on the pour list."
    else
      redirect_to event_page, alert: pour.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @event, :update?
    pour = @event.event_bottles.find(params[:id])

    if pour.destroy
      redirect_to event_page, notice: "Pour removed."
    else
      redirect_to event_page, alert: pour.errors.full_messages.to_sentence
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  # The canonical event URL is the society-nested one.
  def event_page
    society_event_path(@event.society, @event)
  end
end
```

In `app/controllers/events_controller.rb`:

Replace the first two lines of `show`:

```ruby
  def show
    @rsvps = @event.event_rsvps.includes(:user)
```

with:

```ruby
  def show
    @pours = @event.event_bottles.ordered.includes(:bottle)
    @pours_visible = @event.pours_visible_to?(current_user)
    @rsvps = @event.event_rsvps.includes(:user)
```

Replace `event_params`:

```ruby
  def event_params
    params.require(:event).permit(:title, :description, :location, :start_time, :end_time, :society_id)
  end
```

with:

```ruby
  def event_params
    params.require(:event).permit(:title, :description, :location, :start_time, :end_time,
                                  :society_id, :pours_hidden_until_complete)
  end
```

In `app/controllers/bottles_controller.rb`, replace the whole file (adds `id` to the search JSON, and the safe `return_to` round-trip for the pour flow; everything else is unchanged Phase-1 behavior):

```ruby
class BottlesController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create]

  def show
    @bottle = Bottle.find_by!(slug: params[:id])
    @reviews = @bottle.reviews.includes(:user).recent_first
    @my_review = current_user && @bottle.reviews.find_by(user: current_user, event_id: nil)
  end

  def search
    bottles = Bottle.search(params[:q]).order(:name).limit(8)
    render json: bottles.map { |b|
      { id: b.id, name: b.name, display_name: b.display_name,
        url: bottle_path(b), review_url: new_bottle_review_path(b) }
    }
  end

  def new
    @bottle = Bottle.new(name: params[:name])
    @near_matches = []
    @return_to = safe_return_to
  end

  def create
    @bottle = Bottle.new(bottle_params)
    @bottle.created_by = current_user
    @return_to = safe_return_to

    # Soft dedup: same search the autocomplete uses. The user can click an
    # existing bottle instead, or confirm theirs is genuinely different.
    @near_matches =
      if params[:confirmed_duplicate] == "1" || @bottle.name.blank?
        []
      else
        Bottle.search(@bottle.name).limit(5)
      end
    if @near_matches.any?
      render :new, status: :unprocessable_entity
      return
    end

    if @bottle.save
      if @return_to
        redirect_to @return_to, notice: "#{@bottle.name} is on the shelf."
      else
        redirect_to bottle_path(@bottle), notice: "#{@bottle.name} is on the shelf — add your tasting."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def bottle_params
    params.require(:bottle).permit(:name, :distillery, :region, :style, :abv)
  end

  # Only same-app paths may round-trip through the add-a-bottle flow (e.g.
  # back to an event's pour list). "//host" and absolute URLs are dropped.
  def safe_return_to
    path = params[:return_to].to_s
    path if path.start_with?("/") && !path.start_with?("//")
  end
end
```

- [ ] **Step 4: Views and the picker's fill mode**

Create `app/views/events/_pours.html.erb` (reads `@event`, `@pours`, `@pours_visible` from events#show; the review buttons and group scores arrive in Task 3):

```erb
<%# The night's lineup. Visibility: Event#pours_visible_to? decides;
    management: EventPolicy#update? (organizer / society admins). %>
<div class="bg-white shadow-sm rounded-lg overflow-hidden mt-8">
  <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
    <h2 class="text-lg font-semibold text-gray-900">The pours</h2>
    <% if @event.pours_hidden_until_complete? && !@event.pours_revealed? %>
      <span class="rounded-full bg-gray-100 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-gray-500">Secret until the night ends</span>
    <% end %>
  </div>
  <div class="p-6">
    <% if !@pours_visible %>
      <p class="text-gray-500 italic">The pours are a secret until the night ends.</p>
    <% elsif @pours.none? %>
      <p class="text-gray-500 italic">No pours on the list yet.</p>
    <% else %>
      <ol class="space-y-3">
        <% @pours.each do |pour| %>
          <li class="rounded-lg border border-gray-200 p-4">
            <div class="flex flex-wrap items-baseline justify-between gap-2">
              <div class="min-w-0">
                <%= link_to pour.bottle.display_name, bottle_path(pour.bottle), class: "font-display text-lg font-semibold text-gray-900 hover:text-whiskey-700" %>
                <% if pour.label.present? %><p class="mt-0.5 text-sm text-whiskey-700"><%= pour.label %></p><% end %>
              </div>
              <% if user_signed_in? && policy(@event).update? %>
                <%= button_to "Remove", event_event_bottle_path(@event, pour), method: :delete,
                    form: { data: { turbo_confirm: "Remove #{pour.bottle.name} from the pour list?" } },
                    class: "cursor-pointer text-sm font-semibold text-red-600 hover:text-red-700" %>
              <% end %>
            </div>
          </li>
        <% end %>
      </ol>
    <% end %>

    <% if user_signed_in? && policy(@event).update? %>
      <div class="mt-6 border-t border-gray-100 pt-6">
        <%= form_with url: event_event_bottles_path(@event), method: :post, class: "space-y-3" do %>
          <div class="relative" data-controller="bottle-search"
               data-bottle-search-url-value="<%= search_bottles_path %>"
               data-bottle-search-return-to-value="<%= society_event_path(@event.society, @event) %>">
            <input type="search" placeholder="Add a pour — search bottles or distilleries…" autocomplete="off"
                   data-bottle-search-target="input" data-action="input->bottle-search#query"
                   class="w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500">
            <input type="hidden" name="event_bottle[bottle_id]" data-bottle-search-target="bottleId">
            <div data-bottle-search-target="results"
                 class="absolute inset-x-0 top-full z-20 mt-1 hidden overflow-hidden rounded-xl border border-gray-200 bg-white shadow-lg"></div>
          </div>
          <div class="flex items-center gap-3">
            <input type="text" name="event_bottle[label]" placeholder="Label (optional — “the blind”, “pour #3”)"
                   class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-whiskey-500">
            <%= submit_tag "Add pour", class: "cursor-pointer shrink-0 rounded-xl bg-whiskey-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-whiskey-700" %>
          </div>
        <% end %>

        <%= button_to (@event.pours_hidden_until_complete? ? "Reveal the pours now" : "Keep the pours secret until the night ends"),
            society_event_path(@event.society, @event), method: :patch,
            params: { event: { pours_hidden_until_complete: !@event.pours_hidden_until_complete? } },
            class: "mt-4 cursor-pointer text-sm font-semibold text-whiskey-700 hover:text-whiskey-600" %>
      </div>
    <% end %>
  </div>
</div>
```

In `app/views/events/show.html.erb`, render the partial at the bottom of the main column. Replace:

```erb
            <% end %>
          </div>
        </div>
      </div>

      <!-- Sidebar -->
```

with:

```erb
            <% end %>
          </div>
        </div>

        <%= render "pours" %>
      </div>

      <!-- Sidebar -->
```

Replace `app/javascript/controllers/bottle_search_controller.js` in full (adds the fill mode; grouped and picker modes are byte-identical in behavior):

```js
import { Controller } from "@hotwired/stimulus"

// Live search dropdown, three shapes:
//
// - Section mode (grouped: true) — the /reviews page. Fetches the section
//   endpoint, which returns { bottles: [...], societies: [...] }; renders
//   grouped results. Deliberately NO "add a new bottle" row: a society name
//   or a typo must never become a junk catalog entry from here.
// - Picker mode (grouped: false, no bottleId target) — the start-a-review
//   page. Fetches the bottle endpoint (a flat array); rows link to each
//   bottle's REVIEW form (review_url) and an explicit "+ Add …" escape
//   hatch is appended, because the intent to catalog is unambiguous there.
// - Fill mode (grouped: false, WITH a bottleId hidden-input target) — the
//   event pour form. Clicking a row fills the hidden bottle_id instead of
//   navigating; the "+ Add …" escape carries return-to so the organizer
//   lands back on the event after cataloging.
//
// All rendering is textContent/createElement — user input never becomes HTML.
export default class extends Controller {
  static targets = ["input", "results", "bottleId"]
  static values = {
    url: String,
    grouped: { type: Boolean, default: false },
    returnTo: { type: String, default: "" }
  }

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
    const data = await response.json()
    this.groupedValue ? this.renderGroups(data) : this.renderPicker(data, q)
  }

  renderGroups(data) {
    this.resultsTarget.textContent = ""
    const groups = [["Bottles", data.bottles], ["Societies", data.societies]]
    let any = false
    for (const [heading, items] of groups) {
      if (!items?.length) continue
      any = true
      this.resultsTarget.appendChild(this.heading(heading))
      for (const item of items) this.resultsTarget.appendChild(this.link(item.label, item.url))
    }
    if (!any) this.resultsTarget.appendChild(this.empty())
    this.resultsTarget.classList.remove("hidden")
  }

  renderPicker(matches, q) {
    this.resultsTarget.textContent = ""
    for (const match of matches) {
      if (this.hasBottleIdTarget) {
        this.resultsTarget.appendChild(this.fillRow(match))
      } else {
        this.resultsTarget.appendChild(this.link(match.display_name, match.review_url || match.url))
      }
    }
    let addHref = `/bottles/new?name=${encodeURIComponent(q)}`
    if (this.returnToValue) addHref += `&return_to=${encodeURIComponent(this.returnToValue)}`
    const add = this.link(`+ Add “${q}” as a new bottle`, addHref)
    add.classList.add("border-t", "border-gray-100", "font-medium", "text-whiskey-700")
    add.classList.remove("text-gray-800")
    this.resultsTarget.appendChild(add)
    this.resultsTarget.classList.remove("hidden")
  }

  fillRow(match) {
    const el = document.createElement("button")
    el.type = "button"
    el.textContent = match.display_name
    el.className = "block w-full text-left px-4 py-2.5 text-gray-800 hover:bg-whiskey-50"
    el.addEventListener("click", () => {
      this.bottleIdTarget.value = match.id
      this.inputTarget.value = match.display_name
      this.resultsTarget.classList.add("hidden")
    })
    return el
  }

  heading(text) {
    const el = document.createElement("p")
    el.textContent = text
    el.className = "eyebrow border-b border-gray-100 bg-gray-50 px-4 py-1.5 text-gray-400"
    return el
  }

  link(text, href) {
    const el = document.createElement("a")
    el.href = href
    el.textContent = text
    el.className = "block px-4 py-2.5 text-gray-800 hover:bg-whiskey-50"
    return el
  }

  empty() {
    const el = document.createElement("p")
    el.textContent = "Nothing on the record yet."
    el.className = "px-4 py-2.5 text-sm text-gray-400"
    return el
  }

  disconnect() { clearTimeout(this.timer) }
}
```

In `app/views/bottles/new.html.erb`, carry `return_to` through the form. Replace:

```erb
      <% if @near_matches.any? %><input type="hidden" name="confirmed_duplicate" value="1"><% end %>
```

with:

```erb
      <% if @near_matches.any? %><input type="hidden" name="confirmed_duplicate" value="1"><% end %>
      <% if @return_to %><input type="hidden" name="return_to" value="<%= @return_to %>"><% end %>
```

- [ ] **Step 5: Run the test, then the suite**

Run: `docker compose exec -T web bin/rails test test/integration/event_pours_test.rb`
Expected: PASS (8 tests).

Run: `docker compose exec -T web bin/rails test`
Expected: 229 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/events app/controllers/events_controller.rb app/controllers/bottles_controller.rb app/views/events app/views/bottles/new.html.erb app/javascript/controllers/bottle_search_controller.js test/integration/event_pours_test.rb
git commit -m "Pour management: organizer lineup on the event page, secret toggle, picker fill mode"
```

---

### Task 3: Event-tagged reviews — RSVP gate, create flow, the night's group scores

**Files:**
- Modify: `app/models/review.rb` (event-context gates)
- Modify: `config/routes.rb` (event reviews)
- Create: `app/controllers/events/reviews_controller.rb`
- Create: `app/views/events/reviews/new.html.erb`
- Modify: `app/controllers/events_controller.rb` (`show` loads the night's reviews)
- Modify: `app/views/events/_pours.html.erb` (group means, expandable reviews, review buttons)
- Modify: `test/models/review_test.rb` (one existing test must now satisfy the gates)
- Test: `test/models/event_review_test.rb`, `test/integration/event_reviews_test.rb`

**Interfaces:**
- Consumes: `Event#pours_revealed?`, `event.event_bottles` / `event_rsvps`, `reviews/_form` partial (locals `review:`, `url:`), `Review::VALID_RATINGS`, `bottles/_rating`.
- Produces: `Review` create-time gates for event reviews (pour membership, reveal, yes-RSVP); routes `new_event_review_path(event, bottle_id: slug)` / `event_reviews_path(event, bottle_id: slug)`; events#show assigns `@pour_reviews`, `@my_event_reviews`, `@can_review_pours`.

- [ ] **Step 1: Write the failing tests**

Create `test/models/event_review_test.rb`:

```ruby
require "test_helper"

class EventReviewTest < ActiveSupport::TestCase
  test "RSVP'd member reviews a revealed pour" do
    # seth RSVP'd yes and hasn't reviewed the third pour yet
    review = Review.new(user: users(:seth), bottle: bottles(:four_roses_sb),
                        event: events(:spring_blind), rating: 4.5, notes: "Late entry.")
    assert review.valid?, review.errors.full_messages.to_sentence
  end

  test "rejects a bottle that isn't on the pour list" do
    review = Review.new(user: users(:seth), bottle: bottles(:eagle_rare),
                        event: events(:spring_blind), rating: 4.0)
    assert_not review.valid?
    assert_includes review.errors[:base], "That bottle isn't on this event's pour list"
  end

  test "rejects reviewers without a yes RSVP" do
    review = Review.new(user: users(:jane), bottle: bottles(:ardbeg_10),
                        event: events(:spring_blind), rating: 4.0)
    assert_not review.valid?
    assert_includes review.errors[:base], %(Only members who RSVP'd "going" can review this event's pours)
  end

  test "rejects reviews while the pours are still secret" do
    review = Review.new(user: users(:seth), bottle: bottles(:lagavulin),
                        event: events(:mystery_flight), rating: 4.0)
    assert_not review.valid?
    assert_includes review.errors[:base], "The pours haven't been revealed yet"
  end

  test "solo and event reviews of the same bottle coexist; duplicates per context don't" do
    solo = Review.new(user: users(:john), bottle: bottles(:ardbeg_10), rating: 4.0)
    assert solo.valid?, solo.errors.full_messages.to_sentence # event review exists; solo slot is free

    dup = Review.new(user: users(:john), bottle: bottles(:ardbeg_10),
                     event: events(:spring_blind), rating: 4.0)
    assert_not dup.valid?
    assert_includes dup.errors[:bottle_id], "already has your review — edit it instead"
  end
end
```

Create `test/integration/event_reviews_test.rb`:

```ruby
require "test_helper"

class EventReviewsTest < ActionDispatch::IntegrationTest
  test "event page shows the night's group means with expandable individual reviews" do
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_response :success
    assert_match "4.25", response.body                     # Ardbeg: john 4.5, seth 4.0
    assert_match "3.25", response.body                     # GlenDronach: 3.5, 3.0
    assert_match "2 reviews from the night", response.body
    assert_match "Smoke first, then pears", response.body  # john's note in the expandable list
    assert_match "Campfire in a glass", response.body      # seth's cross-bottle score, same page
  end

  test "RSVP'd member sees a review button for pours they haven't reviewed" do
    sign_in users(:seth) # reviewed pours 1–2, not the Four Roses
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_select "a[href=?]",
                  new_event_review_path(events(:spring_blind), bottle_id: bottles(:four_roses_sb).slug),
                  text: "Review this pour"
  end

  test "a member's existing event review turns into an edit link" do
    sign_in users(:seth)
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_select "a[href=?]", edit_review_path(reviews(:seth_spring_ardbeg)), text: "Edit your review"
  end

  test "signed-in visitors without a yes RSVP get no review buttons" do
    sign_in users(:jane)
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_no_match "Review this pour", response.body
    assert_match "4.25", response.body # the record itself stays public
  end

  test "RSVP'd member creates an event-tagged review" do
    sign_in users(:seth)
    assert_difference "Review.count", 1 do
      post event_reviews_path(events(:spring_blind), bottle_id: bottles(:four_roses_sb).slug),
           params: { review: { rating: "4.5", notes: "Round two, still good." } }
    end
    review = Review.find_by!(user: users(:seth), bottle: bottles(:four_roses_sb),
                             event: events(:spring_blind))
    assert_not review.solo?
    assert_redirected_to society_event_path(societies(:single_malt), events(:spring_blind))
  end

  test "create is rejected without a yes RSVP" do
    sign_in users(:jane)
    assert_no_difference "Review.count" do
      post event_reviews_path(events(:spring_blind), bottle_id: bottles(:ardbeg_10).slug),
           params: { review: { rating: "4.0" } }
    end
    assert_response :unprocessable_entity
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `docker compose exec -T web bin/rails test test/models/event_review_test.rb test/integration/event_reviews_test.rb`
Expected: FAIL — the gate tests pass records that should be invalid (`assert_not review.valid?` fails), and `event_reviews_path` is undefined.

- [ ] **Step 3: Model gates + routes + controller + view**

In `app/models/review.rb`, replace the whole file (adds the create-time event gates; everything else unchanged):

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
  validate :event_review_gates, on: :create, if: -> { event.present? }

  scope :recent_first, -> { order(created_at: :desc) }

  # A tasting outside any event.
  def solo? = event_id.nil?

  private

  # Event reviews are the society's record of the night — they only exist for
  # bottles that were actually poured, written by people who actually said
  # they were going, once the pour list is public knowledge. Create-only:
  # edits never re-check (a deleted RSVP must not brick an existing review),
  # and ReviewsController's strong params can't move a review between events.
  def event_review_gates
    unless event.event_bottles.exists?(bottle_id: bottle_id)
      errors.add(:base, "That bottle isn't on this event's pour list")
    end
    unless event.pours_revealed?
      errors.add(:base, "The pours haven't been revealed yet")
    end
    unless event.event_rsvps.exists?(user_id: user_id, status: "yes")
      errors.add(:base, %(Only members who RSVP'd "going" can review this event's pours))
    end
  end
end
```

In `config/routes.rb`, replace:

```ruby
  resources :events, only: [:show] do
    resources :event_rsvps, only: [:create, :update, :destroy]
    # The pour list (organizer/society admins manage it; everyone reads it).
    resources :event_bottles, only: [:create, :destroy], module: :events
  end
```

with:

```ruby
  resources :events, only: [:show] do
    resources :event_rsvps, only: [:create, :update, :destroy]
    # The pour list (organizer/society admins manage it; everyone reads it).
    resources :event_bottles, only: [:create, :destroy], module: :events
    # Event-tagged reviews; the bottle rides along as ?bottle_id=<slug>.
    resources :reviews, only: [:new, :create], module: :events
  end
```

Create `app/controllers/events/reviews_controller.rb`:

```ruby
# Creating a review in the context of an event pour. The event tie is set
# here and only here; the model's gates (pour membership, reveal, RSVP)
# decide whether it saves. Edits go through the shared ReviewsController
# and can never move a review to a different event.
class Events::ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event_and_bottle

  def new
    @review = Review.new(event: @event, bottle: @bottle)
  end

  def create
    @review = Review.new(review_params)
    @review.user = current_user
    @review.event = @event
    @review.bottle = @bottle

    if @review.save
      redirect_to society_event_path(@event.society, @event), notice: "Your pour is on the record."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_event_and_bottle
    @event = Event.find(params[:event_id])
    @bottle = Bottle.find_by!(slug: params[:bottle_id])
  end

  def review_params
    params.require(:review).permit(:rating, :notes, :nose, :palate, :finish, :body_notes)
  end
end
```

Create `app/views/events/reviews/new.html.erb`:

```erb
<% content_for :title, "Review #{@bottle.name} - Whiskey Share Society" %>

<section class="w-full bg-whiskey-50 px-4 py-14">
  <div class="mx-auto max-w-xl">
    <p class="eyebrow text-whiskey-600"><%= @event.title %> · <%= @event.society.name %></p>
    <h1 class="mb-8 mt-1 font-display text-3xl font-semibold text-gray-900">Your pour: <%= @bottle.display_name %></h1>
    <%= render "reviews/form", review: @review, url: event_reviews_path(@event, bottle_id: @bottle.to_param) %>
  </div>
</section>
```

In `app/controllers/events_controller.rb#show`, replace:

```ruby
    @pours = @event.event_bottles.ordered.includes(:bottle)
    @pours_visible = @event.pours_visible_to?(current_user)
```

with:

```ruby
    @pours = @event.event_bottles.ordered.includes(:bottle)
    @pours_visible = @event.pours_visible_to?(current_user)
    @pour_reviews = @event.reviews.includes(:user).recent_first.group_by(&:bottle_id)
    @my_event_reviews = user_signed_in? ? @event.reviews.where(user: current_user).index_by(&:bottle_id) : {}
    @can_review_pours = user_signed_in? && @event.pours_revealed? &&
                        @event.event_rsvps.exists?(user: current_user, status: "yes")
```

- [ ] **Step 4: The pour rows grow scores, reviews, and buttons**

Replace `app/views/events/_pours.html.erb` in full:

```erb
<%# The night's lineup. Visibility: Event#pours_visible_to? decides;
    management: EventPolicy#update? (organizer / society admins).
    Group means use ONLY event-tagged reviews (@pour_reviews) — a solo
    review of the same bottle never counts toward the night. %>
<div class="bg-white shadow-sm rounded-lg overflow-hidden mt-8">
  <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
    <h2 class="text-lg font-semibold text-gray-900">The pours</h2>
    <% if @event.pours_hidden_until_complete? && !@event.pours_revealed? %>
      <span class="rounded-full bg-gray-100 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-gray-500">Secret until the night ends</span>
    <% end %>
  </div>
  <div class="p-6">
    <% if !@pours_visible %>
      <p class="text-gray-500 italic">The pours are a secret until the night ends.</p>
    <% elsif @pours.none? %>
      <p class="text-gray-500 italic">No pours on the list yet.</p>
    <% else %>
      <ol class="space-y-3">
        <% @pours.each do |pour| %>
          <% night_reviews = @pour_reviews[pour.bottle_id] || [] %>
          <li class="rounded-lg border border-gray-200 p-4">
            <div class="flex flex-wrap items-baseline justify-between gap-2">
              <div class="min-w-0">
                <%= link_to pour.bottle.display_name, bottle_path(pour.bottle), class: "font-display text-lg font-semibold text-gray-900 hover:text-whiskey-700" %>
                <% if pour.label.present? %><p class="mt-0.5 text-sm text-whiskey-700"><%= pour.label %></p><% end %>
              </div>
              <div class="flex shrink-0 items-center gap-3">
                <% if night_reviews.any? %>
                  <% mean = (night_reviews.sum(&:rating) / night_reviews.size).to_f.round(2) %>
                  <span class="font-semibold text-gray-900"><%= number_with_precision(mean, precision: 2, strip_insignificant_zeros: true) %></span>
                  <%= render "bottles/rating", value: mean %>
                <% end %>
                <% if @can_review_pours %>
                  <% if (mine = @my_event_reviews[pour.bottle_id]) %>
                    <%= link_to "Edit your review", edit_review_path(mine), class: "text-sm font-semibold text-whiskey-700 hover:text-whiskey-600" %>
                  <% else %>
                    <%= link_to "Review this pour", new_event_review_path(@event, bottle_id: pour.bottle.to_param),
                        class: "rounded-xl bg-whiskey-600 px-3 py-1.5 text-sm font-semibold text-white transition hover:bg-whiskey-700" %>
                  <% end %>
                <% end %>
                <% if user_signed_in? && policy(@event).update? %>
                  <%= button_to "Remove", event_event_bottle_path(@event, pour), method: :delete,
                      form: { data: { turbo_confirm: "Remove #{pour.bottle.name} from the pour list?" } },
                      class: "cursor-pointer text-sm font-semibold text-red-600 hover:text-red-700" %>
                <% end %>
              </div>
            </div>
            <% if night_reviews.any? %>
              <details class="mt-3 border-t border-gray-100 pt-3">
                <summary class="cursor-pointer text-sm font-semibold text-whiskey-700 hover:text-whiskey-600">
                  <%= pluralize(night_reviews.size, "review") %> from the night
                </summary>
                <div class="mt-3 space-y-3">
                  <% night_reviews.each do |review| %>
                    <div class="rounded-lg bg-whiskey-50 p-3">
                      <div class="flex flex-wrap items-baseline justify-between gap-2">
                        <span class="text-sm font-semibold text-gray-900"><%= review.user.first_name %> <%= review.user.last_name %></span>
                        <%= render "bottles/rating", value: review.rating.to_f %>
                      </div>
                      <% if review.notes.present? %><p class="mt-1 text-sm text-gray-600"><%= review.notes %></p><% end %>
                    </div>
                  <% end %>
                </div>
              </details>
            <% end %>
          </li>
        <% end %>
      </ol>
    <% end %>

    <% if user_signed_in? && policy(@event).update? %>
      <div class="mt-6 border-t border-gray-100 pt-6">
        <%= form_with url: event_event_bottles_path(@event), method: :post, class: "space-y-3" do %>
          <div class="relative" data-controller="bottle-search"
               data-bottle-search-url-value="<%= search_bottles_path %>"
               data-bottle-search-return-to-value="<%= society_event_path(@event.society, @event) %>">
            <input type="search" placeholder="Add a pour — search bottles or distilleries…" autocomplete="off"
                   data-bottle-search-target="input" data-action="input->bottle-search#query"
                   class="w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500">
            <input type="hidden" name="event_bottle[bottle_id]" data-bottle-search-target="bottleId">
            <div data-bottle-search-target="results"
                 class="absolute inset-x-0 top-full z-20 mt-1 hidden overflow-hidden rounded-xl border border-gray-200 bg-white shadow-lg"></div>
          </div>
          <div class="flex items-center gap-3">
            <input type="text" name="event_bottle[label]" placeholder="Label (optional — “the blind”, “pour #3”)"
                   class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-whiskey-500">
            <%= submit_tag "Add pour", class: "cursor-pointer shrink-0 rounded-xl bg-whiskey-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-whiskey-700" %>
          </div>
        <% end %>

        <%= button_to (@event.pours_hidden_until_complete? ? "Reveal the pours now" : "Keep the pours secret until the night ends"),
            society_event_path(@event.society, @event), method: :patch,
            params: { event: { pours_hidden_until_complete: !@event.pours_hidden_until_complete? } },
            class: "mt-4 cursor-pointer text-sm font-semibold text-whiskey-700 hover:text-whiskey-600" %>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 5: Fix the one existing test the gates break**

`test/models/review_test.rb` has a test that creates an event review with no pour list and no RSVP ("average_rating uses only a user's newer review when they reviewed the same bottle twice"). It must now satisfy the gates. Replace:

```ruby
    newer_review = Review.create!(user: users(:john), bottle: bottle, event: event, rating: 2.0)
```

with:

```ruby
    event.event_bottles.create!(bottle: bottle, position: 1)
    event.event_rsvps.create!(user: users(:john), status: "yes")
    newer_review = Review.create!(user: users(:john), bottle: bottle, event: event, rating: 2.0)
```

(The event in that test is upcoming and not secret, so `pours_revealed?` is true and the RSVP is creatable.)

- [ ] **Step 6: Run the tests, then the suite**

Run: `docker compose exec -T web bin/rails test test/models/event_review_test.rb test/integration/event_reviews_test.rb test/models/review_test.rb`
Expected: PASS (5 + 6 + 7 tests).

Run: `docker compose exec -T web bin/rails test`
Expected: 240 runs, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add app/models/review.rb config/routes.rb app/controllers/events app/controllers/events_controller.rb app/views/events test/models test/integration/event_reviews_test.rb
git commit -m "Event reviews: RSVP-gated creation, the night's group scores on the event page"
```

---

### Task 4: Provenance event cards on every review surface, veiled for private societies

**Files:**
- Create: `app/views/reviews/_provenance.html.erb`
- Modify: `app/views/bottles/show.html.erb`, `app/views/reviews/index.html.erb`, `app/views/profiles/show.html.erb`
- Modify: `app/controllers/bottles_controller.rb`, `app/controllers/reviews_controller.rb`, `app/controllers/profiles_controller.rb` (eager-load event → society/pours)
- Test: `test/integration/review_provenance_test.rb`

**Interfaces:**
- Consumes: `review.event` (may be nil), `event.society.public?`, `event.event_bottles.size`, `society_event_path`.
- Produces: `reviews/provenance` partial with local `review:` — renders the linked event card (public society), the generic badge (private society), or nothing (solo). The rule is `society.public?`, deliberately NOT a per-viewer policy: private context is veiled for everyone, members and authors included.

- [ ] **Step 1: Write the failing integration test**

Create `test/integration/review_provenance_test.rb`:

```ruby
require "test_helper"

class ReviewProvenanceTest < ActionDispatch::IntegrationTest
  test "bottle page links public-society event reviews to the event" do
    get bottle_path(bottles(:ardbeg_10))
    assert_response :success
    assert_select "a[href=?]", society_event_path(societies(:single_malt), events(:spring_blind)) do
      assert_select "span", text: "The Spring Blind Flight"
      assert_select "span", text: "Single Malt Appreciation"
      assert_select "span", text: "3 pours"
    end
  end

  test "bottle page veils private-society events behind a generic badge" do
    get bottle_path(bottles(:four_roses_sb))
    assert_response :success
    assert_match "Tasted at a WSS society event", response.body # jane's private-club night
    assert_no_match "Allocated Bottles Night", response.body
    assert_no_match society_event_path(societies(:bourbon_club), events(:allocated_night)), response.body
    # …while john's public-society review of the same bottle still links out.
    assert_select "a[href=?]", society_event_path(societies(:single_malt), events(:spring_blind))
  end

  test "solo reviews carry no provenance" do
    get bottle_path(bottles(:eagle_rare))
    assert_response :success
    assert_no_match "Tasted at a WSS society event", response.body
    assert_select "a[href*=?]", "/events/", count: 0
  end

  test "the reviews feed shows event cards under recent tastings" do
    get reviews_path
    assert_select "a[href=?]", society_event_path(societies(:single_malt), events(:spring_blind))
    assert_match "Tasted at a WSS society event", response.body # jane's veiled review, same feed
  end

  test "profile tastings veil private societies but link public events" do
    sign_in users(:john)
    get profile_path(users(:jane)) # jane's only tasting is at the private club
    assert_match "Tasted at a WSS society event", response.body
    assert_no_match "Allocated Bottles Night", response.body

    get profile_path(users(:john))
    assert_select "a[href=?]", society_event_path(societies(:single_malt), events(:spring_blind))
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose exec -T web bin/rails test test/integration/review_provenance_test.rb`
Expected: FAIL — no event cards or badges anywhere yet.

- [ ] **Step 3: The partial**

Create `app/views/reviews/_provenance.html.erb`:

```erb
<%# locals: review
    Where this tasting happened. Public society → a clickable event card
    (title, date, society, pour count); private society → the spec's
    unlinked generic badge; solo → nothing. The rule is society.public?,
    NOT a per-viewer policy — private context is veiled for everyone,
    members and authors included (owner directive, 2026-07-07). %>
<% if review.event %>
  <% event = review.event %>
  <% if event.society.public? %>
    <%= link_to society_event_path(event.society, event),
        class: "mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 rounded-xl border border-whiskey-200 bg-whiskey-50 px-4 py-2.5 text-sm transition hover:border-whiskey-300 hover:bg-whiskey-100" do %>
      <span class="font-semibold text-whiskey-800"><%= event.title %></span>
      <span class="text-gray-500"><%= event.start_time.strftime("%B %-d, %Y") %></span>
      <span class="text-gray-500"><%= event.society.name %></span>
      <span class="text-gray-500"><%= pluralize(event.event_bottles.size, "pour") %></span>
    <% end %>
  <% else %>
    <span class="mt-3 inline-flex rounded-full bg-gray-100 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-gray-500">Tasted at a WSS society event</span>
  <% end %>
<% end %>
```

- [ ] **Step 4: Wire the three surfaces (with eager loading)**

**Bottle page.** In `app/views/bottles/show.html.erb`, replace:

```erb
          <%# Provenance badges (event/society/deck) arrive in Phase 2 — solo only here. %>
```

with:

```erb
          <%= render "reviews/provenance", review: review %>
```

In `app/controllers/bottles_controller.rb#show`, replace:

```ruby
    @reviews = @bottle.reviews.includes(:user).recent_first
```

with:

```ruby
    @reviews = @bottle.reviews.includes(:user, event: [:society, :event_bottles]).recent_first
```

**Reviews feed.** In `app/views/reviews/index.html.erb` (the "Latest tastings" block), replace:

```erb
              <% if review.notes.present? %><p class="mt-2 text-gray-600"><%= truncate(review.notes, length: 200) %></p><% end %>
              <p class="mt-2 text-sm text-gray-400"><%= review.user.first_name %> · <%= time_ago_in_words(review.created_at) %> ago</p>
```

with:

```erb
              <% if review.notes.present? %><p class="mt-2 text-gray-600"><%= truncate(review.notes, length: 200) %></p><% end %>
              <%= render "reviews/provenance", review: review %>
              <p class="mt-2 text-sm text-gray-400"><%= review.user.first_name %> · <%= time_ago_in_words(review.created_at) %> ago</p>
```

In `app/controllers/reviews_controller.rb#index`, replace:

```ruby
    @recent_reviews = Review.includes(:user, :bottle).recent_first.limit(10)
```

with:

```ruby
    @recent_reviews = Review.includes(:user, :bottle, event: [:society, :event_bottles]).recent_first.limit(10)
```

**Profile tastings.** In `app/views/profiles/show.html.erb`, replace the whole Tastings section:

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

with:

```erb
        <!-- Tastings Section -->
        <% if @tastings.any? %>
          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 mb-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Tastings</h2>
            <div class="space-y-3">
              <% @tastings.each do |review| %>
                <div class="border-b border-gray-100 pb-3 last:border-0 last:pb-0">
                  <div class="flex flex-wrap items-baseline justify-between gap-2">
                    <%= link_to review.bottle.display_name, bottle_path(review.bottle), class: "font-medium text-gray-900 hover:text-whiskey-700" %>
                    <span class="flex items-center gap-2 text-sm text-gray-500">
                      <%= render "bottles/rating", value: review.rating.to_f %>
                      <%= review.created_at.strftime("%b %Y") %>
                    </span>
                  </div>
                  <%= render "reviews/provenance", review: review %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
```

In `app/controllers/profiles_controller.rb#show`, replace:

```ruby
    @tastings = @user.reviews.includes(:bottle).recent_first.limit(20)
```

with:

```ruby
    @tastings = @user.reviews.includes(:bottle, event: [:society, :event_bottles]).recent_first.limit(20)
```

- [ ] **Step 5: Run the test, then the suite**

Run: `docker compose exec -T web bin/rails test test/integration/review_provenance_test.rb`
Expected: PASS (5 tests).

Run: `docker compose exec -T web bin/rails test`
Expected: 245 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/views/reviews app/views/bottles/show.html.erb app/views/profiles/show.html.erb app/controllers/bottles_controller.rb app/controllers/reviews_controller.rb app/controllers/profiles_controller.rb test/integration/review_provenance_test.rb
git commit -m "Provenance: event cards on review surfaces, veiled for private societies"
```

---

### Task 5: Society review board

**Files:**
- Modify: `app/controllers/societies_controller.rb` (`show` builds the board)
- Modify: `app/views/societies/show.html.erb` (board card in the main column)
- Test: `test/integration/society_board_test.rb`

**Interfaces:**
- Consumes: `authorize @society` (existing — the board inherits the page's visibility, no new gate), `bottles/_rating`, `bottle_path`.
- Produces: `@review_board` (Bottle rows with `board_avg`, `board_reviewers` — event-tagged reviews of THIS society's events only) and `@board_reviews` (those reviews grouped by bottle_id, for the drill-down).

- [ ] **Step 1: Write the failing integration test**

Create `test/integration/society_board_test.rb`:

```ruby
require "test_helper"

class SocietyBoardTest < ActionDispatch::IntegrationTest
  test "society page ranks bottles by the society's event-review mean" do
    get society_path(societies(:single_malt))
    assert_response :success
    assert_match "The review board", response.body
    body = response.body
    # Ardbeg 4.25 (2 reviewers) > Four Roses 4.0 (1) > GlenDronach 3.25 (2)
    assert_operator body.index("Ardbeg 10"), :<, body.index("Four Roses Small Batch")
    assert_operator body.index("Four Roses Small Batch"), :<, body.index("GlenDronach 12")
    assert_match "2 reviewers", body
    assert_select "a[href=?]", bottle_path(bottles(:ardbeg_10))
  end

  test "board rows expand to member reviews" do
    get society_path(societies(:single_malt))
    assert_match "Member reviews", response.body
    assert_match "Campfire in a glass", response.body
  end

  test "solo reviews and other societies' nights never reach the board" do
    get society_path(societies(:single_malt))
    assert_no_match "Eagle Rare 10", response.body                     # solo-only bottle
    assert_no_match "Even better from a private stash", response.body  # the private club's review

    get society_path(societies(:whiskey_lovers))
    assert_no_match "The review board", response.body # no event reviews at all
  end

  test "the private club's board stays behind the existing society policy" do
    get society_path(societies(:bourbon_club))
    assert_redirected_to societies_url # outsiders never see the page at all

    sign_in users(:jane)
    get society_path(societies(:bourbon_club))
    assert_response :success
    assert_match "The review board", response.body
    assert_match "Even better from a private stash", response.body
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose exec -T web bin/rails test test/integration/society_board_test.rb`
Expected: FAIL — no "The review board" markup.

- [ ] **Step 3: Controller query**

In `app/controllers/societies_controller.rb#show`, replace:

```ruby
  def show
    authorize @society
    @upcoming_events = @society.upcoming_events.limit(5)
    @past_events = @society.past_events.limit(5)
    @recent_members = @society.members.limit(10)
  end
```

with:

```ruby
  def show
    authorize @society
    @upcoming_events = @society.upcoming_events.limit(5)
    @past_events = @society.past_events.limit(5)
    @recent_members = @society.members.limit(10)

    # The review board: bottles ranked by THIS society's event reviews only
    # (spec's aggregation table — solo reviews never count here). Inherits
    # the page's visibility from `authorize @society` above; no new gate.
    @review_board = Bottle
      .joins(reviews: :event)
      .where(events: { society_id: @society.id })
      .select("bottles.*, AVG(reviews.rating) AS board_avg, COUNT(DISTINCT reviews.user_id) AS board_reviewers")
      .group("bottles.id")
      .order(Arel.sql("board_avg DESC, bottles.name ASC"))
    @board_reviews = Review.joins(:event).where(events: { society_id: @society.id })
                           .includes(:user).recent_first.group_by(&:bottle_id)
  end
```

- [ ] **Step 4: The board card**

In `app/views/societies/show.html.erb`, the main column ends its Past Events block right before the About card. Replace:

```erb
        <!-- Recent Activity or Society Description -->
```

with:

```erb
        <!-- The review board -->
        <% if @review_board.any? %>
          <div class="bg-white shadow-sm rounded-lg overflow-hidden">
            <div class="px-6 py-4 border-b border-gray-200">
              <h2 class="text-lg font-semibold text-gray-900">The review board</h2>
              <p class="mt-1 text-sm text-gray-500">Every bottle poured at our events, ranked by the room.</p>
            </div>
            <div class="divide-y divide-gray-100">
              <% @review_board.each do |bottle| %>
                <div class="px-6 py-4">
                  <div class="flex flex-wrap items-baseline justify-between gap-2">
                    <%= link_to bottle.display_name, bottle_path(bottle), class: "font-display text-lg font-semibold text-gray-900 hover:text-whiskey-700" %>
                    <span class="flex items-center gap-2 whitespace-nowrap text-sm text-gray-500">
                      <span class="font-semibold text-gray-900"><%= number_with_precision(bottle.board_avg, precision: 2, strip_insignificant_zeros: true) %></span>
                      <%= render "bottles/rating", value: bottle.board_avg.to_f %>
                      <%= pluralize(bottle.board_reviewers, "reviewer") %>
                    </span>
                  </div>
                  <% member_reviews = @board_reviews[bottle.id] || [] %>
                  <% if member_reviews.any? %>
                    <details class="mt-2">
                      <summary class="cursor-pointer text-sm font-semibold text-whiskey-700 hover:text-whiskey-600">Member reviews</summary>
                      <div class="mt-2 space-y-2">
                        <% member_reviews.each do |review| %>
                          <div class="rounded-lg bg-whiskey-50 p-3">
                            <div class="flex flex-wrap items-baseline justify-between gap-2">
                              <span class="text-sm font-semibold text-gray-900"><%= review.user.first_name %> <%= review.user.last_name %></span>
                              <%= render "bottles/rating", value: review.rating.to_f %>
                            </div>
                            <% if review.notes.present? %><p class="mt-1 text-sm text-gray-600"><%= review.notes %></p><% end %>
                          </div>
                        <% end %>
                      </div>
                    </details>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Recent Activity or Society Description -->
```

- [ ] **Step 5: Run the test, then the suite**

Run: `docker compose exec -T web bin/rails test test/integration/society_board_test.rb`
Expected: PASS (4 tests).

Run: `docker compose exec -T web bin/rails test`
Expected: 249 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/societies_controller.rb app/views/societies/show.html.erb test/integration/society_board_test.rb
git commit -m "Society review board: event-review rankings with member drill-down"
```

---

### Task 6: Seeds demo chain, end-to-end test, docs, final polish

**Files:**
- Modify: `db/seeds.rb` (the demoable chain in development)
- Create: `test/integration/review_demo_chain_test.rb`
- Modify: `.claude/skills/wss-reviews/SKILL.md` (Phase 2 is now "what exists")
- Modify: `.claude/skills/wss-orientation/SKILL.md` (one new bullet)

**Interfaces:**
- Consumes: everything above.
- Produces: `bin/rails db:seed` yields a browsable card → event → board chain in dev; the fixture-backed chain is pinned by an end-to-end test; the skill docs stop pointing at Phase 2 as future work.

- [ ] **Step 1: Write the failing end-to-end test**

Create `test/integration/review_demo_chain_test.rb`:

```ruby
require "test_helper"

# The demo chain the fixtures guarantee end-to-end: a review's event card
# leads to the event page (everything rated that night, including the
# arriving reviewer's other scores), and the same night ranks the society's
# review board. If this breaks, the Phase-2 story is broken.
class ReviewDemoChainTest < ActionDispatch::IntegrationTest
  test "event card leads to an event page showing everything rated that night" do
    get bottle_path(bottles(:ardbeg_10))
    event_url = society_event_path(societies(:single_malt), events(:spring_blind))
    assert_select "a[href=?]", event_url

    get event_url
    assert_response :success
    [bottles(:ardbeg_10), bottles(:glendronach_12), bottles(:four_roses_sb)].each do |bottle|
      assert_select "a[href=?]", bottle_path(bottle)
    end
    assert_match "Campfire in a glass", response.body # seth's other score, one click from his review
  end

  test "the same night ranks the society's review board" do
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_select "a[href=?]", society_path(societies(:single_malt))

    get society_path(societies(:single_malt))
    assert_match "The review board", response.body
    assert_match "4.25", response.body
  end
end
```

Run: `docker compose exec -T web bin/rails test test/integration/review_demo_chain_test.rb`
Expected: PASS immediately (Tasks 1–5 built it — this test exists to pin the chain). If it fails, something above regressed; fix before continuing.

- [ ] **Step 2: Seeds**

In `db/seeds.rb`, directly after the events block (the `event_seeds.each do |attrs| ... end` loop, still inside `if Rails.env.development?`), append:

```ruby
  # --- Review-system demo chain (Phase 2) -----------------------------------
  # A completed public-society night with three pours and two reviewers, so
  # bottle pages, /reviews, the event page, and the society review board all
  # have provenance to show: review card → event page → society board.
  athens = societies[0] # Athens Whiskey Society (public)

  pour_specs = [
    { name: "Ardbeg 10", distillery: "Ardbeg", region: "Islay",
      style: "Single Malt Scotch", abv: 46.0, label: "Pour #1 — the blind" },
    { name: "GlenDronach 12", distillery: "GlenDronach", region: "Highlands",
      style: "Single Malt Scotch", abv: 43.0, label: nil },
    { name: "Four Roses Small Batch", distillery: "Four Roses", region: "Kentucky",
      style: "Bourbon", abv: 45.0, label: nil }
  ]

  night = athens.events.find_or_create_by!(title: "March: The Blind Islay Flight") do |e|
    e.description = "Three brown-bagged pours, scored before the reveal."
    e.location    = "Athens, GA"
    e.organizer   = athens.creator
    e.start_time  = 3.weeks.ago
    e.end_time    = 3.weeks.ago + 2.hours
  end

  pours = pour_specs.each_with_index.map do |spec, i|
    bottle = Bottle.find_or_create_by!(name: spec[:name], distillery: spec[:distillery]) do |b|
      b.region = spec[:region]
      b.style  = spec[:style]
      b.abv    = spec[:abv]
    end
    night.event_bottles.find_or_create_by!(bottle: bottle) do |eb|
      eb.position = i + 1
      eb.label    = spec[:label]
    end
    bottle
  end

  # Dev shortcut, mirroring the presentation-seed publish bypass: the "no
  # RSVP after the event" rule doesn't apply to seeded history, so skip
  # validations for these two RSVPs only.
  [admin_user, test_user].each do |member|
    rsvp = night.event_rsvps.find_or_initialize_by(user: member)
    rsvp.status = "yes"
    rsvp.save!(validate: false)
  end

  # Event reviews pass every real gate (pours listed + revealed, RSVPs yes).
  scores = {
    admin_user => { pours[0] => [4.5, "Smoke first, then pears — the blind fooled nobody."],
                    pours[1] => [3.5, "Sherry-sweet, a little thin on the finish."],
                    pours[2] => [4.0, "Rye spice over caramel. Crowd-pleaser."] },
    test_user  => { pours[0] => [4.0, "Campfire in a glass."],
                    pours[1] => [3.0, "Fine, but I came for the peat."] }
  }
  scores.each do |member, ratings|
    ratings.each do |bottle, (rating, notes)|
      Review.find_or_create_by!(user: member, bottle: bottle, event: night) do |r|
        r.rating = rating
        r.notes  = notes
      end
    end
  end
  puts "Review demo chain: #{night.title} — #{night.event_bottles.count} pours, #{night.reviews.count} event reviews"
```

Run: `docker compose exec -T web bin/rails db:seed`
Expected: ends with `Review demo chain: March: The Blind Islay Flight — 3 pours, 5 event reviews`. Run it twice — the second run must not raise (idempotent).

- [ ] **Step 3: Skill docs**

Replace `.claude/skills/wss-reviews/SKILL.md` in full:

```markdown
---
name: wss-reviews
description: The review system — bottle catalog, solo + event reviews, event pours with the secret toggle, provenance veiling, society review boards, and the Phase 3 roadmap (deck ties)
---

# WSS Reviews

Spec: `docs/superpowers/specs/2026-07-06-review-system-design.md` (owner-approved;
read it before extending anything here). Plans:
`docs/superpowers/plans/2026-07-06-review-system-phase-1.md`,
`docs/superpowers/plans/2026-07-07-review-system-phase-2.md`.

## What exists (Phase 1 — the public bottle database)

- **Public section is `/reviews`** (`ReviewsController#index`) — the bottle
  library: search bar + result rows (name, style/region, distillery, average
  rating, reviewer count) plus a "Latest tastings" feed of recent reviews.
- **Bottle detail/new/create stay under `/bottles`**: `bottle_path`
  (`/bottles/<slug>`), slug URLs via `to_param`. No hard uniqueness; creation
  shows a near-match warning (`confirmed_duplicate=1` bypasses).
- **Autocomplete**: `GET /bottles/search?q=` returns JSON
  `[{ id, name, display_name, url, review_url }]`, consumed by
  `bottle_search_controller.js`.
- `Review` — user + bottle + **nullable event_id** + rating (decimal 2,1;
  half-steps 0.5–5.0, `Review::VALID_RATINGS`) + `notes` (free text — NOT
  `body`) + nose/palate/finish/body_notes. Two unique indexes:
  `(user_id, bottle_id, event_id)` and a partial `(user_id, bottle_id) WHERE
  event_id IS NULL` — one review per tasting context, one solo per bottle.
- Aggregation: `Bottle#average_rating` = mean of each user's LATEST review
  across contexts. `Bottle.with_score` computes the same thing in SQL for
  whole pages (`avg_rating`/`reviewers` columns; `Bottle::SORTS`).
- `bottles/_rating` partial: displayed stars snap to the nearest 0.5, but the
  `aria-label` carries the true value; numerals render via
  `number_with_precision(precision: 2, strip_insignificant_zeros: true)`.
- Solo review CRUD: create nested under bottle (`Bottles::ReviewsController`),
  edit/delete top-level (`ReviewsController`, scoped `current_user.reviews` →
  404 for non-authors).

## What exists (Phase 2 — events and societies)

- `event_bottles` (`event`, `bottle`, `position`, `label`; unique per
  event+bottle; `EventBottle.ordered`). Managed on the EVENT PAGE by
  `policy(event).update?` holders (`app/views/events/_pours.html.erb`) —
  the events/edit view is an unstyled stub, so management lives on show.
- **Secret toggle**: `events.pours_hidden_until_complete`.
  `Event#pours_revealed?` (off-toggle OR past end_time),
  `Event#pours_visible_to?(user)` (revealed OR `Event#managed_by?` —
  organizer / society admin / global admin). Review buttons AND the review
  gate use `pours_revealed?` — even the organizer can't review early.
- **Event reviews**: created only via
  `POST /events/:event_id/reviews?bottle_id=<slug>`
  (`Events::ReviewsController`). Create-time model gates: bottle on the pour
  list, pours revealed, reviewer has a `status: "yes"` RSVP. Gates run
  `on: :create` only — edits (shared `ReviewsController`) never re-check and
  can never move a review between events (strong params omit event_id).
- **Event page "The pours"**: ordered rows, per-pour group mean (event-tagged
  reviews ONLY — computed in-view from `@pour_reviews`), expandable
  individual reviews, Review-this-pour / Edit-your-review buttons.
- **Provenance** (`app/views/reviews/_provenance.html.erb`, rendered on
  bottle pages, /reviews feed, profile tastings): public society → clickable
  event card (title, date, society, pour count → `society_event_path`);
  private society → unlinked badge "Tasted at a WSS society event"; solo →
  nothing. The rule is `society.public?` — NOT per-viewer; members and
  authors see the veil too.
- **Society review board** (`SocietiesController#show` → `@review_board`):
  bottles ranked by AVG of reviews joined through the society's events, with
  `COUNT(DISTINCT user_id)` reviewer counts and a member-review drill-down.
  Inherits the society page's Pundit gate; no separate policy.
- Events/pours with reviews refuse destroy (`dependent: :restrict_with_error`
  on `Event#reviews`; `before_destroy` guard on `EventBottle`) — the night is
  on the record.

## What's next (do NOT improvise — the spec decides)

- Phase 3: `events.presentation_id`, deck pour-list ↔ bottle links, deck
  names on provenance cards, "search by chapter," review badges on deck pages.

## Traps

- The event review, not the user's solo review, feeds event/society
  aggregates — regardless of creation date (owner decision, in the spec).
- Bottle public score uses latest-per-user ACROSS contexts.
- Never store society/deck on a review; always derive through the event.
- `BottlesController#create` skips the near-match check for blank names so
  validation renders (see `@bottle.name.blank?` short-circuit) — don't
  "fix" this into always running the search.
- Adding a migration requires committing the regenerated `db/schema.rb` —
  parallel test workers build their databases from the schema dump, not by
  replaying migrations. A missing/stale dump makes every parallel test
  worker error out while a single-file run still passes (false green).
- Fixture landmines: eagle_rare must keep exactly one review (john, 4.0),
  lagavulin zero; whiskey_lovers must gain no membership fixtures
  (society_test pins its counts). The Phase-2 demo chain therefore lives on
  `societies(:single_malt)` with three dedicated bottles.
- `event_rsvps` fixtures must QUOTE `status: "yes"` — bare `yes` is YAML
  boolean true.
- `EventRsvp` validates "no RSVP after the event" — seeds for completed
  demo events bypass it with `save!(validate: false)` (documented dev
  shortcut, same spirit as the presentation publish bypass).
- The canonical event URL is `society_event_path(event.society, event)`;
  bare `event_path` is a legacy alias.

## Section search scope

/reviews search covers bottles AND societies: `policy_scope(Society).search(q)`
renders a "Societies" result group (private societies stay invisible to
non-members — the policy scope, not the view, enforces it; same scope backs
the grouped JSON at GET /reviews/search).

Three dropdown modes in bottle_search_controller.js:
- grouped (the /reviews page): entity-grouped Bottles/Societies results, NO
  add-a-bottle row — a society name or typo must never become a catalog entry.
- picker (GET /reviews/start, authed "Add a review" flow): bottle rows link
  straight to that bottle's review form (review_url in /bottles/search JSON);
  the "+ Add … as a new bottle" escape lives HERE, where intent is explicit.
- fill (the event pour form — a hidden `bottleId` target is present): rows
  fill the hidden bottle_id instead of navigating; the add-new escape carries
  `return_to` (internal paths only) so organizers land back on the event.
```

In `.claude/skills/wss-orientation/SKILL.md`, find the site-map bullet that starts with `- Reviews (/reviews):` and add this bullet directly below it (same indentation):

```markdown
  - Event pours & society boards: events list ordered pours (optional secret-until-end toggle), RSVP'd members review them, societies rank the results — see wss-reviews skill.
```

- [ ] **Step 4: Run the full suite**

Run: `docker compose exec -T web bin/rails test`
Expected: 251 runs, 0 failures (9 skips persist).

- [ ] **Step 5: Visual pass, then commit and push**

Open in the browser (dev server is the running `web` container, http://localhost:3000):
- `/societies` → Athens Whiskey Society → "March: The Blind Islay Flight": pours in order, group means, expandable reviews. As `admin@whiskeysharesociety.com` / `password`: the add-pour picker, Remove buttons, and the secret-toggle link.
- An upcoming event as organizer: flip "Keep the pours secret…", confirm the badge and hidden state signed out.
- `/reviews`: event cards in the Latest tastings feed. A demo bottle page: card links to the event. The Athens society page: the review board ranks the three pours.
- Fix any spacing/contrast issues found (design-system tokens only).

```bash
git add db/seeds.rb test/integration/review_demo_chain_test.rb .claude/skills/wss-reviews/SKILL.md .claude/skills/wss-orientation/SKILL.md
git commit -m "Review demo chain: seeds, end-to-end test, wss-reviews skill covers Phase 2"
git push
```

---

## Self-review notes

- **Spec coverage (Phase 2):** `event_bottles` + unique index + ordered
  positions + labels (T1), secret toggle with auto-reveal at end_time and
  organizer/society-admin early visibility (T1/T2), organizer pour management
  with the same autocomplete + add-new flow as reviews (T2), RSVP-gated
  event-review creation with pour-membership and reveal gates (T3), event
  group ratings from event-tagged reviews only (T3), provenance with privacy
  veiling on bottle pages, /reviews feed, and profile tastings (T4), society
  review board with reviewer counts and member drill-down behind the existing
  society policy (T5), fixtures AND seeds demo chain, end-to-end pinned (T1/T6).
  All four owner directives are implemented as written; directive 5's chain is
  both fixture-backed (tests) and seed-backed (browser demo).
- **Deliberately out of scope:** Phase 3 (deck ties, `events.presentation_id`),
  pour reordering UI (append-only positions), bottle merge/moderation/photos
  (spec's deferred list), tightening `EventPolicy#show?` (event pages are
  public today — veiling protects the review surfaces; the pre-existing
  event-page exposure of private-society names is unchanged and out of scope).
- **Ambiguities resolved (recorded here because the spec is silent):**
  events/edit is an unstyled stub, so pour management lives on the event
  show page for `policy(event).update?` holders; events/pours with reviews
  refuse destroy (`restrict_with_error` + guard — the night is on the
  record), and `EventsController#destroy` now surfaces that instead of
  claiming success; non-secret pour lists are visible (and reviewable by
  RSVP'd members) even before the event starts — the spec's three gates are
  exactly pour-membership + revealed + yes-RSVP; the veil is `society.public?`
  for every viewer, including members and the review's author; the demo
  fixtures live on `single_malt` and three new bottles because existing tests
  pin eagle_rare/lagavulin aggregates and whiskey_lovers membership counts.
- **Type/interface consistency check:** bottle URLs use slugs everywhere
  (`to_param`; `Events::ReviewsController` looks up `params[:bottle_id]` as a
  slug, matching `Bottles::ReviewsController`); `event_bottle[bottle_id]` in
  the pour form is a numeric DB id filled by the picker (and the search JSON
  now carries `id` for it); group means and board averages render through the
  same `bottles/_rating` + `number_with_precision` pair as Phase 1; RSVP gate
  checks the string enum `status: "yes"` (`EventRsvp` enum, quoted in YAML);
  `@pour_reviews`/`@board_reviews` are grouped once per page — no per-row
  queries; all new redirects target `society_event_path`.
- **Placeholder scan:** every step carries complete, runnable code — no
  TODOs, no `...`, no "adjust as needed". The two full-file replacements
  (review.rb, bottle_search_controller.js) restate unchanged code verbatim
  to keep edits unambiguous. Suite counts: 212 → 221 → 229 → 240 → 245 →
  249 → 251, verified against a real 212-run baseline on 2026-07-07.
