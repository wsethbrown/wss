# Review Images — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans to run this task-by-task. `- [ ]` = tracked step.

**Goal:** the image addenda (2026-07-07, owner-approved) at the end of
`docs/superpowers/specs/2026-07-06-review-system-design.md` — the "refined" review-images
addendum supersedes the first's mechanism; the newest addendum adds a creator upload tier:

- A review carries up to 3 attached images; the FIRST is that review's hero.
- `/bottles/<slug>` default image = admin pin > hero of the bottle's TOP-RATED review
  with an image (tie → most `votes_count`, then newest) > creator's `label_image`
  (set on the add-a-bottle form) > SVG placeholder (`bottles/_placeholder`, the floor
  — never blank, no scraped imagery).
- Upload on the review form (new + edit) and the add-a-bottle form: image content
  types only, 15MB cap each, vips downscale on ingest (`image_processing` +
  `ruby-vips` already in Gemfile.lock).
- Admin moderation: delete image / review / both, from the admin panel.
- Ghost-edits corrections (same newest addendum) are OUT of scope — separate future plan.

**Stack:** Rails 8.0.2, Postgres 15, Hotwire, Tailwind v4, Devise, Pundit, Minitest+fixtures, Active Storage (Disk in dev, R2 planned for prod — no service change here).

## Global constraints

- Docker-only: `docker compose exec -T web bin/rails ...` for every migration/test/generator. Never run `bin/rails` on the host.
- **Schema dump rides with the migration commit.** Active Storage attachments need NO migration (attachment/blob/variant tables already exist from Rails' base install). If any task adds a real column, `git add db/schema.rb` in the same commit.
- **True baseline (verified this session, branch `overhaul/full-refresh`, `docker compose exec -T web bin/rails test`): 295 runs, 1101 assertions, 1 failures, 3 errors, 9 skips.** NOT green — pre-existing breakage in `Review.for_circle` (`#or` structural-incompatibility) and `Favorite` (validation regressions) from the prior social-layer phase, outside this plan's scope. No task here may add new failures/errors; the 1F/3E carries forward untouched. Report deltas as "baseline + N new tests, same 1F/3E."
- Design tokens: white/whiskey-50 surfaces, `.eyebrow` kickers, `font-display` headings, `rounded-2xl border border-gray-200 bg-white shadow-sm` public cards, `rounded-lg`/`rounded-xl` admin cards matching `app/views/admin/presentations/_form.html.erb`. Rating: always `bottles/_rating` partial + `number_with_precision(value, precision: 2, strip_insignificant_zeros: true)`.
- `has_many_attached :images` on `Review`, `has_one_attached :pinned_label_image` on `Bottle`.
- Admin house pattern (`Admin::PresentationsController`): `Admin::BaseController` (`authenticate_admin!` + `layout "admin"`), `form.file_field :x, accept:, multiple: true`, content-type/size validated in the model, destructive actions as separate member routes (not folded into `update`).
- Verify libvips before Task 1 Step 2: `docker compose exec -T web bin/rails runner "puts Vips::VERSION"`.

---

### Task 1: Attachments + validations + upload form (new/edit) + review-page gallery

**Files:** modify `app/models/review.rb`, `app/views/reviews/_form.html.erb`, `app/views/reviews/show.html.erb`, `app/controllers/reviews_controller.rb`, `app/controllers/bottles/reviews_controller.rb`, `app/controllers/events/reviews_controller.rb`. Create `test/models/review_images_test.rb`, `test/fixtures/files/sample_review.jpg` (real decodable JPEG — vips needs actual bytes), `test/fixtures/files/sample_review.txt`. **Interfaces:** `Review#images` (`has_many_attached`), `Review#hero_image` → first image or nil, `Review::MAX_IMAGES = 3`, `Review::MAX_IMAGE_SIZE = 15.megabytes`, `Review::ALLOWED_IMAGE_TYPES`.

- [ ] **Step 1 — failing model test.** Create `test/fixtures/files/sample_review.jpg` (tiny real decodable JPEG — vips needs actual bytes) and `test/fixtures/files/sample_review.txt` (`echo "not an image" > test/fixtures/files/sample_review.txt`).

```ruby
# test/models/review_images_test.rb
require "test_helper"

class ReviewImagesTest < ActiveSupport::TestCase
  setup { @review = reviews(:eagle_review) }

  def attach(name, content_type: "image/jpeg", fixture: "sample_review.jpg")
    @review.images.attach(io: File.open(file_fixture(fixture)), filename: name, content_type: content_type)
  end

  test "a review accepts up to 3 images" do
    3.times { |i| attach("pic#{i}.jpg") }
    assert @review.valid?
    assert_equal 3, @review.images.count
  end

  test "a 4th image is invalid" do
    4.times { |i| attach("pic#{i}.jpg") }
    assert_not @review.valid?
    assert_includes @review.errors[:images], "can have at most 3 photos"
  end

  test "a non-image content type is rejected" do
    attach("notes.txt", content_type: "text/plain", fixture: "sample_review.txt")
    assert_not @review.valid?
    assert_includes @review.errors[:images], "must be an image (JPEG, PNG, GIF, or WEBP)"
  end

  test "an oversized image is rejected" do
    attach("big.jpg")
    @review.images.last.blob.update!(byte_size: 16.megabytes)
    assert_not @review.valid?
    assert_includes @review.errors[:images], "each photo must be 15MB or smaller"
  end

  test "hero_image is the first attached image" do
    attach("first.jpg")
    attach("second.jpg")
    assert_equal "first.jpg", @review.hero_image.filename.to_s
  end

  test "hero_image is nil with no images" do
    assert_nil @review.hero_image
  end
end
```

Run `docker compose exec -T web bin/rails test test/models/review_images_test.rb` — fails (no `images` association, no `hero_image`).

- [ ] **Step 2 — model.** Confirm attachment tables already exist (no migration):

```
docker compose exec -T web bin/rails runner "puts ActiveRecord::Base.connection.table_exists?('active_storage_attachments')"
```

Edit `app/models/review.rb` — add after `has_many :review_votes`:

```ruby
  MAX_IMAGES = 3
  MAX_IMAGE_SIZE = 15.megabytes
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/jpg image/png image/gif image/webp].freeze

  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_fill: [400, 400], saver: { quality: 80 }
  end

  validate :images_are_valid
```

Add near the bottom, in the public section (before `private`):

```ruby
  # First upload wins — shown on the review page and feeds Bottle#display_image.
  def hero_image
    images.attached? ? images.first : nil
  end
```

Add to `private`:

```ruby
  def images_are_valid
    return unless images.attached?

    errors.add(:images, "can have at most #{MAX_IMAGES} photos") if images.size > MAX_IMAGES
    images.each do |image|
      errors.add(:images, "must be an image (JPEG, PNG, GIF, or WEBP)") unless image.content_type.in?(ALLOWED_IMAGE_TYPES)
      errors.add(:images, "each photo must be #{MAX_IMAGE_SIZE / 1.megabyte}MB or smaller") if image.byte_size > MAX_IMAGE_SIZE
    end
  end
```

Run `docker compose exec -T web bin/rails test test/models/review_images_test.rb` — 6 runs green. Then full suite:

```
docker compose exec -T web bin/rails test
```

Expect **301 runs** (295 + 6), same 1 failure/3 errors, 9 skips.

Commit: `Review images: has_many_attached with count/type/size validation`

- [ ] **Step 3 — permit `images` in every review-creating/updating controller.** `app/controllers/reviews_controller.rb`, `app/controllers/bottles/reviews_controller.rb`, `app/controllers/events/reviews_controller.rb` — same one-line change in each `review_params`:

```ruby
    params.require(:review).permit(:rating, :notes, :nose, :palate, :finish, :body_notes, :price_paid,
      flavor_wheel: Review::DESCRIPTOR_LEXICON.keys, images: [])
```

`ReviewsController#update` needs an explicit append (Active Storage's `permit images: []` doesn't attach on its own via `update` for `has_many_attached` in a way that ADDS — uploading on edit should add to, not replace, the existing set, up to the cap):

```ruby
  def update
    @review.images.attach(review_params[:images]) if review_params[:images].present?
    if @review.update(review_params.except(:images))
      redirect_to review_path(@review), notice: "Review updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end
```

- [ ] **Step 4 — controller test for upload wiring.** Create `test/controllers/reviews_controller_images_test.rb`:

```ruby
require "test_helper"

class ReviewsControllerImagesTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:john) }

  test "editing a review can add photos up to the cap" do
    review = reviews(:eagle_review)
    patch review_path(review), params: { review: { images: [fixture_file_upload("sample_review.jpg", "image/jpeg")] } }
    assert_redirected_to review_path(review)
    assert_equal 1, review.reload.images.count
  end

  test "a non-image upload on edit re-renders with an error" do
    review = reviews(:eagle_review)
    patch review_path(review), params: { review: { images: [fixture_file_upload("sample_review.txt", "text/plain")] } }
    assert_response :unprocessable_entity
    assert_equal 0, review.reload.images.count
  end
end
```

Run, expect green (uses Step 3's wiring). If `sign_in` helper differs from the project's Devise test helper, match whatever `test/controllers/reviews_controller_test.rb` already uses instead of guessing.

Run full suite — expect **303 runs** (301 + 2), same 1F/3E baseline carried.

Commit: `Permit review image uploads on create and edit (bottle, event, and edit forms)`

- [ ] **Step 5 — form + review-page gallery (view-only).** `app/views/reviews/_form.html.erb` — before the submit row, add a "Photos (optional, up to 3 — the first becomes this tasting's cover photo)" block: if `review.persisted? && review.images.attached?`, show existing thumbs (`image_tag image.variant(:thumb), class: "h-20 w-20 rounded-lg object-cover ring-1 ring-gray-200"`) in a `flex flex-wrap gap-3` row; below it `form.file_field :images, multiple: true, accept: "image/jpeg,image/jpg,image/png,image/gif,image/webp"` styled like the existing text inputs (`rounded-lg border border-gray-300`).

`app/views/reviews/show.html.erb` — after the tasting-fields block and before `<%= render "reviews/event_card" %>`, add (only `if @review.images.attached?`) a "Photos" `.eyebrow` section: `grid grid-cols-2 gap-3 sm:grid-cols-3` of `image_tag image.variant(:thumb), class: "aspect-square w-full rounded-xl object-cover ring-1 ring-gray-200"` per image.

Run full suite (view-only change, sanity check nothing broke): expect **303 runs**, same 1F/3E baseline.

Commit: `Review form uploads photos; review page renders the gallery`

---

### Task 2: `Bottle#display_image` derived rule + creator upload + identity band + row thumbnails

**Files:** modify `app/models/bottle.rb`, `app/controllers/bottles_controller.rb`, `app/views/bottles/new.html.erb`, `app/views/bottles/show.html.erb`, `app/views/reviews/index.html.erb`. Create `test/models/bottle_display_image_test.rb`. **Interfaces:** `has_one_attached :pinned_label_image`/`:label_image` on `Bottle`. `Bottle#display_image` → pin, else top-rated review-with-image's hero (tie → most `votes_count`, then newest), else `label_image`, else `nil`. `BottlesController#create` permits `:label_image`.

- [ ] **Step 1 — failing model test.**

```ruby
# test/models/bottle_display_image_test.rb
require "test_helper"

class BottleDisplayImageTest < ActiveSupport::TestCase
  def attach_to(record, name)
    record.images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: name, content_type: "image/jpeg")
  end

  test "display_image is nil when no review has a photo" do
    assert_nil bottles(:lagavulin).display_image
  end

  test "display_image is the hero of the top-rated review with a photo" do
    bottle = bottles(:eagle_rare)
    attach_to(reviews(:eagle_review), "hi.jpg") # rating 4.0 per CLAUDE.md fixture note
    assert_equal "hi.jpg", bottle.reload.display_image.filename.to_s
  end

  test "tie in rating breaks to most votes_count, then newest" do
    bottle = bottles(:ardbeg_10)
    low_votes, high_votes = reviews(:ardbeg_jane), reviews(:ardbeg_mike) # same rating — adjust fixtures to tie if not already
    attach_to(low_votes, "low.jpg")
    attach_to(high_votes, "high.jpg")
    low_votes.update_columns(votes_count: 1)
    high_votes.update_columns(votes_count: 5)
    assert_equal "high.jpg", bottle.reload.display_image.filename.to_s
  end

  test "admin pin overrides the derived image" do
    bottle = bottles(:eagle_rare)
    attach_to(reviews(:eagle_review), "derived.jpg")
    bottle.pinned_label_image.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "pinned.jpg", content_type: "image/jpeg")
    assert_equal "pinned.jpg", bottle.reload.display_image.filename.to_s
  end

  test "creator's label_image is used with no review photo and no pin" do
    bottle = bottles(:lagavulin)
    bottle.label_image.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "label.jpg", content_type: "image/jpeg")
    assert_equal "label.jpg", bottle.reload.display_image.filename.to_s
  end

  test "a top-rated review photo beats the creator's label_image" do
    bottle = bottles(:eagle_rare)
    bottle.label_image.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "label.jpg", content_type: "image/jpeg")
    attach_to(reviews(:eagle_review), "review.jpg")
    assert_equal "review.jpg", bottle.reload.display_image.filename.to_s
  end
end
```

Check `test/fixtures/reviews.yml`/`bottles.yml` for real fixture names/ratings first — use existing bottles with 2+ reviews at equal rating and distinct votes, or add two rows at equal rating with `votes_count:` set directly (match however the project already seeds counter-cache columns in fixtures).

Run `docker compose exec -T web bin/rails test test/models/bottle_display_image_test.rb` — fails (no `display_image`, no `pinned_label_image`).

- [ ] **Step 2 — model.** `app/models/bottle.rb` — add near the top:

```ruby
  has_one_attached :pinned_label_image
  has_one_attached :label_image
```

Add a public method (near `average_rating`):

```ruby
  # /bottles/<slug> image: pin > top-rated review hero (ties: votes, newest)
  # > creator's label_image > nil (view falls back to the SVG placeholder).
  def display_image
    return pinned_label_image if pinned_label_image.attached?

    candidate = reviews.joins(:images_attachments)
                        .distinct
                        .order(rating: :desc, votes_count: :desc, created_at: :desc)
                        .first
    return candidate.hero_image if candidate

    label_image.attached? ? label_image : nil
  end
```

Run model test — green (8 runs). Full suite — expect **311 runs** (303 + 8), same 1F/3E baseline.

Commit: `Bottle#display_image: pin > top-rated review photo > creator label_image > nil`

- [ ] **Step 3 — creator upload on "Add a bottle".** `app/controllers/bottles_controller.rb` — add `:label_image` to `bottle_params`:

```ruby
    params.require(:bottle).permit(:name, :distillery, :region, :style, :abv, :label_image)
```

`app/views/bottles/new.html.erb` — before the submit row, add a `form.label :label_image, "A photo of the bottle (optional)"` + `form.file_field :label_image, accept: "image/jpeg,image/jpg,image/png,image/gif,image/webp"`, styled like the existing fields on that form.

Add a failing/passing controller test to `test/controllers/bottles_controller_test.rb` (check the file first — add alongside existing `create` tests, don't invent a new file):

```ruby
  test "creating a bottle with a label image attaches it" do
    sign_in users(:john)
    post bottles_path, params: { bottle: { name: "Redbreast 12", label_image: fixture_file_upload("sample_review.jpg", "image/jpeg") } }
    assert Bottle.find_by!(name: "Redbreast 12").label_image.attached?
  end
```

Run `docker compose exec -T web bin/rails test test/controllers/bottles_controller_test.rb test/models/bottle_display_image_test.rb` — green. Full suite: expect **312 runs** (311 + 1), same 1F/3E baseline.

Commit: `Add-a-bottle form uploads the creator's label_image`

- [ ] **Step 4 — identity band + review-page cover + row thumbnails (view-only).** `app/views/bottles/show.html.erb` — in the identity band, replace the unconditional `render "bottles/placeholder"` with: `image_tag @bottle.display_image.variant(:thumb), class: "h-14 w-14 rounded-lg object-cover"` when `@bottle.display_image` is present, else the existing placeholder render unchanged. Same conditional swap in `app/views/reviews/show.html.erb`'s hero block (`@review.bottle`, `h-14`).

`app/views/reviews/index.html.erb` — bottle row loop: wrap the existing `<div class="min-w-0">` in a new `flex items-center gap-3` div, and before it add the same conditional (`display_image` present → `image_tag img.variant(:thumb), class: "h-10 w-10 shrink-0 rounded-lg object-cover"`, else placeholder at `size: "h-10"`). Close the added wrapper right before the existing `shrink-0 whitespace-nowrap text-right` block. One query per row at the 10-row page size is acceptable; do not eager-load further without a real N+1 complaint. This is additive markup around existing content — check indentation against the live file, not a rewrite.

Run full suite (view-only): expect **312 runs**, same 1F/3E baseline. Spot-check: `docker compose exec -T web bin/rails runner "puts Bottle.first.display_image.inspect"`; load `/reviews` and a bottle page in browser if available.

Commit: `Bottle identity band, review hero, and review-row thumbnails use the derived image`

---

### Task 3: Admin moderation surface (delete image / review / both)

**Files:** create `app/controllers/admin/bottles_controller.rb`, `app/controllers/admin/bottles/reviews_controller.rb`, `app/views/admin/bottles/index.html.erb`, `app/views/admin/bottles/show.html.erb`, `test/controllers/admin/bottles_controller_test.rb`. Modify `config/routes.rb`, `app/views/layouts/admin.html.erb`. **Interfaces:** `Admin::BottlesController#index/#show/#pin_image/#unpin_image`; `Admin::Bottles::ReviewsController#destroy` (deletes review, images cascade) `#destroy_image` (purges images, review survives).

- [ ] **Step 1 — failing controller test.**

```ruby
# test/controllers/admin/bottles_controller_test.rb
require "test_helper"

class Admin::BottlesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) } # substitute the real is_admin: true fixture name

  def image_upload = fixture_file_upload("sample_review.jpg", "image/jpeg")

  test "index lists bottles" do
    get admin_bottles_path
    assert_response :success
    assert_select "body", /#{bottles(:eagle_rare).name}/
  end

  test "show renders reviews with a pin form" do
    get admin_bottle_path(bottles(:eagle_rare))
    assert_response :success
  end

  test "admin can pin a label image" do
    bottle = bottles(:eagle_rare)
    patch pin_image_admin_bottle_path(bottle), params: { bottle: { pinned_label_image: image_upload } }
    assert_redirected_to admin_bottle_path(bottle)
    assert bottle.reload.pinned_label_image.attached?
  end

  test "admin can unpin" do
    bottle = bottles(:eagle_rare)
    bottle.pinned_label_image.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "p.jpg", content_type: "image/jpeg")
    delete unpin_image_admin_bottle_path(bottle)
    assert_not bottle.reload.pinned_label_image.attached?
  end

  test "admin can delete a review's images without deleting the review" do
    review = reviews(:eagle_review)
    review.images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "x.jpg", content_type: "image/jpeg")
    delete destroy_image_admin_bottle_review_path(review.bottle, review)
    assert_redirected_to admin_bottle_path(review.bottle)
    assert_not review.reload.images.attached?
  end

  test "admin can delete a review outright" do
    review = reviews(:eagle_review)
    assert_difference "Review.count", -1 do
      delete admin_bottle_review_path(review.bottle, review)
    end
  end

  test "non-admin gets redirected" do
    sign_out users(:admin)
    sign_in users(:john)
    get admin_bottles_path
    assert_redirected_to root_path
  end
end
```

Confirm the `is_admin: true` fixture name in `test/fixtures/users.yml` before using `users(:admin)`.

Run `docker compose exec -T web bin/rails test test/controllers/admin/bottles_controller_test.rb` — fails (no routes, no controller).

- [ ] **Step 2 — routes.** Edit `config/routes.rb` inside `namespace :admin do ... end`, after the `presentations` block:

```ruby
    resources :bottles, only: [:index, :show] do
      member do
        patch :pin_image
        delete :unpin_image
      end
      resources :reviews, only: [], module: :bottles do
        member do
          delete :destroy
          delete :destroy_image
        end
      end
    end
```

- [ ] **Step 3 — controller.**

```ruby
# app/controllers/admin/bottles_controller.rb
# Pin/unpin the label image. Delete flows live in Bottles::ReviewsController.
class Admin::BottlesController < Admin::BaseController
  before_action :set_bottle, except: [:index]

  def index
    @bottles = Bottle.with_score.order(:name)
  end

  def show
    @reviews = @bottle.reviews.includes(:user, images_attachments: :blob).order(created_at: :desc)
  end

  def pin_image
    @bottle.pinned_label_image.attach(bottle_params[:pinned_label_image])
    redirect_to admin_bottle_path(@bottle), notice: "Label image pinned."
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
end
```

```ruby
# app/controllers/admin/bottles/reviews_controller.rb
# Admin-only moderation, no ownership check (distinct from ReviewsController).
class Admin::Bottles::ReviewsController < Admin::BaseController
  before_action :set_review

  def destroy
    bottle = @review.bottle
    @review.destroy!
    redirect_to admin_bottle_path(bottle), notice: "Review deleted."
  end

  def destroy_image
    @review.images.purge
    redirect_to admin_bottle_path(@review.bottle), notice: "Review photos removed."
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end
end
```

(`module: :bottles` inside `namespace :admin` resolves to `Admin::Bottles::ReviewsController` — standard Rails nesting.)

- [ ] **Step 4 — views.** `app/views/admin/bottles/index.html.erb` — row list matching `app/views/admin/presentations/index.html.erb` (`divide-y divide-gray-100 rounded-2xl border border-gray-200 bg-white shadow-sm`), each row `link_to admin_bottle_path(bottle)` with `bottle.name`, `pluralize(bottle.reviews.count, "review")`, and a "Pinned" badge (`rounded-full bg-whiskey-100 px-2.5 py-0.5 text-xs font-medium text-whiskey-800`) when `bottle.pinned_label_image.attached?`.

`app/views/admin/bottles/show.html.erb`: (1) header — `@bottle.name` + link to `bottle_path(@bottle)`; (2) label-image card (`rounded-2xl border border-gray-200 bg-white p-6 shadow-sm`) — pin thumbnail + `button_to "Unpin", unpin_image_admin_bottle_path(@bottle), method: :delete` when attached, else a note that the derived/placeholder is showing, plus `form_with url: pin_image_admin_bottle_path(@bottle), method: :patch` with `f.file_field "bottle[pinned_label_image]", accept: "image/jpeg,image/jpg,image/png,image/gif,image/webp"` and submit "Pin this image"; (3) reviews list (`divide-y`, same card class) — image thumbs, reviewer name + rating + date, `button_to "Remove photos", destroy_image_admin_bottle_review_path(@bottle, review), method: :delete` (only if images attached) and `button_to "Delete review", admin_bottle_review_path(@bottle, review), method: :delete, data: { turbo_confirm: "Delete this review?" }` (`bg-red-50 text-red-700 hover:bg-red-100`). Match `admin/presentations/show.html.erb`'s exact classes when in doubt.

`app/views/layouts/admin.html.erb` — nav entry after `"Decks"`:

```ruby
            "Bottles"       => [admin_bottles_path,             'M9 3v2m6-2v2M5 7h14M5 7l1 12a2 2 0 002 2h8a2 2 0 002-2l1-12M5 7h14'],
```

Run `docker compose exec -T web bin/rails test test/controllers/admin/bottles_controller_test.rb` — 7 runs green. Full suite: expect **319 runs** (312 + 7), same 1F/3E baseline.

Commit: `Admin bottle moderation: pin/unpin label image, delete review photos or the review`

---

### Task 4: Seeds check + final green-baseline verification + push

**Files:** `db/seeds.rb` (check only; no licensed whiskey photos exist to seed with, so leave seeded reviews/bottles image-free — intentional, placeholder/derived-nil path is the correct state, not a gap). No status-doc file exists in `docs/superpowers/` to update; do not invent one — the spec's addenda are the record.

- [ ] **Step 1 — final full-suite run.**

```
docker compose exec -T web bin/rails test
```

Expect **319 runs, ~1170+ assertions, same 1 failures, 3 errors, 9 skips**. Any NEW failure is this plan's regression — fix before proceeding, do not carry it forward as "pre-existing."

- [ ] **Step 2 — self-review checklist (inline, fix findings, then commit).**
- [ ] Every `review_params` in `ReviewsController`, `Bottles::ReviewsController`, `Events::ReviewsController` includes `images: []`.
- [ ] `Bottle#display_image` order matches both addenda verbatim: pin > top-rated review hero (ties: votes then newest) > creator `label_image` > nil.
- [ ] Placeholder still renders whenever `display_image` is nil in all three surfaces (identity band, review hero, row thumbnail) — grep for a stray `if @bottle.display_image` missing its `else`.
- [ ] Deleting a Review cascades its attached images (Active Storage default behavior, no extra code required — confirm, don't assume).
- [ ] No new column added without a migration + `db/schema.rb` in the same commit (this plan adds none — attachments only).
- [ ] `docker compose exec -T web bundle exec rubocop app/models/review.rb app/models/bottle.rb app/controllers/admin/bottles_controller.rb app/controllers/admin/bottles/reviews_controller.rb` clean.

Commit: `Review images phase: final green-baseline check`

- [ ] **Step 3 — push.** Confirm branch first (`git branch --show-current` — expect `overhaul/full-refresh`, never push to `main`), then `git push -u origin overhaul/full-refresh`.

---

## Summary of what ships

| Surface | Behavior |
|---|---|
| Review form (new/edit) | Up to 3 image uploads, 15MB/type-validated, additive on edit |
| Review page | Photo gallery grid when present |
| Add-a-bottle form | Optional creator `label_image` upload |
| Bottle identity band | `display_image` (pin > top-rated-review hero > creator label_image > nil) or placeholder |
| Reviews index rows | Small thumbnail per bottle, same derivation |
| Admin → Bottles | List, per-bottle pin/unpin, per-review delete-photos or delete-review |

**Explicitly out of scope:** ghost-edits correction system (bottle_edits table, N-proposal auto-apply), admin full-field bottle edit form — both from the same newest addendum, deferred to a separate future plan.
