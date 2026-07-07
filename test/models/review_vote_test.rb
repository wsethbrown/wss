require "test_helper"

class ReviewVoteTest < ActiveSupport::TestCase
  test "a user can vote for someone else's review" do
    assert ReviewVote.new(user: users(:seth), review: reviews(:john_spring_ardbeg)).valid?
  end

  test "cannot vote for your own review" do
    vote = ReviewVote.new(user: users(:john), review: reviews(:john_spring_ardbeg))
    assert_not vote.valid?
    assert_includes vote.errors[:base], "You can't vote for your own review"
  end

  test "duplicate vote is invalid" do
    ReviewVote.create!(user: users(:seth), review: reviews(:john_spring_ardbeg))
    dup = ReviewVote.new(user: users(:seth), review: reviews(:john_spring_ardbeg))
    assert_not dup.valid?
    assert_includes dup.errors[:review_id], "has already been taken"
  end

  test "voting increments the counter cache" do
    review = reviews(:john_spring_glendronach)
    assert_difference -> { review.reload.votes_count }, 1 do
      ReviewVote.create!(user: users(:seth), review: review)
    end
  end

  test "unvoting decrements the counter cache" do
    vote = ReviewVote.create!(user: users(:jane), review: reviews(:john_eagle_rare))
    assert_difference -> { reviews(:john_eagle_rare).reload.votes_count }, -1 do
      vote.destroy
    end
  end
end
