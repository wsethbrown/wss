require "test_helper"

class EventCommentPolicyTest < ActiveSupport::TestCase
  # Commenting permission lives on EventPolicy#comment? (society members,
  # the organizer, global admins). The window is the model's concern.
  test "society members can comment, outsiders cannot" do
    event = events(:mystery_flight) # single_malt: admin (organizer), john, seth
    assert EventPolicy.new(users(:john), event).comment?
    assert EventPolicy.new(users(:admin), event).comment?
    assert_not EventPolicy.new(users(:jane), event).comment?
    assert_not EventPolicy.new(nil, event).comment?
  end

  test "author can delete their own comment" do
    comment = EventComment.new(event: events(:mystery_flight), user: users(:john), body: "x")
    assert EventCommentPolicy.new(users(:john), comment).destroy?
    assert_not EventCommentPolicy.new(users(:seth), comment).destroy?
    assert_not EventCommentPolicy.new(nil, comment).destroy?
  end

  test "event managers can delete any comment" do
    comment = EventComment.new(event: events(:mystery_flight), user: users(:john), body: "x")
    # admin is both the organizer and a global admin; either path allows it.
    assert EventCommentPolicy.new(users(:admin), comment).destroy?
  end
end
