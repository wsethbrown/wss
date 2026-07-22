require "test_helper"

# The event masthead and RSVP control, rebuilt July 2026. These pin the two
# things the rebuild fixed, both of which are invisible in a screenshot once
# they regress.
class EventMastheadTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = users(:john)
    @member = users(:jane)
    @society = Society.create!(name: "Masthead Club", description: "x",
                               creator: @organizer, is_private: false)
    [ @organizer, @member ].each do |user|
      SocietyMembership.find_or_create_by!(society: @society, user: user) do |m|
        m.role = "member"
        m.status = "active"
      end
    end
    @event = Event.new(society: @society, organizer: @organizer, title: "Cask Night",
                       description: "x", location: "275 Atkinson Drive, Athens GA",
                       start_time: 5.days.from_now, end_time: 5.days.from_now + 3.hours)
    @event.save!(validate: false)
  end

  test "the society is named once in the masthead, not twice" do
    sign_in @member
    get society_event_path(@society, @event)
    assert_response :success

    masthead = css_select("nav[aria-label=Breadcrumb]").first.parent
    occurrences = masthead.to_s.scan(@society.name).size
    assert_equal 1, occurrences,
                 "the society appeared #{occurrences}x; the breadcrumb is the only place it belongs"
  end

  test "the RSVP control is one segmented group, not three coloured buttons" do
    sign_in @member
    get society_event_path(@society, @event)

    assert_select "#event-rsvp-buttons [role=group][aria-label=?]", "Your RSVP"
    assert_select "#event-rsvp-buttons [role=group] button", count: 3
    # The traffic-light palette the overhaul purged, hardcoded as inline hex.
    assert_no_match(/background-color: #047857/, response.body)
    assert_select "#event-rsvp-buttons .bg-green-50", count: 0
    assert_select "#event-rsvp-buttons .bg-red-50", count: 0
  end

  test "the chosen answer is marked by more than colour" do
    EventRsvp.new(user: @member, event: @event, status: "yes").save!(validate: false)
    sign_in @member
    get society_event_path(@society, @event)

    assert_select "#event-rsvp-buttons [role=group] button[aria-pressed=true]", count: 1 do |button|
      assert_equal "Yes", button.first.text.strip
      assert button.first.css("svg").any?, "the chosen answer carries a tick, not just a fill"
    end
  end

  # The note competed with the RSVP itself before; it is folded away until a
  # person has actually answered.
  test "the note is offered only after answering, and starts folded" do
    sign_in @member
    get society_event_path(@society, @event)
    assert_select "#event-rsvp-buttons details", count: 0

    EventRsvp.new(user: @member, event: @event, status: "yes").save!(validate: false)
    get society_event_path(@society, @event)
    assert_select "#event-rsvp-buttons details:not([open])", count: 1
  end

  test "an existing note starts open so it can be seen and edited" do
    EventRsvp.new(user: @member, event: @event, status: "yes", note: "Bringing rye").save!(validate: false)
    sign_in @member
    get society_event_path(@society, @event)

    assert_select "#event-rsvp-buttons details[open]", count: 1
    assert_select "#rsvp-note[value=?]", "Bringing rye"
  end

  # The bug this rebuild fixed: the attendee list only existed once somebody
  # was attending, so the turbo_stream replace on the FIRST yes had no target
  # and your own name never appeared until a reload.
  test "the attendee list renders as a turbo target even with nobody attending" do
    sign_in @member
    get society_event_path(@society, @event)

    assert_equal 0, @event.yes_count
    assert_select "#event-attendees", count: 1
    assert_select "#event-attendees", text: /No one has said yes yet/
  end

  test "every RSVP turbo stream refreshes the attendee list" do
    %w[create update].each do |action|
      template = Rails.root.join("app/views/event_rsvps/#{action}.turbo_stream.erb").read
      assert_match "event-attendees", template,
                   "#{action}.turbo_stream leaves the attendee list stale"
    end
  end

  test "the three RSVP states each say something true" do
    sign_in @member

    get society_event_path(@society, @event)
    assert_select "#event-rsvp-buttons", count: 1

    @event.update_columns(start_time: 6.hours.from_now, end_time: 8.hours.from_now)
    get society_event_path(@society, @event)
    assert_select "#event-rsvp-buttons", count: 0
    assert_match "RSVPs closed", response.body

    @event.update_columns(start_time: 3.days.ago, end_time: 3.days.ago + 2.hours)
    get society_event_path(@society, @event)
    assert_match "This night has passed", response.body
  end

  test "a signed-out visitor is pointed at a sign-in that exists" do
    get society_event_path(@society, @event)
    assert_response :success
    assert_select "a[href=?]", new_user_session_path
  end
end
