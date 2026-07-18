require "test_helper"

# The society Activity ledger + join notifications (owner-approved, July
# 2026): all member churn lands on the managers-only Activity page; bells
# only ring for invite-link joins and invitation flows.
class SocietyActivityTest < ActionDispatch::IntegrationTest
  setup do
    @creator = users(:john)
    @member = users(:jane)
    @society = Society.create!(name: "Ledger Club", description: "x", creator: @creator, is_private: false)
  end

  test "joining is recorded in the ledger but does not ring the bell" do
    sign_in @member
    post join_society_path(@society)
    assert @society.society_activities.exists?(user: @member, action: "joined")
    assert_not @creator.notifications.exists?(action: "member_joined"),
               "public joins must not notify admins"
  end

  test "an invite-link join is recorded AND notifies the admins" do
    sign_in @member
    get society_invite_path(@society.invite_token!)
    assert @society.society_activities.exists?(user: @member, action: "joined")
    assert @creator.notifications.exists?(action: "member_joined", actor: @member)
  end

  test "leaving is recorded" do
    SocietyMembership.create!(user: @member, society: @society, role: "member", status: "active")
    sign_in @member
    delete leave_society_path(@society)
    assert @society.society_activities.exists?(user: @member, action: "left")
  end

  test "a removal is recorded with the acting manager" do
    membership = SocietyMembership.create!(user: @member, society: @society, role: "member", status: "active")
    sign_in @creator
    delete society_membership_path(membership)
    activity = @society.society_activities.find_by(user: @member, action: "removed")
    assert_equal @creator, activity.actor
  end

  test "a role change is recorded" do
    membership = SocietyMembership.create!(user: @member, society: @society, role: "member", status: "active")
    sign_in @creator
    patch society_membership_path(membership, role: "officer")
    assert @society.society_activities.exists?(user: @member, action: "role_changed")
  end

  test "the activity page is managers-only" do
    SocietyMembership.create!(user: @member, society: @society, role: "member", status: "active")
    sign_in @creator
    get activity_society_path(@society)
    assert_response :success
    assert_match "Member activity", response.body

    sign_in @member
    get activity_society_path(@society)
    assert_response :redirect
  end
end

# Hosts run the night: they manage the pour list and see hidden pours,
# but gain no event-edit rights from it.
class HostPoursTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = users(:john)
    @host = users(:jane)
    @society = Society.create!(name: "Pour Club", description: "x", creator: @organizer, is_private: false)
    SocietyMembership.create!(user: @host, society: @society, role: "member", status: "active")
    st = 3.days.from_now
    @event = Event.create!(society: @society, organizer: @organizer, title: "Pour Night",
                           description: "x", location: "den", start_time: st, end_time: st + 2.hours,
                           host: @host, pours_hidden_until_complete: true)
    @bottle = Bottle.create!(name: "Host Test Dram", created_by: @organizer)
  end

  test "the host can add and remove pours" do
    sign_in @host
    assert_difference "@event.event_bottles.count", 1 do
      post event_event_bottles_path(@event), params: { event_bottle: { bottle_id: @bottle.id, label: "the blind" } }
    end
    assert_difference "@event.event_bottles.count", -1 do
      delete event_event_bottle_path(@event, @event.event_bottles.last)
    end
  end

  test "a plain member cannot manage pours" do
    outsider = users(:one)
    SocietyMembership.create!(user: outsider, society: @society, role: "member", status: "active")
    sign_in outsider
    assert_no_difference "@event.event_bottles.count" do
      post event_event_bottles_path(@event), params: { event_bottle: { bottle_id: @bottle.id } }
    end
  end

  test "the host sees hidden pours before the reveal" do
    assert @event.pours_visible_to?(@host)
    assert_not @event.pours_visible_to?(users(:one))
  end
end
