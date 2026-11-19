require "test_helper"

# B1 (S12, membership part): an emailed RSVP link outlives membership, so it
# re-checks that the person may still RSVP to a private society's event.
class EmailRsvpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @society = societies(:bourbon_club) # private
    st = 5.days.from_now
    @event = Event.create!(society: @society, organizer: users(:jane), title: "Cask Night",
                           description: "x", location: "x", start_time: st, end_time: st + 2.hours)
    @user = users(:one)
    @membership = SocietyMembership.create!(user: @user, society: @society, role: "member", status: "active")
  end

  test "a current member's email RSVP still records" do
    get email_rsvp_path("yes", token: EmailRsvpsController.token_for(@user, @event))
    assert_equal "yes", @event.event_rsvps.find_by(user: @user)&.status
  end

  test "a removed member's old RSVP link is refused" do
    token = EmailRsvpsController.token_for(@user, @event)
    @membership.destroy!
    assert_no_difference -> { EventRsvp.count } do
      get email_rsvp_path("yes", token: token)
    end
    assert_response :redirect
  end
end
