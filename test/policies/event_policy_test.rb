require "test_helper"

# B1: who may RSVP. The public-society rule is one switch
# (Event::PUBLIC_EVENTS_OPEN_TO_NON_MEMBERS) pending an owner decision.
class EventPolicyTest < ActiveSupport::TestCase
  setup do
    st = 5.days.from_now
    @private_event = Event.create!(society: societies(:bourbon_club), organizer: users(:jane), title: "Private Night",
                                   description: "x", location: "x", start_time: st, end_time: st + 2.hours)
    @public_event = Event.create!(society: societies(:whiskey_lovers), organizer: users(:john), title: "Open Night",
                                  description: "x", location: "x", start_time: st, end_time: st + 2.hours)
  end

  test "non-members may not RSVP to a private society's event" do
    assert_not EventPolicy.new(users(:one), @private_event).rsvp?
  end

  test "members may RSVP to a private society's event" do
    assert EventPolicy.new(users(:jane), @private_event).rsvp?
  end

  test "non-members may RSVP to a public society's event (owner default)" do
    assert EventPolicy.new(users(:one), @public_event).rsvp?
  end

  test "signed out may not RSVP" do
    assert_not EventPolicy.new(nil, @public_event).rsvp?
  end

  test "create? with no society is false, not an error" do
    assert_not EventPolicy.new(users(:one), Event.new).create?
  end
end
