# Bottle Data Corrections — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans to run this task-by-task. `- [ ]` = tracked step.

**Goal:** the corrections half of the FINAL addendum (2026-07-07, owner-approved)
in `docs/superpowers/specs/2026-07-06-review-system-design.md`
("bottle image at creation; data corrections"). The image-at-creation half
already shipped (`Bottle#label_image`, upload on the add-a-bottle form —
see `docs/superpowers/plans/2026-07-07-review-images.md` Task 2 Step 3).
This plan covers only:

1. **Admin edit.** Full edit of bottle fields from the existing
   `Admin::BottlesController` surface (today: index/show/pin_image/unpin_image
   only) — add `edit`/`update`.
2. **Ghost edits.** Signed-in users "suggest a correction" on the public
   bottle page. Whitelisted fields: name, distillery, region, style, abv.
   Pre-filled form; each CHANGED field becomes a per-field proposal row in a
   new `bottle_edits` table (bottle, user, field, proposed_value; one LIVE
   proposal per user/field/bottle). When N DISTINCT users have live proposals
   with the IDENTICAL field+value, it auto-applies and clears ALL proposals
   for that field (competing values included). N is Rails config
   (`config.x.bottle_edits.auto_apply_threshold`), default 3. Admins see
   pending proposals grouped by bottle/field/value on the admin bottle page
   and can apply or reject a value instantly. Applied edits are logged (who
   proposed, when applied).

**Stack:** Rails 8.0.2, Postgres 15, Hotwire, Tailwind v4, Devise, Pundit
(not used for bottles — auth here is `authenticate_admin!` / plain
`current_user` checks, matching the existing `Admin::BottlesController` and
`BottlesController`), Minitest+fixtures, Active Storage (Disk in dev, R2
planned for prod).

## Architecture

- **No enrichment columns exist yet.** `db/schema.rb`'s `bottles` table has
  only `name, distillery, region, style, abv, slug, created_by_id` — the
  `description`/`age_statement`/`cask_type`/`cost_tier` columns mentioned in
  the EARLIER addendum ("bottle images & detail enrichment") were never
  built. Per the FINAL addendum's own instruction ("the enrichment columns
  IF PRESENT"), this plan edits/proposes corrections on exactly the five
  columns that exist: `name, distillery, region, style, abv`. Enrichment
  columns are out of scope — a future plan adds them and extends both the
  admin form and `BottleEdit::FIELDS` together.
- **`bottle_edits` is a proposal ledger, not a diff table.** One row per
  (bottle, user, field) while `status: "pending"`; `status` transitions to
  `"applied"` or `"rejected"` and the row is kept (audit trail — "who
  proposed, when applied"). `applied_at` + `applied_by_id` (nullable —
  nil for auto-apply, the admin's id for a manual apply) carry the "when
  applied" half; `user_id` on every row already carries "who proposed."
- **Auto-apply is a service, not a callback.** `BottleEdits::AutoApply`
  runs after every proposal create: count DISTINCT `user_id` among pending
  rows sharing this bottle+field+proposed_value; if `>= threshold`, write
  the field onto the bottle, mark those matching rows `applied`
  (`applied_by_id: nil`), and mark every OTHER pending row for that
  bottle+field (competing values) `rejected`. Admin apply/reject reuses the
  same "clear the field's other pending rows" step, just triggered manually
  and with `applied_by_id` set.
- **ABV normalization.** `proposed_value` is always a string column (every
  other whitelisted field is already a string). `BottleEdits::Normalize`
  (Task 3) is the single shared place that parses `abv` with `BigDecimal()`
  and re-serializes it with `format("%.1f", ...)` before storing — matching
  the DB column's `precision: 4, scale: 1`. This makes `"45"`, `"45.0"`,
  and `"45.00"` all normalize to `"45.0"` so they group as the identical
  proposal for auto-apply counting, and both the proposal-creation
  controller (Task 5) and the auto-apply/admin-apply write paths (Tasks 3
  and 4) route through it — no second `BigDecimal(...)` call exists
  anywhere else in the corrections flow. Invalid numeric text falls back to
  storing/writing the raw string; `Bottle`'s own
  `validates :abv, numericality: ...` is what actually rejects a bad value,
  at save time, whichever path (auto-apply or admin apply) attempts the
  write — a rejected save leaves every proposal row untouched (see Task 3's
  `apply` method). Non-abv fields are stored as `.to_s.strip` with no
  further normalization — matching the string columns' own validations (no
  case-folding: "Buffalo Trace" and "buffalo trace" are treated as
  different proposals, same as the model layer treats them as different
  values).
- **Slug never changes.** `Bottle#generate_slug` already runs
  `before_validation ..., on: :create` only — renaming via admin edit or an
  applied ghost edit cannot touch `slug` because neither write path calls
  `valid?` with `on: :create`, and `slug` is never in either permitted
  params list. This plan adds a regression test pinning it (Task 1) because
  slugs are public URLs and a silent regeneration would 404 every existing
  link to a renamed bottle.

## Global Constraints

- **Docker-only.** Every migration/test/generator command runs as
  `docker compose exec -T web bin/rails ...`. Never run `bin/rails` on the
  host. Test runs use `docker compose exec -T web bin/rails test` (whole
  suite) or `docker compose exec -T web bin/rails test test/path/to/file.rb`
  (one file) — **never pass multiple explicit file paths in one invocation.**
- **Schema dump rides with the migration commit.** Any migration task MUST
  `git add db/schema.rb` (regenerated) in the SAME commit as the migration
  file. Parallel test workers build their databases from `db/schema.rb`, not
  by replaying migrations — a stale dump makes every parallel worker error
  out while a single-file run still passes (false green).
- **Ghost-edit whitelist (exact):** `name, distillery, region, style, abv`.
  Never `slug`, never `created_by_id`, never any future enrichment column
  without a follow-up plan.
- **Auto-apply threshold:** `Rails.application.config.x.bottle_edits.auto_apply_threshold`,
  default `3` (set in `config/application.rb`; owner's "100" is the
  eventual-scale intent, not a launch value — do not hardcode 100 anywhere).
- **Uniqueness:** partial unique index on `bottle_edits(bottle_id, field, user_id)
  WHERE status = 'pending'` — one LIVE proposal per user/field/bottle. A
  user may still hold live proposals on multiple DIFFERENT fields for the
  same bottle, and may propose again on the same field once their prior
  proposal on it has resolved (applied or rejected).
- **Slug-never-changes rule:** renaming a bottle (admin edit or an applied
  ghost edit to the `name` or `distillery` field) must NOT regenerate
  `slug` — slugs are public URLs. `Bottle#generate_slug` is `on: :create`
  only; keep it that way. Any task touching `Bottle` validations or save
  paths must re-run `test/models/bottle_test.rb`'s slug tests and the new
  regression test from Task 1.
- **Suite baseline (verified this session, branch `overhaul/full-refresh`,
  HEAD `da35f9b`): 327 runs, 1183 assertions, 0 failures, 0 errors, 9 skips.**
  Every task states its expected run-count delta as arithmetic from 327;
  expect 0 failures / 0 errors at every checkpoint — a new failure is this
  plan's regression, fix before proceeding, never carry it forward as
  "pre-existing."
- **Scope fence (YAGNI — the spec doesn't ask):** no moderation queue beyond
  apply/reject, no notification emails, no rate limiting on proposal
  submission, no enrichment columns, no admin bottle merge/dedup tool.
- Design tokens (for any view work): white/whiskey-50 surfaces, `.eyebrow`
  kickers, `font-display` headings, `rounded-2xl border border-gray-200
  bg-white shadow-sm` public cards, `rounded-lg`/`rounded-xl` admin cards
  matching `admin/presentations/_form.html.erb`. Admin house pattern
  (`Admin::BaseController`): `authenticate_admin!` + `layout "admin"`,
  destructive/state-changing actions as separate member routes,
  `button_to ... method: :patch/:delete`.

---

### Task 1: Admin full-field edit (`Admin::BottlesController#edit/#update`)

**Files:** modify `app/controllers/admin/bottles_controller.rb`,
`config/routes.rb`, `app/views/admin/bottles/show.html.erb`, create
`app/views/admin/bottles/edit.html.erb`, modify
`test/controllers/admin/bottles_controller_test.rb`, modify
`test/models/bottle_test.rb` (slug-stability regression).
**Interfaces:** `Admin::BottlesController#edit` (GET, renders form) /
`#update` (PATCH, permits `name, distillery, region, style, abv`, redirects
to `admin_bottle_path(@bottle)` with a notice on success, re-renders `:edit`
with `:unprocessable_entity` on validation failure). Route helper
`edit_admin_bottle_path(bottle)`.

- [ ] **Step 1 — failing controller test + slug regression test.** Add to
`test/controllers/admin/bottles_controller_test.rb`, inside the existing
`Admin::BottlesControllerTest` class (after the `"admin can unpin"` test):

```ruby
  test "admin can view the edit form" do
    get edit_admin_bottle_path(bottles(:eagle_rare))
    assert_response :success
    assert_select "input[name='bottle[name]'][value=?]", bottles(:eagle_rare).name
  end

  test "admin can update bottle fields" do
    bottle = bottles(:eagle_rare)
    patch admin_bottle_path(bottle), params: { bottle: {
      name: "Eagle Rare 10 Year", distillery: "Buffalo Trace Distillery",
      region: "Kentucky", style: "Bourbon", abv: "45.5"
    } }
    assert_redirected_to admin_bottle_path(bottle)
    bottle.reload
    assert_equal "Eagle Rare 10 Year", bottle.name
    assert_equal "Buffalo Trace Distillery", bottle.distillery
    assert_equal "45.5".to_d, bottle.abv
  end

  test "admin edit renaming a bottle does not change its slug" do
    bottle = bottles(:eagle_rare)
    original_slug = bottle.slug
    patch admin_bottle_path(bottle), params: { bottle: { name: "Totally Different Name" } }
    assert_equal original_slug, bottle.reload.slug
    assert_equal "Totally Different Name", bottle.name
  end

  test "admin update with invalid data re-renders the edit form" do
    bottle = bottles(:eagle_rare)
    patch admin_bottle_path(bottle), params: { bottle: { name: "", abv: "500" } }
    assert_response :unprocessable_entity
    assert_not_equal "", bottle.reload.name
  end

  test "non-admin cannot edit or update a bottle" do
    sign_out users(:admin)
    sign_in users(:john)
    bottle = bottles(:eagle_rare)
    get edit_admin_bottle_path(bottle)
    assert_redirected_to root_path
    patch admin_bottle_path(bottle), params: { bottle: { name: "Hijacked" } }
    assert_redirected_to root_path
    assert_not_equal "Hijacked", bottle.reload.name
  end
```

Also add to `test/models/bottle_test.rb`, inside `class BottleTest`, right
after the `"deduplicates slugs with a numeric suffix"` test — this is the
model-level half of the slug-stability guarantee (the controller test above
covers the admin write path; this one pins the model invariant directly so
it fails loudly regardless of which future write path touches the record):

```ruby
  test "updating name or distillery after creation does not regenerate the slug" do
    bottle = bottles(:eagle_rare)
    original_slug = bottle.slug
    bottle.update!(name: "Eagle Rare Renamed", distillery: "New Distillery Co")
    assert_equal original_slug, bottle.slug
  end
```

Run `docker compose exec -T web bin/rails test test/controllers/admin/bottles_controller_test.rb` —
fails (no `edit`/`update` action, no route). Run
`docker compose exec -T web bin/rails test test/models/bottle_test.rb` —
this one already passes today (proving the invariant already holds before
any code changes in this task); confirm it's green so Task 1's only real
failing surface is the controller.

- [ ] **Step 2 — routes.** Edit `config/routes.rb`, inside
`namespace :admin do ... resources :bottles, only: [:index, :show] do`
— change `only: [:index, :show]` to add `:edit, :update`:

```ruby
    resources :bottles, only: [:index, :show, :edit, :update] do
      member do
        patch :pin_image
        delete :unpin_image
      end
      resources :reviews, only: [], module: :bottles do
        member { delete :destroy_image }
      end
    end
```

(This is the existing block — only the `only:` list on the outer
`resources :bottles` line changes; the `member`/nested `reviews` blocks are
unchanged, reproduced here for context so the edit is unambiguous.)

- [ ] **Step 3 — controller.** Edit `app/controllers/admin/bottles_controller.rb`:

```ruby
# app/controllers/admin/bottles_controller.rb
# Pin/unpin the label image, full-field edit. Delete flows live in
# Bottles::ReviewsController. Ghost-edit proposal review lives on #show.
class Admin::BottlesController < Admin::BaseController
  before_action :set_bottle, except: [ :index ]

  def index
    @bottles = Bottle.with_score.order(:name)
  end

  def show
    @reviews = @bottle.reviews.includes(:user, images_attachments: :blob).order(created_at: :desc)
  end

  def edit
  end

  def update
    if @bottle.update(bottle_edit_params)
      redirect_to admin_bottle_path(@bottle), notice: "Bottle updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def pin_image
    if params.dig(:bottle, :pinned_label_image).blank?
      redirect_to admin_bottle_path(@bottle), alert: "Choose an image to pin."
    else
      @bottle.pinned_label_image.attach(bottle_params[:pinned_label_image])
      redirect_to admin_bottle_path(@bottle), notice: "Label image pinned."
    end
  end

  def unpin_image
    @bottle.pinned_label_image.purge
    redirect_to admin_bottle_path(@bottle), notice: "Pin removed — the derived image (or placeholder) shows again."
  end

  private

  def set_bottle
    @bottle = Bottle.find_by!(slug: params[:id])
  end

  def bottle_params
    params.require(:bottle).permit(:pinned_label_image)
  end

  # Same five fields the ghost-edit whitelist uses (Task 2) — slug and
  # created_by_id are deliberately never permitted here.
  def bottle_edit_params
    params.require(:bottle).permit(:name, :distillery, :region, :style, :abv)
  end
end
```

Run `docker compose exec -T web bin/rails test test/controllers/admin/bottles_controller_test.rb` —
still fails on the two new tests that hit `edit_admin_bottle_path` (no view yet).

- [ ] **Step 4 — view.** Create `app/views/admin/bottles/edit.html.erb`,
matching the admin form conventions in
`app/views/admin/presentations/_form.html.erb` (rounded-lg inputs,
`bg-whiskey-600` submit) and the breadcrumb pattern from
`app/views/admin/presentations/edit.html.erb`:

```erb
<% content_for :title, "Edit #{@bottle.name} - Admin" %>

<div class="mb-8">
  <div class="flex items-center gap-4 mb-4">
    <%= link_to admin_bottle_path(@bottle), class: "text-gray-500 hover:text-gray-700" do %>
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
      </svg>
    <% end %>
    <h1 class="text-3xl font-bold text-gray-900">Edit <%= @bottle.name %></h1>
  </div>
</div>

<div class="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm max-w-xl">
  <%= form_with model: @bottle, url: admin_bottle_path(@bottle), method: :patch, local: true, class: "space-y-5" do |form| %>
    <% if @bottle.errors.any? %>
      <div class="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
        <%= @bottle.errors.full_messages.to_sentence %>
      </div>
    <% end %>

    <div>
      <%= form.label :name, "Bottle name", class: "mb-2 block text-sm font-medium text-gray-700" %>
      <%= form.text_field :name, class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
    </div>
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
      <div>
        <%= form.label :distillery, class: "mb-2 block text-sm font-medium text-gray-700" %>
        <%= form.text_field :distillery, class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
      </div>
      <div>
        <%= form.label :region, class: "mb-2 block text-sm font-medium text-gray-700" %>
        <%= form.text_field :region, class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
      </div>
      <div>
        <%= form.label :style, class: "mb-2 block text-sm font-medium text-gray-700" %>
        <%= form.text_field :style, class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
      </div>
      <div>
        <%= form.label :abv, "ABV %", class: "mb-2 block text-sm font-medium text-gray-700" %>
        <%= form.number_field :abv, step: 0.1, min: 0, max: 99, class: "w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500" %>
      </div>
    </div>

    <div class="flex items-center gap-3 pt-2">
      <%= form.submit "Save changes", class: "cursor-pointer rounded-xl bg-whiskey-600 px-6 py-3 font-semibold text-white transition hover:bg-whiskey-700" %>
      <%= link_to "Cancel", admin_bottle_path(@bottle), class: "rounded-xl bg-gray-100 px-6 py-3 font-semibold text-gray-700 transition hover:bg-gray-200" %>
    </div>
  <% end %>
</div>
```

Add an "Edit bottle" link on `app/views/admin/bottles/show.html.erb`, in
the header block right after the existing "View bottle" link:

```erb
  <%= link_to "View bottle", bottle_path(@bottle), class: "text-whiskey-600 hover:text-whiskey-700" %>
  <%= link_to "Edit bottle", edit_admin_bottle_path(@bottle), class: "ml-4 text-whiskey-600 hover:text-whiskey-700" %>
```

(Replaces the single existing `link_to "View bottle", ...` line — both
links now sit side by side.)

Run `docker compose exec -T web bin/rails test test/controllers/admin/bottles_controller_test.rb` —
expect 11 runs green (6 pre-existing + 5 new). Run
`docker compose exec -T web bin/rails test test/models/bottle_test.rb` —
expect 5 runs green (4 pre-existing + 1 new). Full suite:
`docker compose exec -T web bin/rails test` — expect **333 runs** (327 + 5
controller + 1 model), 0 failures, 0 errors, 9 skips.

Commit: `Admin can edit bottle fields (name/distillery/region/style/abv); pin slug stability with a regression test`

---

### Task 2: `bottle_edits` table + `BottleEdit` model + `Bottle#bottle_edits`

**Files:** create migration via generator, modify `db/schema.rb` (generated,
commit alongside), create `app/models/bottle_edit.rb`, modify
`app/models/bottle.rb` (add `has_many :bottle_edits`), modify
`config/application.rb` (the `config.x` threshold), create
`test/models/bottle_edit_test.rb`, create `test/fixtures/bottle_edits.yml`
(empty — no seed rows needed; fixtures file must exist so Rails doesn't
warn on an undeclared table, matching how other new tables in this codebase
started with an empty fixtures file — check `test/fixtures/favorites.yml`'s
history if unsure, but an empty file is sufficient and is what this task
creates).

**Interfaces:** `BottleEdit` columns: `bottle_id` (bigint, FK), `user_id`
(bigint, FK), `field` (string, not null), `proposed_value` (string, not
null), `status` (string, not null, default `"pending"`), `applied_at`
(datetime, nullable), `applied_by_id` (bigint, FK to users, nullable).
`BottleEdit::FIELDS = %w[name distillery region style abv].freeze`.
`BottleEdit::STATUSES = %w[pending applied rejected].freeze`. Partial
unique index `(bottle_id, field, user_id) WHERE status = 'pending'` named
`index_bottle_edits_on_live_proposal`. `Rails.application.config.x.bottle_edits.auto_apply_threshold`
(Integer, default `3`).

- [ ] **Step 1 — failing model test.** Create `test/models/bottle_edit_test.rb`:

```ruby
require "test_helper"

class BottleEditTest < ActiveSupport::TestCase
  setup { @bottle = bottles(:eagle_rare) }

  test "valid with a whitelisted field and a live status" do
    edit = BottleEdit.new(bottle: @bottle, user: users(:john), field: "distillery", proposed_value: "New Co")
    assert edit.valid?
  end

  test "field must be one of the whitelisted columns" do
    edit = BottleEdit.new(bottle: @bottle, user: users(:john), field: "slug", proposed_value: "hijacked")
    assert_not edit.valid?
    assert_includes edit.errors[:field], "is not included in the list"
  end

  test "status defaults to pending" do
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    assert_equal "pending", edit.status
  end

  test "status must be one of the known values" do
    edit = BottleEdit.new(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands", status: "bogus")
    assert_not edit.valid?
    assert_includes edit.errors[:status], "is not included in the list"
  end

  test "one live proposal per user per field per bottle" do
    BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    dupe = BottleEdit.new(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Speyside")
    assert_not dupe.valid?
    assert_includes dupe.errors[:user_id], "has already been taken"
  end

  test "a user may propose again on the same field once their prior proposal resolved" do
    first = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    first.update!(status: "rejected")
    second = BottleEdit.new(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Speyside")
    assert second.valid?
  end

  test "the same user may hold live proposals on two different fields" do
    BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    other_field = BottleEdit.new(bottle: @bottle, user: users(:john), field: "style", proposed_value: "Bourbon")
    assert other_field.valid?
  end

  test "two different users may each propose the same field live at once" do
    BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    other_user = BottleEdit.new(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Highlands")
    assert other_user.valid?
  end

  test "Bottle#bottle_edits returns its proposals" do
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    assert_includes @bottle.bottle_edits, edit
  end

  test "FIELDS is the exact five-column whitelist" do
    assert_equal %w[name distillery region style abv], BottleEdit::FIELDS
  end

  test "default auto-apply threshold is 3" do
    assert_equal 3, Rails.application.config.x.bottle_edits.auto_apply_threshold
  end
end
```

Run `docker compose exec -T web bin/rails test test/models/bottle_edit_test.rb` —
fails (no `bottle_edits` table, no `BottleEdit` constant).

- [ ] **Step 2 — migration.**

```
docker compose exec -T web bin/rails generate migration CreateBottleEdits
```

Edit the generated `db/migrate/<timestamp>_create_bottle_edits.rb`:

```ruby
class CreateBottleEdits < ActiveRecord::Migration[8.0]
  def change
    create_table :bottle_edits do |t|
      t.references :bottle, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :field, null: false
      t.string :proposed_value, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :applied_at
      t.references :applied_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :bottle_edits, [ :bottle_id, :field, :user_id ], unique: true,
      where: "status = 'pending'", name: "index_bottle_edits_on_live_proposal"
    add_index :bottle_edits, [ :bottle_id, :field, :status ], name: "index_bottle_edits_on_bottle_field_status"
  end
end
```

Run:

```
docker compose exec -T web bin/rails db:migrate
```

**Commit the regenerated `db/schema.rb` in this same commit** — confirm the
new `bottle_edits` table block and its two indexes appear, and that
`version:` at the top of `db/schema.rb` advanced to this migration's
timestamp.

- [ ] **Step 3 — `config.x` threshold.** Edit `config/application.rb`, add
inside `class Application < Rails::Application`, after
`config.generators.system_tests = nil`:

```ruby
    # Ghost-edit corrections: how many DISTINCT users proposing the identical
    # field+value auto-applies it. 3 while the community is small — the
    # eventual-scale intent is much higher, tune via ENV/environment config
    # later, never hardcode a "final" number here.
    config.x.bottle_edits.auto_apply_threshold = 3
```

- [ ] **Step 4 — model.** Create `app/models/bottle_edit.rb`:

```ruby
# A community-proposed correction to one field on a bottle. Lives as
# "pending" until enough distinct users agree on the identical value
# (BottleEdits::AutoApply, Task 3) or an admin applies/rejects it by hand
# (Admin::BottleEditsController, Task 4). Applied/rejected rows are kept —
# they're the "who proposed, when applied" audit trail, not scratch data.
class BottleEdit < ApplicationRecord
  FIELDS = %w[name distillery region style abv].freeze
  STATUSES = %w[pending applied rejected].freeze

  belongs_to :bottle
  belongs_to :user
  belongs_to :applied_by, class_name: "User", optional: true

  validates :field, inclusion: { in: FIELDS }
  validates :status, inclusion: { in: STATUSES }
  validates :proposed_value, presence: true
  validates :user_id, uniqueness: {
    scope: [ :bottle_id, :field ],
    conditions: -> { where(status: "pending") },
    message: "has already been taken"
  }, if: -> { status == "pending" }

  scope :pending, -> { where(status: "pending") }
  scope :for_field, ->(field) { where(field: field) }
end
```

Edit `app/models/bottle.rb` — add after `has_many :reviews, dependent: :destroy`:

```ruby
  has_many :bottle_edits, dependent: :destroy
```

Run `docker compose exec -T web bin/rails test test/models/bottle_edit_test.rb` —
expect 11 runs green. Full suite:
`docker compose exec -T web bin/rails test` — expect **344 runs**
(333 + 11), 0 failures, 0 errors, 9 skips.

Commit: `Add bottle_edits table and BottleEdit model (ghost-edit proposal ledger)`

---

### Task 3: `BottleEdits::AutoApply` service

**Files:** create `app/services/bottle_edits/auto_apply.rb`, create
`test/services/bottle_edits/auto_apply_test.rb`.

**Interfaces:** `BottleEdits::AutoApply.call(bottle:, field:)` → returns
`true` if it applied a value, `false` otherwise. Counts DISTINCT `user_id`
among `bottle.bottle_edits.pending.for_field(field)` grouped by
`proposed_value`; if any group's distinct-user count
`>= Rails.application.config.x.bottle_edits.auto_apply_threshold`, writes
the winning `proposed_value` onto `bottle[field]` (using
`BottleEdits::Normalize.for_write(field, value)`, see below, so `abv`
lands as a `BigDecimal` not a string), saves the bottle with
`validate: false` is NOT used — it saves normally so bottle-level
validations (e.g., abv range) still gate a bad auto-apply; marks every
pending row in the winning group `status: "applied", applied_at: Time.current,
applied_by: nil`; marks every OTHER pending row for that bottle+field
(competing values) `status: "rejected"`. All of this runs inside a
transaction. If two groups both cross the threshold in the same call
(shouldn't happen in practice — a proposal create only ever adds to one
group — but the service is defensive), the group with the most distinct
users wins; a tie picks the earliest-created group.

- [ ] **Step 1 — failing service test.** Create
`test/services/bottle_edits/auto_apply_test.rb`:

```ruby
require "test_helper"

class BottleEdits::AutoApplyTest < ActiveSupport::TestCase
  setup { @bottle = bottles(:eagle_rare) }

  def propose(user, field, value)
    BottleEdit.create!(bottle: @bottle, user: user, field: field, proposed_value: value)
  end

  test "does nothing below the threshold" do
    propose(users(:john), "region", "Highlands")
    propose(users(:jane), "region", "Highlands")
    assert_not BottleEdits::AutoApply.call(bottle: @bottle, field: "region")
    assert_equal "Kentucky", @bottle.reload.region
  end

  test "applies once the threshold of distinct users on the identical value is reached" do
    propose(users(:john), "region", "Highlands")
    propose(users(:jane), "region", "Highlands")
    propose(users(:seth), "region", "Highlands")
    assert BottleEdits::AutoApply.call(bottle: @bottle, field: "region")
    assert_equal "Highlands", @bottle.reload.region
  end

  test "applied rows are marked applied with a nil applied_by (auto)" do
    e1 = propose(users(:john), "region", "Highlands")
    e2 = propose(users(:jane), "region", "Highlands")
    e3 = propose(users(:seth), "region", "Highlands")
    BottleEdits::AutoApply.call(bottle: @bottle, field: "region")
    [ e1, e2, e3 ].each do |e|
      e.reload
      assert_equal "applied", e.status
      assert_nil e.applied_by_id
      assert_not_nil e.applied_at
    end
  end

  test "competing pending proposals on the same field are cleared (rejected) when one wins" do
    winner_users = [ users(:john), users(:jane), users(:seth) ]
    winner_users.each { |u| propose(u, "region", "Highlands") }
    loser = propose(users(:admin), "region", "Speyside")
    BottleEdits::AutoApply.call(bottle: @bottle, field: "region")
    assert_equal "rejected", loser.reload.status
    assert_nil loser.applied_at
  end

  test "does not touch pending proposals on a different field" do
    propose(users(:john), "region", "Highlands")
    propose(users(:jane), "region", "Highlands")
    propose(users(:seth), "region", "Highlands")
    other_field = propose(users(:one), "style", "Bourbon")
    BottleEdits::AutoApply.call(bottle: @bottle, field: "region")
    assert_equal "pending", other_field.reload.status
  end

  test "abv proposals normalize before grouping so 45, 45.0, and 45.00 count together" do
    propose(users(:john), "abv", "45")
    propose(users(:jane), "abv", "45.0")
    propose(users(:seth), "abv", "45.00")
    assert BottleEdits::AutoApply.call(bottle: @bottle, field: "abv")
    assert_equal "45.0".to_d, @bottle.reload.abv
  end

  test "does not apply a value that would fail bottle validation" do
    propose(users(:john), "abv", "500")
    propose(users(:jane), "abv", "500")
    propose(users(:seth), "abv", "500")
    assert_not BottleEdits::AutoApply.call(bottle: @bottle, field: "abv")
    assert_not_equal "500".to_d, @bottle.reload.abv
  end
end
```

Run `docker compose exec -T web bin/rails test test/services/bottle_edits/auto_apply_test.rb` —
fails (no `BottleEdits::AutoApply` constant).

- [ ] **Step 2 — implementation.** Create `app/services/bottle_edits/auto_apply.rb`:

```ruby
# BottleEdits::AutoApply — runs after a proposal is created (see
# Bottles::EditsController#create, Task 5). Checks whether any proposed
# value for the given bottle+field now has enough DISTINCT proposing users
# to auto-apply; if so, writes it onto the bottle, marks the winning rows
# applied, and clears (rejects) every other pending proposal on that field
# — competing values included, per spec.
module BottleEdits
  class AutoApply
    def self.call(bottle:, field:) = new(bottle, field).call

    def initialize(bottle, field)
      @bottle = bottle
      @field = field
    end

    def call
      groups = BottleEdit.pending.for_field(@field).where(bottle: @bottle)
                          .group(:proposed_value).distinct.count(:user_id)
      threshold = Rails.application.config.x.bottle_edits.auto_apply_threshold
      winning_value, distinct_count = groups.max_by { |_value, count| count }
      return false if winning_value.nil? || distinct_count < threshold

      apply(winning_value)
    end

    private

    # Explicit flag rather than relying on transaction/save return values —
    # a failed bottle save (e.g., an out-of-range abv) must leave every
    # proposal row untouched and report false, not partially update rows.
    def apply(winning_value)
      applied = false
      ActiveRecord::Base.transaction do
        @bottle[@field] = BottleEdits::Normalize.for_write(@field, winning_value)
        if @bottle.save
          applied = true
          pending = BottleEdit.pending.for_field(@field).where(bottle: @bottle)
          pending.where(proposed_value: winning_value)
                 .update_all(status: "applied", applied_at: Time.current, applied_by_id: nil)
          pending.where.not(proposed_value: winning_value)
                 .update_all(status: "rejected")
        end
      end
      applied
    end
  end
end
```

Create `app/services/bottle_edits/normalize.rb` — the shared normalization
both this service and the proposal-creation controller (Task 5) use, so the
"identical value" comparison and the actual DB write agree:

```ruby
# Shared value normalization for ghost-edit proposals: what gets STORED as
# proposed_value (so identical submissions group together for auto-apply)
# and what gets WRITTEN onto the bottle column when a proposal is applied.
# abv is the only field needing numeric normalization — the other four
# whitelisted fields are strings compared as-is (no case-folding: "Buffalo
# Trace" and "buffalo trace" are different proposals, matching how the
# model layer treats them as different values).
module BottleEdits
  class Normalize
    # String → String, safe to store as BottleEdit#proposed_value.
    def self.for_storage(field, raw_value)
      value = raw_value.to_s.strip
      return value unless field == "abv"

      begin
        format("%.1f", BigDecimal(value))
      rescue ArgumentError, TypeError
        value # invalid numeric text is stored as-is; Bottle's own
              # numericality validation catches it if/when it's ever applied
      end
    end

    # String → the type Bottle#<field>= expects (BigDecimal for abv, String
    # otherwise).
    def self.for_write(field, stored_value)
      return stored_value unless field == "abv"

      BigDecimal(stored_value)
    rescue ArgumentError, TypeError
      stored_value
    end
  end
end
```

Run `docker compose exec -T web bin/rails test test/services/bottle_edits/auto_apply_test.rb` —
expect 7 runs green. Full suite:
`docker compose exec -T web bin/rails test` — expect **351 runs**
(344 + 7), 0 failures, 0 errors, 9 skips.

Commit: `Add BottleEdits::AutoApply and shared value normalization (abv rounds to one decimal for grouping)`

---

### Task 4: Admin apply/reject surface (`Admin::Bottles::EditsController`)

**Files:** create `app/controllers/admin/bottles/edits_controller.rb`,
modify `config/routes.rb`, modify `app/controllers/admin/bottles_controller.rb`
(load pending proposals on `#show`), modify `app/views/admin/bottles/show.html.erb`,
create `test/controllers/admin/bottles/edits_controller_test.rb`.

**Interfaces:** `POST /admin/bottles/:bottle_id/edits/:id/apply` →
`Admin::Bottles::EditsController#apply` — applies THIS row's value: writes
it onto the bottle, marks this row (and every other pending row with the
SAME field+value) `applied` with `applied_by: current_user`, and marks
every OTHER pending row on that field (different values) `rejected`.
`DELETE /admin/bottles/:bottle_id/edits/:id` →
`Admin::Bottles::EditsController#reject` — marks just this one row
`rejected` (other pending rows on the field, including same-value ones
from other users, are untouched — an admin rejecting a lone crank proposal
should not touch other users' live proposals on the same field). Both
redirect to `admin_bottle_path(@bottle)`. `Admin::BottlesController#show`
gains `@pending_edits = @bottle.bottle_edits.pending.includes(:user).group_by(&:field)`
— grouped by field for the view; each field's proposals additionally group
by `proposed_value` in the view (not the controller) since the view needs
per-value user lists for the "distinct users" count.

- [ ] **Step 1 — failing controller test.** Create
`test/controllers/admin/bottles/edits_controller_test.rb`:

```ruby
require "test_helper"

class Admin::Bottles::EditsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
    @bottle = bottles(:eagle_rare)
  end

  test "admin can apply a single pending proposal" do
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    post apply_admin_bottle_edit_path(@bottle, edit)
    assert_redirected_to admin_bottle_path(@bottle)
    assert_equal "Highlands", @bottle.reload.region
    edit.reload
    assert_equal "applied", edit.status
    assert_equal users(:admin), edit.applied_by
    assert_not_nil edit.applied_at
  end

  test "applying one proposal clears competing pending proposals on the same field" do
    winner = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    loser = BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Speyside")
    other_field = BottleEdit.create!(bottle: @bottle, user: users(:seth), field: "style", proposed_value: "Bourbon")
    post apply_admin_bottle_edit_path(@bottle, winner)
    assert_equal "rejected", loser.reload.status
    assert_equal "pending", other_field.reload.status
  end

  test "applying one proposal also applies co-proposers of the identical value" do
    a = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    b = BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Highlands")
    post apply_admin_bottle_edit_path(@bottle, a)
    assert_equal "applied", b.reload.status
    assert_equal users(:admin), b.applied_by
  end

  test "admin can reject a single proposal without touching others" do
    reject_me = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    leave_me = BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Highlands")
    delete admin_bottle_edit_path(@bottle, reject_me)
    assert_redirected_to admin_bottle_path(@bottle)
    assert_equal "rejected", reject_me.reload.status
    assert_equal "pending", leave_me.reload.status
    assert_not_equal "Highlands", @bottle.reload.region
  end

  test "applying a proposal with invalid data re-renders without crashing" do
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "abv", proposed_value: "500.0")
    post apply_admin_bottle_edit_path(@bottle, edit)
    assert_redirected_to admin_bottle_path(@bottle)
    assert_equal "pending", edit.reload.status
    assert_not_equal "500.0".to_d, @bottle.reload.abv
  end

  test "non-admin cannot apply or reject" do
    sign_out users(:admin)
    sign_in users(:john)
    edit = BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Highlands")
    post apply_admin_bottle_edit_path(@bottle, edit)
    assert_redirected_to root_path
    delete admin_bottle_edit_path(@bottle, edit)
    assert_redirected_to root_path
    assert_equal "pending", edit.reload.status
  end

  test "an edit addressed under the wrong bottle's URL is not found" do
    other_bottle = bottles(:lagavulin)
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    post apply_admin_bottle_edit_path(other_bottle, edit)
    assert_response :not_found
  end
end
```

Run `docker compose exec -T web bin/rails test test/controllers/admin/bottles/edits_controller_test.rb` —
fails (no route, no controller).

- [ ] **Step 2 — routes.** Edit `config/routes.rb`, inside
`namespace :admin do ... resources :bottles, only: [:index, :show, :edit, :update] do`
— add an `edits` nested resource alongside the existing nested `reviews`:

```ruby
    resources :bottles, only: [:index, :show, :edit, :update] do
      member do
        patch :pin_image
        delete :unpin_image
      end
      resources :reviews, only: [], module: :bottles do
        member { delete :destroy_image }
      end
      resources :edits, only: [:destroy], module: :bottles do
        member { post :apply }
      end
    end
```

(Reproduces the full block for context — only the new `resources :edits`
line is added; `pin_image`/`unpin_image`/`reviews` are unchanged from
Task 1.) `:destroy` here is the "reject" action per REST convention
(removing a proposal from the live/pending set) — the view route helper
`admin_bottle_edit_path(bottle, edit)` maps to `DELETE`, and
`apply_admin_bottle_edit_path(bottle, edit)` maps to `POST`.

- [ ] **Step 3 — controller.** Create `app/controllers/admin/bottles/edits_controller.rb`:

```ruby
# app/controllers/admin/bottles/edits_controller.rb
# Manual apply/reject for a single ghost-edit proposal. Distinct from
# BottleEdits::AutoApply (Task 3) but shares its "clear the field" step —
# applying manually still resolves every pending proposal on the field.
class Admin::Bottles::EditsController < Admin::BaseController
  before_action :set_bottle
  before_action :set_edit

  def apply
    field = @edit.field
    value = @edit.proposed_value
    applied = false

    ActiveRecord::Base.transaction do
      @bottle[field] = BottleEdits::Normalize.for_write(field, value)
      if @bottle.save
        applied = true
        pending = @bottle.bottle_edits.pending.for_field(field)
        pending.where(proposed_value: value)
               .update_all(status: "applied", applied_at: Time.current, applied_by_id: current_user.id)
        pending.where.not(proposed_value: value)
               .update_all(status: "rejected")
      end
    end

    if applied
      redirect_to admin_bottle_path(@bottle), notice: "Applied #{field}: #{value.inspect}."
    else
      redirect_to admin_bottle_path(@bottle), alert: "Couldn't apply that value: #{@bottle.errors.full_messages.to_sentence}"
    end
  end

  def destroy
    @edit.update!(status: "rejected")
    redirect_to admin_bottle_path(@bottle), notice: "Proposal rejected."
  end

  private

  def set_bottle
    @bottle = Bottle.find_by!(slug: params[:bottle_id])
  end

  def set_edit
    @edit = @bottle.bottle_edits.find(params[:id])
  end
end
```

Run `docker compose exec -T web bin/rails test test/controllers/admin/bottles/edits_controller_test.rb` —
expect 7 runs green.

- [ ] **Step 4 — view: pending proposals on the admin bottle page.** Edit
`app/controllers/admin/bottles_controller.rb`'s `#show` action:

```ruby
  def show
    @reviews = @bottle.reviews.includes(:user, images_attachments: :blob).order(created_at: :desc)
    @pending_edits = @bottle.bottle_edits.pending.includes(:user).group_by(&:field)
  end
```

Add a new card to `app/views/admin/bottles/show.html.erb`, right after the
"Label Image" card and before the "Reviews List" card:

```erb
<!-- Pending Corrections -->
<% if @pending_edits.any? %>
  <div class="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm mb-6">
    <h2 class="text-lg font-semibold text-gray-900 mb-6">Suggested Corrections</h2>
    <% @pending_edits.each do |field, edits| %>
      <div class="mb-6 last:mb-0">
        <h3 class="text-sm font-semibold text-gray-900 mb-3 capitalize"><%= field %></h3>
        <div class="divide-y divide-gray-100 rounded-lg border border-gray-200">
          <% edits.group_by(&:proposed_value).each do |value, value_edits| %>
            <div class="flex items-center justify-between gap-4 p-4">
              <div>
                <p class="font-medium text-gray-900"><%= value %></p>
                <p class="mt-1 text-sm text-gray-600">
                  Proposed by <%= value_edits.map { |e| e.user.full_name }.to_sentence %>
                  (<%= pluralize(value_edits.size, "vote") %>)
                </p>
              </div>
              <div class="flex shrink-0 gap-2">
                <%= button_to "Apply", apply_admin_bottle_edit_path(@bottle, value_edits.first), method: :post,
                    class: "px-3 py-1 bg-green-50 text-green-700 font-medium rounded text-sm hover:bg-green-100 cursor-pointer" %>
                <%= button_to "Reject", admin_bottle_edit_path(@bottle, value_edits.first), method: :delete,
                    data: { turbo_confirm: "Reject this proposal?" },
                    class: "px-3 py-1 bg-red-50 text-red-700 font-medium rounded text-sm hover:bg-red-100 cursor-pointer" %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
<% end %>
```

("Apply" posts the first row of that value-group — the controller's
`apply` action then resolves every co-proposer of the same value AND every
competing value on the field, so which specific row's id rides in the URL
doesn't matter as long as it belongs to the winning value.)

Run `docker compose exec -T web bin/rails test test/controllers/admin/bottles_controller_test.rb test/controllers/admin/bottles/edits_controller_test.rb` —
still expect all green (the `#show` action change is additive; no existing
test asserts `@pending_edits` is absent). Full suite:
`docker compose exec -T web bin/rails test` — expect **358 runs**
(351 + 7), 0 failures, 0 errors, 9 skips.

Commit: `Admin can apply or reject ghost-edit proposals; pending corrections show on the admin bottle page`

---

### Task 5: Public "suggest a correction" flow (`Bottles::EditsController`)

**Files:** create `app/controllers/bottles/edits_controller.rb`, modify
`config/routes.rb`, create `app/views/bottles/edits/new.html.erb`, modify
`app/views/bottles/show.html.erb` (entry-point link), create
`test/controllers/bottles/edits_controller_test.rb`.

**Interfaces:** `GET /bottles/:bottle_id/edits/new` →
`Bottles::EditsController#new` — pre-filled form, one field per whitelisted
column, current value as the default. `POST /bottles/:bottle_id/edits` →
`Bottles::EditsController#create` — for each of the five whitelisted
fields, compares the submitted (normalized) value against the bottle's
CURRENT value; only fields that actually changed become `BottleEdit` rows;
after creating rows, runs `BottleEdits::AutoApply.call` once per changed
field; redirects to `bottle_path(@bottle)` with a notice. Both actions
`before_action :authenticate_user!`.

- [ ] **Step 1 — failing controller test.** Create
`test/controllers/bottles/edits_controller_test.rb`:

```ruby
require "test_helper"

class Bottles::EditsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:john)
    @bottle = bottles(:eagle_rare)
  end

  test "signed-in user can view the pre-filled suggest-a-correction form" do
    get new_bottle_edit_path(@bottle)
    assert_response :success
    assert_select "input[name='bottle_edit[region]'][value=?]", @bottle.region
  end

  test "signed-out user is redirected to sign in" do
    sign_out users(:john)
    get new_bottle_edit_path(@bottle)
    assert_redirected_to new_user_session_path
  end

  test "submitting with only unchanged fields creates no proposals" do
    assert_no_difference "BottleEdit.count" do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: @bottle.name, distillery: @bottle.distillery,
        region: @bottle.region, style: @bottle.style, abv: @bottle.abv.to_s
      } }
    end
    assert_redirected_to bottle_path(@bottle)
  end

  test "submitting a changed field creates exactly one proposal for that field" do
    assert_difference "BottleEdit.count", 1 do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: @bottle.name, distillery: @bottle.distillery,
        region: "Highlands", style: @bottle.style, abv: @bottle.abv.to_s
      } }
    end
    edit = BottleEdit.last
    assert_equal "region", edit.field
    assert_equal "Highlands", edit.proposed_value
    assert_equal users(:john), edit.user
    assert_equal "pending", edit.status
  end

  test "submitting multiple changed fields creates one proposal per changed field" do
    assert_difference "BottleEdit.count", 2 do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: @bottle.name, distillery: "New Distillery Co",
        region: "Highlands", style: @bottle.style, abv: @bottle.abv.to_s
      } }
    end
    fields = BottleEdit.order(:id).last(2).map(&:field)
    assert_equal %w[distillery region], fields.sort
  end

  test "abv is normalized before the changed-value comparison" do
    assert_no_difference "BottleEdit.count" do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: @bottle.name, distillery: @bottle.distillery,
        region: @bottle.region, style: @bottle.style, abv: "45.00"
      } }
    end
  end

  test "a resubmission while a proposal is already live updates nothing new (unique index holds)" do
    BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    assert_no_difference "BottleEdit.count" do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: @bottle.name, distillery: @bottle.distillery,
        region: "Highlands", style: @bottle.style, abv: @bottle.abv.to_s
      } }
    end
  end

  test "the third distinct user proposing the identical value auto-applies it" do
    BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Highlands")
    BottleEdit.create!(bottle: @bottle, user: users(:seth), field: "region", proposed_value: "Highlands")
    post bottle_edits_path(@bottle), params: { bottle_edit: {
      name: @bottle.name, distillery: @bottle.distillery,
      region: "Highlands", style: @bottle.style, abv: @bottle.abv.to_s
    } }
    assert_equal "Highlands", @bottle.reload.region
  end

  test "suggesting a correction never changes the bottle's slug" do
    original_slug = @bottle.slug
    BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "name", proposed_value: "Totally New Name")
    BottleEdit.create!(bottle: @bottle, user: users(:seth), field: "name", proposed_value: "Totally New Name")
    post bottle_edits_path(@bottle), params: { bottle_edit: {
      name: "Totally New Name", distillery: @bottle.distillery,
      region: @bottle.region, style: @bottle.style, abv: @bottle.abv.to_s
    } }
    @bottle.reload
    assert_equal "Totally New Name", @bottle.name
    assert_equal original_slug, @bottle.slug
  end
end
```

Run `docker compose exec -T web bin/rails test test/controllers/bottles/edits_controller_test.rb` —
fails (no route, no controller, no view).

- [ ] **Step 2 — routes.** Edit `config/routes.rb`, inside the public
`resources :bottles, only: [:show, :new, :create], param: :id do` block:

```ruby
  # Bottles
  resources :bottles, only: [:show, :new, :create], param: :id do
    collection { get :search }
    resources :reviews, only: [:new, :create], module: :bottles
    resources :edits, only: [:new, :create], module: :bottles
  end
```

(Reproduces the full block — only the `resources :edits` line is new.)

- [ ] **Step 3 — controller.** Create `app/controllers/bottles/edits_controller.rb`:

```ruby
# app/controllers/bottles/edits_controller.rb
# "Suggest a correction" — any signed-in user proposes new values for the
# five whitelisted bottle fields. Only fields that actually changed become
# BottleEdit rows; each triggers an auto-apply check immediately after
# creation (BottleEdits::AutoApply, Task 3).
class Bottles::EditsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bottle

  def new
  end

  def create
    changed_fields = []

    BottleEdit::FIELDS.each do |field|
      submitted = edit_params[field]
      next if submitted.nil?

      normalized = BottleEdits::Normalize.for_storage(field, submitted)
      current = BottleEdits::Normalize.for_storage(field, @bottle[field])
      next if normalized == current

      edit = @bottle.bottle_edits.pending.for_field(field).find_by(user: current_user)
      next if edit # already has a live proposal on this field — resubmission is a no-op

      @bottle.bottle_edits.create!(user: current_user, field: field, proposed_value: normalized)
      changed_fields << field
    end

    changed_fields.each { |field| BottleEdits::AutoApply.call(bottle: @bottle, field: field) }

    redirect_to bottle_path(@bottle), notice:
      changed_fields.any? ? "Thanks — your correction is on the record." : "No changes to suggest."
  end

  private

  def set_bottle
    @bottle = Bottle.find_by!(slug: params[:bottle_id])
  end

  def edit_params
    params.require(:bottle_edit).permit(*BottleEdit::FIELDS)
  end
end
```

Run `docker compose exec -T web bin/rails test test/controllers/bottles/edits_controller_test.rb` —
still fails on `#new`/`#create` view-rendering tests (no view yet).

- [ ] **Step 4 — view.** Create `app/views/bottles/edits/new.html.erb`,
matching the public form conventions in `app/views/bottles/new.html.erb`:

```erb
<% content_for :title, "Suggest a correction - #{@bottle.name}" %>

<section class="w-full bg-whiskey-50 px-4 py-14">
  <div class="mx-auto max-w-xl">
    <p class="eyebrow text-whiskey-600">Help keep the record straight</p>
    <h1 class="mb-2 mt-1 font-display text-3xl font-semibold text-gray-900">Suggest a correction</h1>
    <p class="mb-8 text-gray-600">
      Change only what's wrong — fields you leave as-is are ignored. Once
      enough members agree on a fix, it applies automatically.
    </p>

    <%= form_with url: bottle_edits_path(@bottle), method: :post, class: "space-y-5 rounded-2xl border border-gray-200 bg-white p-6 shadow-sm" do %>
      <div>
        <label for="bottle_edit_name" class="mb-2 block text-sm font-medium text-gray-700">Bottle name</label>
        <input type="text" name="bottle_edit[name]" id="bottle_edit_name" value="<%= @bottle.name %>"
          class="w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500">
      </div>
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
        <div>
          <label for="bottle_edit_distillery" class="mb-2 block text-sm font-medium text-gray-700">Distillery</label>
          <input type="text" name="bottle_edit[distillery]" id="bottle_edit_distillery" value="<%= @bottle.distillery %>"
            class="w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500">
        </div>
        <div>
          <label for="bottle_edit_region" class="mb-2 block text-sm font-medium text-gray-700">Region</label>
          <input type="text" name="bottle_edit[region]" id="bottle_edit_region" value="<%= @bottle.region %>"
            class="w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500">
        </div>
        <div>
          <label for="bottle_edit_style" class="mb-2 block text-sm font-medium text-gray-700">Style</label>
          <input type="text" name="bottle_edit[style]" id="bottle_edit_style" value="<%= @bottle.style %>"
            class="w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500">
        </div>
        <div>
          <label for="bottle_edit_abv" class="mb-2 block text-sm font-medium text-gray-700">ABV %</label>
          <input type="number" step="0.1" min="0" max="99" name="bottle_edit[abv]" id="bottle_edit_abv" value="<%= @bottle.abv %>"
            class="w-full rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-whiskey-500">
        </div>
      </div>

      <div class="flex items-center gap-3 pt-2">
        <button type="submit" class="cursor-pointer rounded-xl bg-whiskey-600 px-6 py-3 font-semibold text-white transition hover:bg-whiskey-700">Submit correction</button>
        <%= link_to "Cancel", bottle_path(@bottle), class: "rounded-xl bg-gray-100 px-6 py-3 font-semibold text-gray-700 transition hover:bg-gray-200" %>
      </div>
    <% end %>
  </div>
</section>
```

(Plain `<input>`/`<label>` tags rather than a `form_with model:` — there is
no persisted `@bottle_edit` record backing this form, only a bag of
per-field proposals created on submit, so a model-backed form builder would
misleadingly imply a single-record round trip.)

Add the entry point on `app/views/bottles/show.html.erb`, in the "The
bottle" facts card, right after the closing `</dl>` and before the
`top_descriptors` block:

```erb
          <% if user_signed_in? %>
            <%= link_to "Suggest a correction", new_bottle_edit_path(@bottle), class: "mt-3 inline-block text-xs font-semibold text-whiskey-700 hover:text-whiskey-600" %>
          <% end %>
```

Run `docker compose exec -T web bin/rails test test/controllers/bottles/edits_controller_test.rb` —
expect 9 runs green. Full suite:
`docker compose exec -T web bin/rails test` — expect **367 runs**
(358 + 9), 0 failures, 0 errors, 9 skips.

Commit: `Signed-in users can suggest bottle corrections; auto-applies at the configured threshold`

---

### Task 6: Final green-baseline check, self-review, push

**Files:** none created; verification only.

- [ ] **Step 1 — full suite.**

```
docker compose exec -T web bin/rails test
```

Expect **367 runs, 0 failures, 0 errors, 9 skips** — the running total
carried task-to-task through this plan: 327 baseline + 6 (Task 1: 5
controller + 1 model) + 11 (Task 2) + 7 (Task 3) + 7 (Task 4) + 9 (Task 5)
= 367. If the actual count differs, treat `bin/rails test`'s own printed
total as ground truth and track down which task's tests didn't land as
written before proceeding — do not paper over a mismatch.

- [ ] **Step 2 — self-review checklist (inline, fix findings, then commit).**
- [ ] `Admin::BottlesController#update` and `Bottles::EditsController#create`
      both permit EXACTLY `name, distillery, region, style, abv` — grep for
      `permit` in both files and confirm neither includes `slug` or
      `created_by_id`.
- [ ] `Bottle#generate_slug` is still `on: :create` only (unchanged from
      before this plan) — `grep -n "generate_slug" app/models/bottle.rb`.
- [ ] Every place that reads `BottleEdit::FIELDS` (admin form, public form,
      controller strong params, model validation) lists the same five
      fields in the same order — grep `FIELDS\|permit(:name` across
      `app/models/bottle_edit.rb`, `app/controllers/admin/bottles_controller.rb`,
      `app/controllers/bottles/edits_controller.rb`.
- [ ] `BottleEdits::Normalize.for_storage`/`for_write` are the ONLY places
      that parse `abv` as a number in the corrections flow — the auto-apply
      service and both controllers all route through them (no duplicate
      `BigDecimal(...)` calls scattered elsewhere).
- [ ] The partial unique index name `index_bottle_edits_on_live_proposal`
      matches between the migration and `db/schema.rb`'s dumped block —
      confirm the exact string, not just "an index exists."
- [ ] `db/schema.rb`'s `version:` matches the latest migration timestamp;
      `git status` shows `db/schema.rb` as modified/staged alongside the
      Task 2 migration commit (not a separate or missing commit).
- [ ] No task introduced enrichment columns (`description`, `age_statement`,
      `cask_type`, `cost_tier`) — confirm `db/schema.rb`'s `bottles` table
      block is unchanged by this plan (only `bottle_edits` is new).
- [ ] No moderation queue, notification email, or rate limiter exists
      anywhere in the diff — this plan's scope fence.
- [ ] `docker compose exec -T web bundle exec rubocop app/models/bottle_edit.rb app/services/bottle_edits/auto_apply.rb app/services/bottle_edits/normalize.rb app/controllers/admin/bottles_controller.rb app/controllers/admin/bottles/edits_controller.rb app/controllers/bottles/edits_controller.rb` clean.

Commit: `Bottle corrections phase: final green-baseline check`

- [ ] **Step 3 — push.** Confirm branch first (`git branch --show-current` —
expect `overhaul/full-refresh`, never push to `main`), then
`git push -u origin overhaul/full-refresh`.

---

## Summary of what ships

| Surface | Behavior |
|---|---|
| Admin → Bottles → Edit | Full edit of name/distillery/region/style/abv; slug never changes |
| Bottle page (signed-in) | "Suggest a correction" link → pre-filled form; only changed fields submit |
| `bottle_edits` table | One row per (bottle, user, field) proposal; `status`: pending/applied/rejected; `applied_at`/`applied_by_id` audit the resolution |
| Auto-apply | 3 (configurable) distinct users on the identical value → writes the bottle, applies matching rows, rejects competing pending rows on that field |
| Admin → Bottles → show | Pending proposals grouped by field/value with proposer names and vote counts; Apply / Reject buttons |
| abv normalization | Stored and compared as `"%.1f"` of a parsed `BigDecimal` — "45", "45.0", "45.00" all group identically |

**Explicitly out of scope (per the plan's scope fence):** enrichment
columns (`description`/`age_statement`/`cask_type`/`cost_tier` — not yet in
the schema; a future plan adds them and extends `BottleEdit::FIELDS`
alongside the admin/public forms), moderation queue beyond apply/reject,
notification emails, rate limiting, admin bottle merge/dedup tool.
