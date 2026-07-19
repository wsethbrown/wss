require "test_helper"

class ReviewsControllerImagesTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:john) }

  test "editing a review can add photos up to the cap" do
    review = reviews(:john_eagle_rare)
    patch review_path(review), params: { review: { images: [ fixture_file_upload("sample_review.jpg", "image/jpeg") ] } }
    assert_redirected_to review_path(review)
    assert_equal 1, review.reload.images.count
  end

  test "a non-image upload on edit re-renders with an error" do
    review = reviews(:john_eagle_rare)
    patch review_path(review), params: { review: { images: [ fixture_file_upload("sample_review.txt", "text/plain") ] } }
    assert_response :unprocessable_entity
    assert_equal 0, review.reload.images.count
  end
end
