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

  test "?feed=hot renders hot tastings ranked by recent votes" do
    get reviews_path(feed: "hot")
    assert_response :success
    assert_select "h2", text: /hot/i
  end

  test "feed pills appear near the tastings heading" do
    get reviews_path
    assert_select "a", text: "Latest"
    assert_select "a", text: "Hot"
  end

  test "index preloads display images so bottle rows issue no extra per-bottle queries" do
    # Give every existing bottle a photo path so display_image actually has
    # work to do: attach a review image to each bottle's first review, or a
    # label_image where there's no review at all.
    Bottle.find_each do |bottle|
      review = bottle.reviews.first
      if review
        review.images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "hero.jpg", content_type: "image/jpeg")
      else
        bottle.label_image.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "label.jpg", content_type: "image/jpeg")
      end
    end

    query_count = count_sql_queries { get reviews_path }
    assert_response :success
    # Generous fixed bound: fixture catalog is a handful of bottles, so a
    # real N+1 (2-3 queries/row) would blow well past this; a properly
    # batched preload stays flat regardless of row count.
    assert_operator query_count, :<, 40, "expected a bounded query count from batched display-image preloading, got #{query_count}"
  end

  test "bottle list paginates with a separate bottle_page param" do
    26.times { |n| Bottle.create!(name: "Pagination Test Bottle #{n}", distillery: "Test Distillery") }

    get reviews_path
    assert_response :success
    assert_select ".pagination", true

    get reviews_path(bottle_page: 2)
    assert_response :success
  end
end
