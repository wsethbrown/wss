require "test_helper"

# B18: who may create, change, remove and see an RSVP.
class EventRsvpPolicyTest < ActiveSupport::TestCase
  setup do
    far = 5.days.from_now
    @private_event = Event.create!(society: societies(:bourbon_club), organizer: users(:jane), title: "Private Night",
                                   description: "x", location: "x", start_time: far, end_time: far + 2.hours)
    @member_rsvp = EventRsvp.create!(event: @private_event, user: users(:jane), status: "yes")
  end

  def public_event
    far = 5.days.from_now
    Event.create!(society: societies(:whiskey_lovers), organizer: users(:john), title: "Open Night",
                  description: "x", location: "x", start_time: far, end_time: far + 2.hours)
  end

  def policy(user, rsvp = @member_rsvp)
    EventRsvpPolicy.new(user, rsvp)
  end

  test "create? needs a signed-in user who may RSVP to the event" do
    assert_not policy(nil, EventRsvp.new(event: @private_event)).create?
    assert_not policy(users(:one), EventRsvp.new(event: @private_event, user: users(:one))).create?,
               "a non-member of a private society"
    assert_not policy(users(:jane), EventRsvp.new(event: @private_event, user: users(:jane))).create?,
               "jane already has an RSVP, so a second create is refused"
    assert policy(users(:one), EventRsvp.new(event: public_event, user: users(:one))).create?,
           "a signed-in non-member of a public society"
  end

  test "create? is false when the RSVP has no event" do
    assert_not policy(users(:jane), EventRsvp.new(user: users(:jane))).create?
  end

  test "only the owner changes or removes their RSVP" do
    assert policy(users(:jane)).update?
    assert policy(users(:jane)).destroy?
    assert_not policy(users(:one)).update?
    assert_not policy(users(:one)).destroy?
    assert_not policy(users(:admin)).update?, "even an admin cannot answer for someone else"
    assert_not policy(nil).update?
    assert_not policy(nil).destroy?
  end

  test "an eligible user still cannot change someone else's RSVP" do
    open_event = public_event
    theirs = EventRsvp.create!(event: open_event, user: users(:one), status: "yes")
    assert policy(users(:one), theirs).update?
    assert_not policy(users(:john), theirs).update?, "john may RSVP to this public event but not edit one's answer"
  end

  test "a removed member can no longer update an RSVP they made" do
    @private_event.society.society_memberships.where(user: users(:jane)).delete_all
    @private_event.update_columns(organizer_id: users(:admin).id)
    @private_event.society.update_columns(creator_id: users(:admin).id)
    assert_not policy(users(:jane)).update?
  end

  # The window closes when the night starts (owner decision, November 2026).
  test "nobody changes an RSVP once the response window has closed" do
    @private_event.update_columns(start_time: 1.minute.ago, end_time: 2.hours.from_now)
    assert_not policy(users(:jane)).update?
    assert_not policy(users(:jane)).destroy?
  end

  test "show? is for the organiser, society admins, site admins and the owner of the RSVP" do
    assert policy(users(:jane)).show?, "the organiser"
    assert policy(users(:admin)).show?, "a site admin"
    assert policy(users(:jane), EventRsvp.new(event: @private_event, user: users(:john))).show?
    assert_not policy(users(:one)).show?, "a stranger"
    assert_not policy(nil).show?
  end
end
