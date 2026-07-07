require "test_helper"

class ReviewVotesControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user votes for a review" do
    sign_in users(:seth)
    assert_difference "ReviewVote.count", 1 do
      post review_votes_path, params: { review_id: reviews(:john_spring_ardbeg).id }
    end
    assert_redirected_to review_path(reviews(:john_spring_ardbeg))
  end

  test "cannot vote for your own review" do
    sign_in users(:john)
    assert_no_difference "ReviewVote.count" do
      post review_votes_path, params: { review_id: reviews(:john_eagle_rare).id }
    end
  end

  test "unvoting destroys the record" do
    sign_in users(:seth)
    assert_difference "ReviewVote.count", -1 do
      delete review_vote_path(review_votes(:seth_votes_john_eagle_rare))
    end
  end

  test "cannot destroy someone else's vote" do
    sign_in users(:john)
    assert_no_difference "ReviewVote.count" do
      delete review_vote_path(review_votes(:seth_votes_john_eagle_rare))
    end
    assert_response :not_found
  end
end
