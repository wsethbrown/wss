require "test_helper"

class BottleImagesTest < ActiveSupport::TestCase
  setup { @bottle = bottles(:lagavulin) }

  def attach(attribute, name, content_type: "image/jpeg", fixture: "sample_review.jpg")
    @bottle.public_send(attribute).attach(io: File.open(file_fixture(fixture)), filename: name, content_type: content_type)
  end

  test "label_image accepts a valid jpg" do
    attach(:label_image, "label.jpg")
    assert @bottle.valid?
  end

  test "label_image rejects a non-image content type" do
    attach(:label_image, "notes.txt", content_type: "text/plain", fixture: "sample_review.txt")
    assert_not @bottle.valid?
    assert_includes @bottle.errors[:label_image], "must be an image (JPEG, PNG, GIF, or WEBP)"
  end

  test "label_image rejects an oversized image" do
    attach(:label_image, "big.jpg")
    @bottle.label_image.blob.update!(byte_size: 16.megabytes)
    assert_not @bottle.valid?
    assert_includes @bottle.errors[:label_image], "must be 15MB or smaller"
  end

  test "pinned_label_image accepts a valid jpg" do
    attach(:pinned_label_image, "pin.jpg")
    assert @bottle.valid?
  end

  test "pinned_label_image rejects a non-image content type" do
    attach(:pinned_label_image, "notes.txt", content_type: "text/plain", fixture: "sample_review.txt")
    assert_not @bottle.valid?
    assert_includes @bottle.errors[:pinned_label_image], "must be an image (JPEG, PNG, GIF, or WEBP)"
  end

  test "pinned_label_image rejects an oversized image" do
    attach(:pinned_label_image, "big.jpg")
    @bottle.pinned_label_image.blob.update!(byte_size: 16.megabytes)
    assert_not @bottle.valid?
    assert_includes @bottle.errors[:pinned_label_image], "must be 15MB or smaller"
  end
end
