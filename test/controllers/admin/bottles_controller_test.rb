require "test_helper"

class Admin::BottlesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) }

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

  test "admin gets alert when no image chosen for pin" do
    bottle = bottles(:eagle_rare)
    patch pin_image_admin_bottle_path(bottle), params: { bottle: { pinned_label_image: nil } }
    assert_redirected_to admin_bottle_path(bottle)
    assert_equal "Choose an image to pin.", flash[:alert]
  end

  test "admin can unpin" do
    bottle = bottles(:eagle_rare)
    bottle.pinned_label_image.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "p.jpg", content_type: "image/jpeg")
    delete unpin_image_admin_bottle_path(bottle)
    assert_not bottle.reload.pinned_label_image.attached?
  end

  test "admin can delete a review's images without deleting the review" do
    review = reviews(:john_eagle_rare)
    review.images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "x.jpg", content_type: "image/jpeg")
    delete destroy_image_admin_bottle_review_path(review.bottle, review)
    assert_redirected_to admin_bottle_path(review.bottle)
    assert_not review.reload.images.attached?
  end

  test "admin can delete a review outright" do
    review = reviews(:john_eagle_rare)
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
