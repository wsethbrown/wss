require "test_helper"

class ReviewImagesTest < ActiveSupport::TestCase
  setup { @review = reviews(:john_eagle_rare) }

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
