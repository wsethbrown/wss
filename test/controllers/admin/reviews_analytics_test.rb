require "test_helper"

class Admin::ReviewsAnalyticsTest < ActionDispatch::IntegrationTest
  test "the reviews analytics page renders with its sections" do
    sign_in users(:admin)
    get admin_reviews_analytics_path
    assert_response :success
    assert_select "h1", text: /Reviews/
    assert_match(/Total reviews/, @response.body)
    assert_match(/Most reviewed bottles/, @response.body)
    assert_match(/Top rated bottles/, @response.body)
    assert_match(/Most active reviewers/, @response.body)
  end

  test "a non-admin cannot reach reviews analytics" do
    sign_in users(:john)
    get admin_reviews_analytics_path
    assert_redirected_to root_path
  end

  test "a limited admin can reach reviews analytics (it is not a delete)" do
    sign_in users(:limited_admin)
    get admin_reviews_analytics_path
    assert_response :success
  end

  test "the analytics reflect review data" do
    bottle = bottles(:eagle_rare) # has one review (john) in fixtures
    Review.create!(user: users(:jane), bottle: bottle, rating: 5.0, notes: "excellent")

    sign_in users(:admin)
    get admin_reviews_analytics_path
    assert_response :success
    # The two-reviewer bottle shows up in both the most-reviewed and top-rated lists.
    assert_match(/Eagle Rare/, @response.body)
  end
end
