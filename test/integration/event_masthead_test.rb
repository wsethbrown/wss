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

  # "Default to maybe" is a RESTING POSITION for the control, never a record.
  # Writing a maybe on page view would tell every host that people who never
  # opened the page are undecided, and would create data on a GET.
  test "an unanswered control rests on maybe without recording anything" do
    sign_in @member
    assert_no_difference "EventRsvp.count" do
      get society_event_path(@society, @event)
    end

    assert_nil @event.event_rsvps.find_by(user: @member)
    assert_equal 0, @event.reload.maybe_count, "nobody is counted as maybe until they say so"
    # Nothing is pressed, so CSS reveals no tick; Maybe is only the resting
    # position, which is a different attribute entirely.
    assert_select "#event-rsvp-buttons [role=group] button[aria-pressed=true]", count: 0
    assert_select "#event-rsvp-buttons button[data-resting=true][data-answer=maybe]", count: 1
  end

  test "whichever answer was given is the pressed one" do
    sign_in @member
    %w[yes maybe no].each do |answer|
      EventRsvp.where(event: @event).delete_all
      EventRsvp.new(user: @member, event: @event, status: answer).save!(validate: false)
      get society_event_path(@society, @event)

      assert_select "#event-rsvp-buttons button[aria-pressed=true]", count: 1 do |pressed|
        assert_equal answer, pressed.first["data-answer"]
      end
      assert_select "#event-rsvp-buttons button[data-resting=true]", count: 0,
                    msg: "resting is the pre-answer state; it must not linger"
    end
  end

  # THE invariant behind the slide: a stream that re-renders the control tears
  # the indicator out mid-transition and the fill snaps instead of moving.
  test "no turbo stream re-renders the segmented control" do
    %w[create update].each do |action|
      template = Rails.root.join("app/views/event_rsvps/#{action}.turbo_stream.erb").read
      assert_no_match(/target: *"event-rsvp-buttons"|"event-rsvp-buttons"/, template,
                      "#{action}.turbo_stream re-renders the control, which breaks the slide")
      assert_match "rsvp-note-region", template, "the note still has to be refreshed"
    end
  end

  # The control never re-renders, so its form action can never change: the
  # endpoint has to accept the second and third answers too.
  test "answering twice through the same action works" do
    sign_in @member
    assert_difference "EventRsvp.count", 1 do
      post event_event_rsvps_path(@event), params: { status: "yes" }
    end
    assert_no_difference "EventRsvp.count" do
      post event_event_rsvps_path(@event), params: { status: "no" }
    end
    assert_equal "no", @event.event_rsvps.find_by(user: @member).status
  end

  # The note region has the same trap the attendee list had: a target that only
  # exists once someone has answered can't be replaced by the answer that
  # creates it, so the note would never appear without a reload.
  test "the note region renders as a turbo target before anyone answers" do
    sign_in @member
    get society_event_path(@society, @event)

    assert_select "#rsvp-note-region", count: 1
    assert_select "#rsvp-note-region details", count: 0, msg: "nothing to note yet"

    post event_event_rsvps_path(@event), params: { status: "yes" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_match "rsvp-note-region", response.body
    assert_match "Add a note for the host", response.body
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
