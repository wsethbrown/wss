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

  # D4b: nothing links to a standalone events list, so it redirects.
  test "the events index redirects to the society page" do
    get society_events_path(@society)
    assert_redirected_to society_path(@society)
  end

  test "the events index redirects a private society's request without rendering anything" do
    private_society = societies(:bourbon_club)
    get society_events_path(private_society)
    assert_redirected_to society_path(private_society)
  end

  # --- Edit / update (D4b) ---------------------------------------------------

  def build_event(society:, organizer:)
    # Odd seconds on purpose: stored times are not minute-aligned in real data.
    start = Time.utc(2027, 3, 12, 23, 30, 42)
    Event.create!(society: society, organizer: organizer, title: "Edit Night", description: "d",
                  location: "Somewhere", start_time: start, end_time: start + 2.hours)
  end

  def event_path_for(event) = society_event_path(event.society, event)

  test "the organizer sees the edit form prefilled in their own time zone" do
    event = build_event(society: societies(:single_malt), organizer: users(:seth))
    sign_in users(:seth)
    cookies[:browser_timezone] = "America/New_York"
    get edit_society_event_path(event.society, event)
    assert_response :success
    # 23:30 UTC on 12 March 2027 is 18:30 in New York (EST until the 14th)
    expected = event.start_time.in_time_zone("America/New_York").strftime("%Y-%m-%dT%H:%M")
    assert_select "input[name='event[start_time]'][value='#{expected}']"
    assert_select "input[name='event[title]'][value='Edit Night']"
    assert_select "select[name='event[society_id]']", false
    assert_select "input[name='event[host_query]']", false
  end

  test "submitting the edit form unchanged leaves the stored times alone and notifies nobody" do
    event = build_event(society: societies(:single_malt), organizer: users(:seth))
    original_start, original_end = event.start_time, event.end_time
    sign_in users(:seth)
    cookies[:browser_timezone] = "America/New_York"

    get edit_society_event_path(event.society, event)
    form = css_select("form[action='#{event_path_for(event)}']").first
    fields = form.css("input[name^='event['], textarea[name^='event[']").to_h { |i| [ i["name"], i["value"] || i.text.strip ] }

    assert_no_enqueued_jobs(only: EventNotificationJob) do
      patch event_path_for(event), params: { event: fields.slice("event[title]", "event[description]", "event[location]",
                                                                 "event[start_time]", "event[end_time]")
                                                         .transform_keys { |k| k[/\[(.*)\]/, 1] } }
    end
    assert_redirected_to event_path(event)
    event.reload
    assert_equal original_start.to_i, event.start_time.to_i
    assert_equal original_end.to_i, event.end_time.to_i
  end

  test "changing the time in the browser zone is stored in UTC and notifies" do
    event = build_event(society: societies(:single_malt), organizer: users(:seth))
    sign_in users(:seth)
    cookies[:browser_timezone] = "America/New_York"
    assert_enqueued_with(job: EventNotificationJob) do
      patch event_path_for(event), params: { event: { start_time: "2027-03-12T20:00", end_time: "2027-03-12T22:00" } }
    end
    assert_equal Time.utc(2027, 3, 13, 1, 0), event.reload.start_time.utc
  end

  test "the organizer can update their event" do
    event = build_event(society: societies(:single_malt), organizer: users(:seth))
    sign_in users(:seth)
    patch event_path_for(event), params: { event: { title: "Renamed" } }
    assert_redirected_to event_path(event)
    assert_equal "Renamed", event.reload.title
  end

  test "a society admin who is not the organizer can edit and update" do
    event = build_event(society: societies(:whiskey_lovers), organizer: users(:jane))
    sign_in users(:john) # creator + admin member of whiskey_lovers
    get edit_society_event_path(event.society, event)
    assert_response :success
    patch event_path_for(event), params: { event: { title: "By Admin" } }
    assert_equal "By Admin", event.reload.title
  end

  test "a plain member cannot edit or update" do
    event = build_event(society: societies(:single_malt), organizer: users(:admin))
    sign_in users(:seth) # member, not organizer, not admin
    get edit_society_event_path(event.society, event)
    assert_redirected_to root_path
    patch event_path_for(event), params: { event: { title: "Hijack" } }
    assert_equal "Edit Night", event.reload.title
  end

  test "an outsider cannot edit or update" do
    event = build_event(society: societies(:whiskey_lovers), organizer: users(:john))
    sign_in users(:jane)
    get edit_society_event_path(event.society, event)
    assert_response :redirect
    patch event_path_for(event), params: { event: { title: "Hijack" } }
    assert_equal "Edit Night", event.reload.title
  end

  test "a signed-out visitor is sent to sign in for edit and update" do
    event = build_event(society: societies(:whiskey_lovers), organizer: users(:john))
    get edit_society_event_path(event.society, event)
    assert_redirected_to new_user_session_path
    patch event_path_for(event), params: { event: { title: "Hijack" } }
    assert_redirected_to new_user_session_path
    assert_equal "Edit Night", event.reload.title
  end

  # --- Destroy (D4b) -----------------------------------------------------------

  test "the organizer deleting an event lands on the society page and the event is gone" do
    event = build_event(society: societies(:single_malt), organizer: users(:seth))
    sign_in users(:seth)
    assert_difference -> { Event.count }, -1 do
      delete event_path_for(event)
    end
    assert_redirected_to society_path(societies(:single_malt))
    assert_equal "Event was successfully deleted.", flash[:notice]
  end

  test "a society admin who is not the organizer can delete the event" do
    event = build_event(society: societies(:whiskey_lovers), organizer: users(:jane))
    sign_in users(:john)
    assert_difference -> { Event.count }, -1 do
      delete event_path_for(event)
    end
    assert_redirected_to society_path(societies(:whiskey_lovers))
  end

  test "a plain member and an outsider cannot delete an event" do
    event = build_event(society: societies(:single_malt), organizer: users(:admin))
    [ users(:seth), users(:jane) ].each do |user|
      sign_in user
      assert_no_difference -> { Event.count } do
        delete event_path_for(event)
      end
      assert_response :redirect
    end
  end

  test "create stores the organiser's browser zone on the event (B15)" do
    sign_in users(:john)
    cookies[:browser_timezone] = "America/Chicago"
    post society_events_path(@society), params: { event: { society_id: @society.id, title: "Zone Night",
                                                            description: "x", location: "x",
                                                            start_time: "2030-03-01T19:30", end_time: "2030-03-01T21:30" } }
    event = Event.find_by!(title: "Zone Night")
    assert_equal "America/Chicago", event.time_zone
    assert_match(/7:30 PM CST\z/, event.start_time_label)
  end

  test "create without a zone cookie uses the fallback zone (B15)" do
    sign_in users(:john)
    post society_events_path(@society), params: { event: { society_id: @society.id, title: "Fallback Night",
                                                            description: "x", location: "x",
                                                            start_time: 3.days.from_now, end_time: 3.days.from_now + 1.hour } }
    assert_equal Event::FALLBACK_TIME_ZONE, Event.find_by!(title: "Fallback Night").time_zone
  end
end
