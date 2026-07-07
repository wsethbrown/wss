require "test_helper"

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  test "signed-out index has no circle sidebar data" do
    get reviews_path
    assert_nil assigns(:circle_reviews)
  end

  test "signed-in index builds the circle feed from favorited users and societies" do
    jane = users(:jane)
    # jane already favorites single_malt (Society) via fixture
    # Add a favorite for john (User)
    Favorite.create!(user: jane, favoritable: users(:john))

    sign_in jane
    get reviews_path
    assert_response :success
    assert_includes assigns(:circle_reviews), reviews(:john_eagle_rare)
    assert_includes assigns(:circle_reviews), reviews(:john_spring_ardbeg) # tied to single_malt's spring_blind
  end

  test "circle feed excludes reviews outside the favorited set" do
    sign_in users(:john) # favorites nobody
    get reviews_path
    assert_response :success
    assert_empty assigns(:circle_reviews)
  end

  test "?feed=circle renders the full circle feed" do
    jane = users(:jane)
    # jane already favorites single_malt (Society) via fixture
    # Add a favorite for john (User)
    Favorite.create!(user: jane, favoritable: users(:john))

    sign_in jane
    get reviews_path(feed: "circle")
    assert_response :success
    assert_select "h2", text: /circle/i
  end
end
