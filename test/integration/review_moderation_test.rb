require "test_helper"

# Post-moderation for review content: anyone signed in can flag a review, the
# content stays public, and admins act from the moderation queue.
class ReviewModerationTest < ActionDispatch::IntegrationTest
  def setup
    @review = reviews(:eagle_rare_john) rescue nil
    @review ||= Review.where.not(user_id: users(:jane).id).first
    @review ||= Review.create!(user: users(:john), bottle: bottles(:eagle_rare), rating: 4.0, notes: "solid pour")
  end

  # ---- reporting ----------------------------------------------------------
  test "a signed-in member can report someone else's review" do
    sign_in users(:jane)
    assert_difference("ReviewReport.count", 1) do
      post review_report_path(@review)
    end
    assert_redirected_to review_path(@review)
    assert_equal "open", ReviewReport.last.status
  end

  test "reporting twice is a no-op, not an error" do
    sign_in users(:jane)
    post review_report_path(@review)
    assert_no_difference("ReviewReport.count") do
      post review_report_path(@review)
    end
    assert_redirected_to review_path(@review)
  end

  test "you cannot report your own review" do
    sign_in users(:john)
    own = Review.where(user: users(:john)).first || @review
    assert_no_difference("ReviewReport.count") do
      post review_report_path(own)
    end
  end

  test "signed-out visitors cannot report" do
    assert_no_difference("ReviewReport.count") do
      post review_report_path(@review)
    end
  end

  test "a reported review stays public (post-moderation)" do
    sign_in users(:jane)
    post review_report_path(@review)
    sign_out users(:jane) if respond_to?(:sign_out)

    get review_path(@review)
    assert_response :success
  end

  test "the report button shows on someone else's review and flips after reporting" do
    sign_in users(:jane)
    get review_path(@review)
    assert_match(/Report/, @response.body)

    post review_report_path(@review)
    get review_path(@review)
    assert_match(/Flagged for review/, @response.body)
  end

  # ---- admin queue --------------------------------------------------------
  test "the moderation queue lists open reports and pending bottle edits" do
    ReviewReport.create!(review: @review, user: users(:jane))
    sign_in users(:admin)

    get admin_moderation_path
    assert_response :success
    assert_match(/Flagged reviews/, @response.body)
    assert_match(/Proposed bottle corrections/, @response.body)
    assert_match(@review.bottle.name, @response.body)
  end

  test "dismissing closes every open report on that review" do
    r1 = ReviewReport.create!(review: @review, user: users(:jane))
    ReviewReport.create!(review: @review, user: users(:seth))
    sign_in users(:admin)

    post dismiss_admin_review_report_path(r1)
    assert_redirected_to admin_moderation_path
    assert_equal 0, ReviewReport.open_reports.where(review: @review).count
    assert_equal 2, ReviewReport.where(review: @review, status: "dismissed").count
  end

  test "a limited admin can dismiss but sees no delete button" do
    ReviewReport.create!(review: @review, user: users(:jane))
    sign_in users(:limited_admin)

    get admin_moderation_path
    assert_response :success
    assert_no_match(/Delete review/, @response.body)

    post dismiss_admin_review_report_path(ReviewReport.last)
    assert_redirected_to admin_moderation_path
  end

  test "deleting a reported review clears its reports from the queue" do
    ReviewReport.create!(review: @review, user: users(:jane))
    sign_in users(:admin)

    assert_difference("Review.count", -1) do
      delete admin_bottle_review_path(@review.bottle, @review)
    end
    assert_equal 0, ReviewReport.where(review_id: @review.id).count
  end

  test "non-admins cannot reach the moderation queue" do
    sign_in users(:jane)
    get admin_moderation_path
    assert_redirected_to root_path
  end
end
