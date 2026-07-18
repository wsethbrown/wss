require "test_helper"

# Per-event hosts (owner-requested, July 2026): a society admin assigns a
# member as Host of one event. The host sees that event's RSVP replies
# (statuses + notes) on the event page and joins the RSVP emails.
class EventHostsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @organizer = users(:john)
    @member = users(:jane)
    @host = users(:one)
    @society = Society.create!(name: "Host Club", description: "x", creator: @organizer, is_private: false)
    [@member, @host].each { |u| SocietyMembership.create!(user: u, society: @society, role: "member", status: "active") }
    st = 3.days.from_now
    @event = Event.create!(society: @society, organizer: @organizer, title: "Host Night",
                           description: "x", location: "den", start_time: st, end_time: st + 2.hours)
  end

  # ---- assignment -----------------------------------------------------------
  test "a society admin can assign a member as host" do
    sign_in @organizer
    patch assign_host_society_event_path(@society, @event), params: { host_id: @host.id }
    assert_equal @host, @event.reload.host
  end

  test "a regular member cannot assign a host" do
    sign_in @member
    patch assign_host_society_event_path(@society, @event), params: { host_id: @host.id }
    assert_nil @event.reload.host
  end

  test "the host must be an active society member" do
    sign_in @organizer
    patch assign_host_society_event_path(@society, @event), params: { host_id: users(:seth).id }
    assert_nil @event.reload.host
  end

  test "the host can be removed" do
    @event.update!(host: @host)
    sign_in @organizer
    patch assign_host_society_event_path(@society, @event), params: { host_id: "" }
    assert_nil @event.reload.host
  end

  # ---- visibility -----------------------------------------------------------
  test "the host sees RSVP replies including notes" do
    @event.update!(host: @host)
    EventRsvp.create!(user: @member, event: @event, status: "yes", note: "Bringing the Ardbeg")
    sign_in @host
    get society_event_path(@society, @event)
    assert_response :success
    assert_match "Bringing the Ardbeg", response.body
  end

  test "a regular member does not see RSVP notes" do
    @event.update!(host: @host)
    EventRsvp.create!(user: @host, event: @event, status: "yes", note: "Only for hosts")
    sign_in @member
    get society_event_path(@society, @event)
    assert_response :success
    assert_no_match "Only for hosts", response.body
  end

  # ---- notifications --------------------------------------------------------
  test "the host is emailed on new RSVPs alongside the organizer" do
    @event.update!(host: @host)
    sign_in @member
    assert_enqueued_emails 2 do
      post event_event_rsvps_path(@event), params: { status: "yes" }
    end
  end

  test "an organizer who is also the host gets one email" do
    @event.update!(host: @organizer)
    sign_in @member
    assert_enqueued_emails 1 do
      post event_event_rsvps_path(@event), params: { status: "yes" }
    end
  end

  test "a muted host is skipped" do
    @host.update!(event_emails: false)
    @event.update!(host: @host)
    sign_in @member
    assert_enqueued_emails 1 do
      post event_event_rsvps_path(@event), params: { status: "yes" }
    end
  end

  test "the host RSVPing does not email themselves" do
    @event.update!(host: @host)
    sign_in @host
    assert_enqueued_emails 1 do # organizer only
      post event_event_rsvps_path(@event), params: { status: "yes" }
    end
  end
end
