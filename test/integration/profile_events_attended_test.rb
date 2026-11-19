require "test_helper"

class ProfileEventsAttendedTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @society = Society.first
    @organizer = users(:seth)
  end

  def past_event(title)
    st = 2.days.ago
    e = Event.new(society: @society, organizer: @organizer, title: title, description: "x",
                  location: "den", start_time: st, end_time: st + 2.hours)
    e.save!(validate: false)
    e
  end

  test "events attended counts only past events with a yes RSVP" do
    @user.event_rsvps.destroy_all
    EventRsvp.new(user: @user, event: past_event("One"), status: "yes").save!(validate: false)
    EventRsvp.new(user: @user, event: past_event("Two"), status: "yes").save!(validate: false)
    EventRsvp.new(user: @user, event: past_event("Maybe"), status: "maybe").save!(validate: false)
    future = Event.new(society: @society, organizer: @organizer, title: "Future", description: "x", location: "den",
                       start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours)
    future.save!(validate: false)
    EventRsvp.new(user: @user, event: future, status: "yes").save!(validate: false)

    assert_equal 2, @user.events_attended_count

    post "/users/sign_in", params: { user: { email: users(:seth).email, password: "password" } }
    get profile_path(@user)
    assert_response :success
    assert_select "span.chip", text: /\A\s*2 events attended\s*\z/
  end
end
