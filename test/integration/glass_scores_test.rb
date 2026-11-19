require "test_helper"

# G1b: scores are shown as one glass beside the number, never as stars.
class GlassScoresTest < ActionDispatch::IntegrationTest
  test "the reviews index shows each bottle's score as a glass with its number" do
    get reviews_path
    assert_response :success
    scores = css_select("[data-score]")
    assert scores.any?
    scores.each do |score|
      assert_equal 1, score.css("svg[data-glass]").size
      assert_match(/\A#{Regexp.escape(score["data-score"])}\s+out of 5\z/, score.text.strip)
    end
    assert_empty css_select("svg[data-star]")
  end

  test "a bottle page and a review page show glasses with scores and no stars" do
    get bottle_path(bottles(:eagle_rare))
    assert_response :success
    assert css_select("[data-score] svg[data-glass]").any?
    assert_empty css_select("svg[data-star]")

    get review_path(reviews(:john_eagle_rare))
    assert_response :success
    assert css_select("[data-score] svg[data-glass]").any?
    assert_empty css_select("svg[data-star]")
  end
end
