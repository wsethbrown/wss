require "test_helper"

# A member who joined a society by any path — the shareable link, an admin add,
# accepting the invitation — must not linger in that society's "Awaiting reply"
# list. The SocietyMembership callback settles any pending admin invitation
# whenever someone becomes a member. (Regression: Ethan Frank showed pending
# while being a member, because he joined via the invite link.)
class SocietyInvitationSettlingTest < ActiveSupport::TestCase
  setup do
    @owner = users(:john)
    @invitee = users(:jane)
    @society = Society.create!(name: "Settling Club", description: "x", creator: @owner, is_private: false)
  end

  def invite!
    SocietyInvitation.create!(society: @society, user: @invitee, invited_by: @owner, status: "pending")
  end

  test "joining via any membership path settles a pending invitation" do
    invitation = invite!
    assert @society.society_invitations.pending.exists?(user: @invitee)

    # The invite-link path: a membership created directly, NOT through accept!.
    @society.society_memberships.create!(user: @invitee, role: :member, status: :active)

    assert_not @society.society_invitations.pending.exists?(user: @invitee),
               "a member must not still be awaiting reply"
    assert_equal "accepted", invitation.reload.status
    assert invitation.responded_at.present?
  end

  test "settling does not re-notify the inviter" do
    invite!
    # accept! sends the "they accepted" mail/notification; joining another way
    # must not, or every link-join would spam the inviter.
    assert_no_difference "Notification.where(action: 'invite_accepted').count" do
      @society.society_memberships.create!(user: @invitee, role: :member, status: :active)
    end
  end

  test "a membership activated later also settles the invitation" do
    invitation = invite!
    membership = @society.society_memberships.create!(user: @invitee, role: :member, status: :inactive)
    # An inactive membership is not a join, so the invitation stays pending.
    assert_equal "pending", invitation.reload.status

    membership.update!(status: :active)
    assert_equal "accepted", invitation.reload.status
  end

  test "other people's pending invitations are untouched" do
    invite!
    other = users(:admin)
    other_invitation = SocietyInvitation.create!(society: @society, user: other, invited_by: @owner, status: "pending")

    @society.society_memberships.create!(user: @invitee, role: :member, status: :active)
    assert_equal "pending", other_invitation.reload.status, "only the joiner's invitation settles"
  end
end
