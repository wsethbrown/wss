require "test_helper"

# B1 (S11): the event-review form must not reveal a private society's name
# or event title to someone who cannot see the event.
class Events::ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @society = societies(:bourbon_club) # private, creator jane
    st = 2.days.ago
    @event = Event.create!(society: @society, organizer: users(:jane), title: "Hidden Cask Evening",
                           description: "x", location: "cellar", start_time: st, end_time: st + 2.hours)
    @bottle = bottles(:eagle_rare)
  end

  test "a non-member is refused the review form without the society name in the body" do
    sign_in users(:one)
    get new_event_review_path(@event, bottle_id: @bottle.slug)
    assert_response :redirect
    follow_redirect! if response.redirect?
    assert_no_match @society.name, response.body
    assert_no_match @event.title, response.body
  end

  test "a non-member cannot post a review to a private event" do
    sign_in users(:one)
    assert_no_difference -> { Review.count } do
      post event_reviews_path(@event, bottle_id: @bottle.slug), params: { review: { rating: 4, notes: "x" } }
    end
  end

  test "a member still reaches the review form" do
    sign_in users(:jane)
    get new_event_review_path(@event, bottle_id: @bottle.slug)
    assert_response :success
  end

  test "signed out is sent to sign in" do
    get new_event_review_path(@event, bottle_id: @bottle.slug)
    assert_redirected_to new_user_session_path
  end
end
