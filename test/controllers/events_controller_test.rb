require "test_helper"

# B1 (S19): signed-out writes go to sign in; a missing society is a refusal,
# never a 500.
class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @society = societies(:whiskey_lovers) # creator john (admin member)
  end

  test "a signed-out POST to create an event redirects to sign in and creates nothing" do
    assert_no_difference -> { Event.count } do
      post society_events_path(@society), params: { event: { society_id: @society.id, title: "Sneaky",
                                                              description: "x", location: "x",
                                                              start_time: 3.days.from_now, end_time: 3.days.from_now + 1.hour } }
    end
    assert_redirected_to new_user_session_path
  end

  test "a signed-out visitor asking for the new-event form is sent to sign in" do
    get new_society_event_path(@society)
    assert_redirected_to new_user_session_path
  end

  test "creating an event with no society is refused, not a 500" do
    sign_in users(:one)
    assert_no_difference -> { Event.count } do
      post society_events_path(@society), params: { event: { title: "Orphan", description: "x", location: "x",
                                                              start_time: 3.days.from_now, end_time: 3.days.from_now + 1.hour } }
    end
    assert_response :redirect
  end

  test "a society admin can still create an event" do
    sign_in users(:john)
    assert_difference -> { Event.count }, 1 do
      post society_events_path(@society), params: { event: { society_id: @society.id, title: "Real Night",
                                                              description: "x", location: "x",
                                                              start_time: 3.days.from_now, end_time: 3.days.from_now + 1.hour } }
    end
  end

  test "the events index still renders" do
    get society_events_path(@society)
    assert_response :success
  end
end
