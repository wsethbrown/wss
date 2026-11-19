require "test_helper"

# B1 (S17): purging review photos is a hard delete, so only full admins.
class Admin::Bottles::ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @review = reviews(:john_eagle_rare)
    @bottle = @review.bottle
    @review.images.attach(io: StringIO.new("fakepng"), filename: "pour.png", content_type: "image/png")
  end

  test "a limited admin cannot purge a review's photos" do
    sign_in users(:limited_admin)
    delete destroy_image_admin_bottle_review_path(@bottle, @review)
    assert @review.reload.images.attached?, "photos were purged by a limited admin"
  end

  test "a full admin can purge a review's photos" do
    sign_in users(:admin)
    delete destroy_image_admin_bottle_review_path(@bottle, @review)
    assert_redirected_to admin_bottle_path(@bottle)
    assert_equal "Review photos removed.", flash[:notice]
  end
end
