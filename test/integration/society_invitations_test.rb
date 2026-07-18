require "test_helper"

# Society email invitations (owner-approved, July 2026): managers invite an
# existing account by email; the invitee gets a notification + email and
# answers from /notifications; the inviter is notified of the answer; three
# declines close the door for that society.
class SocietyInvitationsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @admin = users(:john)
    @invitee = users(:jane)
    @society = Society.create!(name: "Invite Club", description: "x", creator: @admin, is_private: false)
  end

  def invite!(by: @admin, email: @invitee.email)
    sign_in by
    post society_invitations_path, params: { society_id: @society.id, email: email }
  end

  test "a manager invites an existing account: invitation, notification, email" do
    assert_difference "SocietyInvitation.count", 1 do
      assert_enqueued_emails 1 do
        invite!
      end
    end
    invitation = SocietyInvitation.last
    assert_equal "pending", invitation.status
    assert_equal @admin, invitation.invited_by
    notification = @invitee.notifications.find_by(action: "society_invite")
    assert_equal invitation, notification.notifiable
  end

  test "a non-manager cannot invite" do
    outsider = users(:one)
    sign_in outsider
    assert_no_difference "SocietyInvitation.count" do
      post society_invitations_path, params: { society_id: @society.id, email: @invitee.email }
    end
  end

  test "an unknown email creates nothing and points at the invite link" do
    assert_no_difference "SocietyInvitation.count" do
      invite!(email: "stranger@example.com")
    end
    assert_match "No account uses", flash[:alert]
  end

  test "an active member cannot be re-invited" do
    SocietyMembership.create!(user: @invitee, society: @society, role: "member", status: "active")
    assert_no_difference "SocietyInvitation.count" do
      invite!
    end
  end

  test "a second pending invitation is refused" do
    invite!
    assert_no_difference "SocietyInvitation.count" do
      invite!
    end
  end

  test "accepting joins the society and notifies the inviter" do
    invite!
    invitation = SocietyInvitation.last
    sign_in @invitee
    assert_enqueued_emails 1 do
      patch accept_society_invitation_path(invitation)
    end
    assert_equal "accepted", invitation.reload.status
    assert @society.society_memberships.exists?(user: @invitee, status: "active")
    assert @admin.notifications.exists?(action: "invite_accepted", actor: @invitee)
  end

  test "accepting works for a private society" do
    @society.update!(is_private: true)
    invite!
    invitation = SocietyInvitation.last
    sign_in @invitee
    patch accept_society_invitation_path(invitation)
    assert @society.society_memberships.exists?(user: @invitee, status: "active")
  end

  test "declining notifies the inviter and does not join" do
    invite!
    invitation = SocietyInvitation.last
    sign_in @invitee
    patch decline_society_invitation_path(invitation)
    assert_equal "declined", invitation.reload.status
    assert_not @society.society_memberships.exists?(user: @invitee, status: "active")
    assert @admin.notifications.exists?(action: "invite_declined", actor: @invitee)
  end

  test "only the invitee can respond" do
    invite!
    invitation = SocietyInvitation.last
    sign_in users(:one)
    patch accept_society_invitation_path(invitation)
    assert_response :not_found
    assert_equal "pending", invitation.reload.status
  end

  test "three declines close the door" do
    3.times do
      invite!
      sign_in @invitee
      patch decline_society_invitation_path(SocietyInvitation.last)
    end
    assert_no_difference "SocietyInvitation.count" do
      invite!
    end
    assert_match "declined 3 invitations", flash[:alert]
  end
end
