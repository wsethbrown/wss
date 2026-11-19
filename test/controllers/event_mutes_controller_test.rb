require "test_helper"

# B15 (I23): a signed one-click mute for event emails. Single purpose: the
# token names the member, the event and the purpose, and can only switch off
# that member's own event emails.
class EventMutesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @society = societies(:whiskey_lovers)
    @member = users(:jane)
    @other = users(:one)
    @event = Event.create!(society: @society, organizer: users(:john), title: "Mute Night", description: "x",
                           location: "x", start_time: 5.days.from_now, end_time: 5.days.from_now + 2.hours)
    @token = EventMutesController.token_for(@member, @event)
    @member.update_columns(event_emails: true)
    @other.update_columns(event_emails: true)
  end

  test "GET shows a confirm page and changes nothing" do
    get event_mute_path(token: @token)
    assert_response :success
    assert_select "form[method=post][action=?]", event_mute_path do
      assert_select "input[type=hidden][name=token][value=?]", @token
    end
    assert @member.reload.event_emails?
  end

  test "POST without a session mutes only that member" do
    post event_mute_path, params: { token: @token }
    assert_response :success
    assert_not @member.reload.event_emails?
    assert @other.reload.event_emails?
  end

  test "RFC 8058 one-click POST body is accepted" do
    post event_mute_path(token: @token), params: { "List-Unsubscribe" => "One-Click" }
    assert_not @member.reload.event_emails?
  end

  test "a tampered token does nothing" do
    post event_mute_path, params: { token: @token + "x" }
    assert_response :redirect
    assert @member.reload.event_emails?
  end

  test "an RSVP token cannot be used as a mute token" do
    rsvp_token = EmailRsvpsController.token_for(@member, @event)
    post event_mute_path, params: { token: rsvp_token }
    assert @member.reload.event_emails?
  end

  test "a mute token cannot be used to RSVP" do
    assert_no_difference -> { EventRsvp.count } do
      post email_rsvp_path("yes"), params: { token: @token }
    end
  end
end
