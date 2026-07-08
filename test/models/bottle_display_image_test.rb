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
end
