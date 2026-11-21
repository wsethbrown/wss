require "test_helper"

# B1 (S12, membership part): an emailed RSVP link outlives membership, so it
# re-checks that the person may still RSVP to a private society's event.
# B8 (S12): the emailed link is a GET that mail scanners follow, so it only
# shows a one-button confirmation page; the POST records the answer and
# re-checks the RSVP policy.
class EmailRsvpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @society = societies(:bourbon_club) # private
    st = 5.days.from_now
    @event = Event.create!(society: @society, organizer: users(:jane), title: "Cask Night",
                           description: "x", location: "x", start_time: st, end_time: st + 2.hours)
    @user = users(:one)
    @membership = SocietyMembership.create!(user: @user, society: @society, role: "member", status: "active")
    @token = EmailRsvpsController.token_for(@user, @event)
  end

  test "a GET of the emailed link changes nothing and shows a form that POSTs" do
    assert_no_difference -> { EventRsvp.count } do
      assert_no_enqueued_emails do
        get email_rsvp_path("yes", token: @token)
      end
    end
    assert_response :success
    assert_select "form[method=post][action=?]", email_rsvp_path("yes") do
      assert_select "input[type=hidden][name=token][value=?]", @token
      assert_select "button, input[type=submit]", count: 1
    end
    assert_includes response.body, "Cask Night"
  end

  test "the POST records a current member's answer" do
    post email_rsvp_path("yes"), params: { token: @token }
    assert_equal "yes", @event.event_rsvps.find_by(user: @user)&.status
    assert_redirected_to society_event_path(@society, @event)
  end

  test "the POST can change an existing answer" do
    post email_rsvp_path("yes"), params: { token: @token }
    post email_rsvp_path("no"), params: { token: @token }
    assert_equal "no", @event.event_rsvps.find_by(user: @user).status
    assert_equal 1, @event.event_rsvps.where(user: @user).count
  end

  test "a removed member's old RSVP link is refused at the confirm page and the POST" do
    @membership.destroy!
    get email_rsvp_path("yes", token: @token)
    assert_redirected_to root_path
    assert_no_difference -> { EventRsvp.count } do
      post email_rsvp_path("yes"), params: { token: @token }
    end
    assert_redirected_to root_path
  end

  test "the POST is refused once the RSVP window has closed" do
    @event.update_columns(start_time: 1.minute.ago, end_time: 2.hours.from_now)
    %w[yes maybe no].each do |status|
      assert_no_difference -> { EventRsvp.count } do
        post email_rsvp_path(status), params: { token: @token }
      end
    end
  end

  test "a new yes is refused inside the last 24 hours of a night announced earlier; maybe is not" do
    @event.update_columns(start_time: 2.hours.from_now, end_time: 4.hours.from_now, created_at: 5.days.ago)
    get email_rsvp_path("yes", token: @token)
    assert_redirected_to society_event_path(@society, @event)
    assert_no_difference -> { EventRsvp.count } do
      post email_rsvp_path("yes"), params: { token: @token }
    end
    assert_difference -> { EventRsvp.count }, 1 do
      post email_rsvp_path("maybe"), params: { token: @token }
    end
  end

  test "a forged token is refused on both verbs" do
    get email_rsvp_path("yes", token: "garbage--forged")
    assert_redirected_to root_path
    post email_rsvp_path("yes"), params: { token: "garbage--forged" }
    assert_redirected_to root_path
    assert_equal 0, @event.event_rsvps.count
  end

  test "an unknown status is refused on the confirm page" do
    get "/email_rsvps/definitely?token=#{@token}"
    assert_response :redirect
    assert_equal 0, @event.event_rsvps.count
  end
end
