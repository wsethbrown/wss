require "test_helper"

class Admin::BottlesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

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
    perform_enqueued_jobs do
      delete unpin_image_admin_bottle_path(bottle)
    end
    assert_not bottle.reload.pinned_label_image.attached?
  end

  test "admin can delete a review's images without deleting the review" do
    review = reviews(:john_eagle_rare)
    review.images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "x.jpg", content_type: "image/jpeg")
    perform_enqueued_jobs do
      delete destroy_image_admin_bottle_review_path(review.bottle, review)
    end
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

  test "non-admin cannot pin, unpin, or delete" do
    sign_out users(:admin)
    sign_in users(:john)
    review = reviews(:john_eagle_rare)
    bottle = review.bottle
    review.images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "x.jpg", content_type: "image/jpeg")

    assert_no_difference "Review.count" do
      patch pin_image_admin_bottle_path(bottle), params: { bottle: { pinned_label_image: image_upload } }
      assert_redirected_to root_path
      delete unpin_image_admin_bottle_path(bottle)
      assert_redirected_to root_path
      delete destroy_image_admin_bottle_review_path(bottle, review)
      assert_redirected_to root_path
      delete admin_bottle_review_path(bottle, review)
      assert_redirected_to root_path
    end
    assert_not bottle.reload.pinned_label_image.attached?
    assert review.reload.images.attached?
  end

  test "a review addressed under the wrong bottle's URL is not found" do
    other_bottle = bottles(:lagavulin)
    review = reviews(:john_eagle_rare)
    assert_not_equal other_bottle, review.bottle

    assert_no_difference "Review.count" do
      delete admin_bottle_review_path(other_bottle, review)
      assert_response :not_found
    end
  end

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
end
