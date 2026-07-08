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
    attach_to(reviews(:john_eagle_rare), "hi.jpg") # rating 4.0 per CLAUDE.md fixture note
    assert_equal "hi.jpg", bottle.reload.display_image.filename.to_s
  end

  test "tie in rating breaks to most votes_count, then newest" do
    bottle = bottles(:ardbeg_10)
    low_votes, high_votes = reviews(:seth_ardbeg_solo_low), reviews(:one_ardbeg_solo_high) # same rating — adjust fixtures to tie if not already
    attach_to(low_votes, "low.jpg")
    attach_to(high_votes, "high.jpg")
    assert_equal "high.jpg", bottle.reload.display_image.filename.to_s
  end

  test "admin pin overrides the derived image" do
    bottle = bottles(:eagle_rare)
    attach_to(reviews(:john_eagle_rare), "derived.jpg")
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
    attach_to(reviews(:john_eagle_rare), "review.jpg")
    assert_equal "review.jpg", bottle.reload.display_image.filename.to_s
  end

  test "label_image :thumb variant actually transforms" do
    bottle = bottles(:lagavulin)
    bottle.label_image.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "label.jpg", content_type: "image/jpeg")
    # .processed forces the real vips transform — a lazy variant wrapper is
    # never nil, so anything less asserts nothing.
    processed = bottle.label_image.variant(:thumb).processed
    assert processed.image.blob.byte_size.positive?
  end

  test "display_image= memoizes so the reader returns the assigned value without querying" do
    bottle = bottles(:lagavulin)
    bottle.display_image = nil
    assert_no_queries { assert_nil bottle.display_image }

    bottle2 = bottles(:eagle_rare)
    attach_to(reviews(:john_eagle_rare), "assigned.jpg")
    review = Review.includes(images_attachments: :blob).find(reviews(:john_eagle_rare).id)
    image = review.hero_image
    bottle2.display_image = image
    assert_no_queries { assert_equal "assigned.jpg", bottle2.display_image.filename.to_s }
  end

  test "preload_display_images assigns the same answers display_image computes lazily" do
    pinned = Bottle.create!(name: "Pinned Pick", distillery: "Test Distillery")
    pinned.pinned_label_image.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "pinned.jpg", content_type: "image/jpeg")

    hero_bottle = Bottle.create!(name: "Hero Pick", distillery: "Test Distillery")
    reviewer1 = users(:john)
    reviewer2 = users(:jane)
    low_review = Review.create!(user: reviewer1, bottle: hero_bottle, rating: 3.0, notes: "Lower rated.")
    high_review = Review.create!(user: reviewer2, bottle: hero_bottle, rating: 4.5, notes: "Higher rated.")
    attach_to(low_review, "low_first.jpg")
    attach_to(high_review, "high_first.jpg")
    attach_to(high_review, "high_second.jpg")

    bare_bottle = Bottle.create!(name: "Bare Bottle", distillery: "Test Distillery")

    collection = Bottle.where(id: [ pinned.id, hero_bottle.id, bare_bottle.id ])
                        .with_attached_pinned_label_image.with_attached_label_image
                        .index_by(&:id)
    ordered = [ pinned.id, hero_bottle.id, bare_bottle.id ].map { |id| collection.fetch(id) }

    Bottle.preload_display_images(ordered)

    assert_equal "pinned.jpg", ordered[0].display_image.filename.to_s
    # Higher-rated review wins the candidate slot; its FIRST image is the hero.
    assert_equal "high_first.jpg", ordered[1].display_image.filename.to_s
    assert_nil ordered[2].display_image

    # Cross-check against the lazy instance-method computation (fresh objects).
    assert_equal Bottle.find(pinned.id).display_image.filename.to_s, ordered[0].display_image.filename.to_s
    assert_equal Bottle.find(hero_bottle.id).display_image.filename.to_s, ordered[1].display_image.filename.to_s
    assert_nil Bottle.find(bare_bottle.id).display_image
  end
end
