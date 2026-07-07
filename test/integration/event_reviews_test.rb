require "test_helper"

class EventReviewsTest < ActionDispatch::IntegrationTest
  test "event page shows the night's group means with expandable individual reviews" do
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_response :success
    assert_match "4.25", response.body                     # Ardbeg: john 4.5, seth 4.0
    assert_match "3.25", response.body                     # GlenDronach: 3.5, 3.0
    assert_match "2 reviews from the night", response.body
    assert_match "Smoke first, then pears", response.body  # john's note in the expandable list
    assert_match "Campfire in a glass", response.body      # seth's cross-bottle score, same page
  end

  test "RSVP'd member sees a review button for pours they haven't reviewed" do
    sign_in users(:seth) # reviewed pours 1–2, not the Four Roses
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_select "a[href=?]",
                  new_event_review_path(events(:spring_blind), bottle_id: bottles(:four_roses_sb).slug),
                  text: "Review this pour"
  end

  test "a member's existing event review turns into an edit link" do
    sign_in users(:seth)
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_select "a[href=?]", edit_review_path(reviews(:seth_spring_ardbeg)), text: "Edit your review"
  end

  test "signed-in visitors without a yes RSVP get no review buttons" do
    sign_in users(:jane)
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_no_match "Review this pour", response.body
    assert_match "4.25", response.body # the record itself stays public
  end

  test "RSVP'd member creates an event-tagged review" do
    sign_in users(:seth)
    assert_difference "Review.count", 1 do
      post event_reviews_path(events(:spring_blind), bottle_id: bottles(:four_roses_sb).slug),
           params: { review: { rating: "4.5", notes: "Round two, still good." } }
    end
    review = Review.find_by!(user: users(:seth), bottle: bottles(:four_roses_sb),
                             event: events(:spring_blind))
    assert_not review.solo?
    assert_redirected_to society_event_path(societies(:single_malt), events(:spring_blind))
  end

  test "create is rejected without a yes RSVP" do
    sign_in users(:jane)
    assert_no_difference "Review.count" do
      post event_reviews_path(events(:spring_blind), bottle_id: bottles(:ardbeg_10).slug),
           params: { review: { rating: "4.0" } }
    end
    assert_response :unprocessable_entity
  end

  test "reviewing a bottle not on the pour list is rejected, not 404" do
    # john RSVP'd yes for spring_blind (ardbeg/glendronach/four_roses).
    # Attempt to review lagavulin (exists globally, but not on spring_blind's pour list).
    # Should return unprocessable_entity (model gate fires), not 404.
    sign_in users(:john)
    assert_no_difference "Review.count" do
      post event_reviews_path(events(:spring_blind), bottle_id: bottles(:lagavulin).slug),
           params: { review: { rating: "4.0" } }
    end
    assert_response :unprocessable_entity
  end
end

class EventPrivacyTest < ActionDispatch::IntegrationTest
  # The veil showed a private event's title; the event PAGE must not then
  # hand over the society, members, and pours (owner directive: member
  # lists and event calendars are private).
  test "a private society's event page is not reachable by outsiders" do
    event = events(:allocated_night)
    get society_event_path(event.society, event)
    assert_redirected_to root_path

    sign_in users(:seth) # not a bourbon_club member
    get society_event_path(event.society, event)
    assert_response :redirect
  end

  test "members still see their private society's event" do
    event = events(:allocated_night)
    sign_in users(:jane) # bourbon_club creator
    get society_event_path(event.society, event)
    assert_response :success
    assert_match event.title, response.body
  end

  test "the event policy scope hides private societies' events from outsiders" do
    # The index view is a scaffold stub today; the scope is the guard that
    # matters (and will keep any future listing honest).
    anonymous = EventPolicy::Scope.new(nil, Event).resolve
    assert_not_includes anonymous, events(:allocated_night)
    assert_includes anonymous, events(:spring_blind)

    member = EventPolicy::Scope.new(users(:jane), Event).resolve # bourbon_club creator
    assert_includes member, events(:allocated_night)
  end
end
