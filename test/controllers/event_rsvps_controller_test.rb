require "test_helper"

# B1 (S2, S19): RSVPs are only as open as the event. A private society's
# event refuses outsiders outright: no RSVP row, no attendee list in the
# response, no email to the organizer. Public societies keep their current
# rule (any signed-in user) until the owner decides otherwise; see
# Event::PUBLIC_EVENTS_OPEN_TO_NON_MEMBERS.
class EventRsvpsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @private_society = societies(:bourbon_club) # creator jane, private
    @public_society = Society.create!(name: "Open Pour Club", description: "x", creator: users(:john), is_private: false)
    st = 5.days.from_now
    @private_event = Event.create!(society: @private_society, organizer: users(:jane), title: "Secret Barrel Night",
                                   description: "x", location: "cellar", start_time: st, end_time: st + 2.hours)
    @public_event = Event.create!(society: @public_society, organizer: users(:john), title: "Open Night",
                                  description: "x", location: "bar", start_time: st, end_time: st + 2.hours)
    @outsider = users(:one)
    @member = users(:seth)
    SocietyMembership.create!(user: @member, society: @private_society, role: "member", status: "active")
    # Something an outsider must never see in the response.
    EventRsvp.create!(user: @member, event: @private_event, status: "yes")
  end

  test "a non-member cannot RSVP to a private society's event" do
    sign_in @outsider
    assert_no_difference -> { EventRsvp.count } do
      assert_no_enqueued_emails do
        post society_event_event_rsvps_path(@private_society, @private_event),
             params: { status: "yes" }, as: :turbo_stream
      end
    end
    assert_no_match "event-attendees", response.body
    assert_no_match @member.first_name.to_s, response.body if @member.first_name.present?
  end

  test "a non-member cannot RSVP to a private event through the top-level route either" do
    sign_in @outsider
    assert_no_difference -> { EventRsvp.count } do
      post event_event_rsvps_path(@private_event), params: { status: "yes" }
    end
  end

  test "a member of a private society can still RSVP" do
    other = users(:john)
    SocietyMembership.create!(user: other, society: @private_society, role: "member", status: "active")
    sign_in other
    assert_difference -> { EventRsvp.count }, 1 do
      post society_event_event_rsvps_path(@private_society, @private_event), params: { status: "yes" }, as: :turbo_stream
    end
    assert_match "event-attendees", response.body
  end

  test "a removed member cannot change their old RSVP to a private event" do
    sign_in @member
    @private_society.society_memberships.find_by(user: @member).destroy!
    post society_event_event_rsvps_path(@private_society, @private_event), params: { status: "no" }
    assert_equal "yes", @private_event.event_rsvps.find_by(user: @member).status
  end

  test "public society events keep accepting signed-in non-members (owner default)" do
    sign_in @outsider
    assert_difference -> { EventRsvp.count }, 1 do
      post society_event_event_rsvps_path(@public_society, @public_event), params: { status: "yes" }
    end
  end

  test "a signed-out RSVP redirects to sign in and creates nothing" do
    assert_no_difference -> { EventRsvp.count } do
      post society_event_event_rsvps_path(@public_society, @public_event), params: { status: "yes" }
    end
    assert_redirected_to new_user_session_path
  end

  test "a signed-out update redirects to sign in instead of erroring" do
    patch society_event_event_rsvp_path(@public_society, @public_event, 1), params: { event_rsvp: { status: "no" } }
    assert_redirected_to new_user_session_path
  end

  test "updating an RSVP you never made is a 404, not a 500" do
    sign_in @outsider
    patch society_event_event_rsvp_path(@public_society, @public_event, 1), params: { event_rsvp: { status: "no" } }
    assert_response :not_found
  end

  test "cancelling an RSVP you never made is a 404, not a 500" do
    sign_in @outsider
    delete society_event_event_rsvp_path(@public_society, @public_event, 1)
    assert_response :not_found
  end
end
