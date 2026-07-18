require "test_helper"

# Admin invitations (owner-requested, July 2026): an admin creates an account
# for someone and emails them a long-lived, single-use claim link. Accepting
# signs them in; afterwards they use magic link or Google like anyone else.
class Auth::InvitationServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @admin = users(:admin)
  end

  test "invite! creates the user, stores a digest, and emails the raw token" do
    result = nil
    assert_difference "User.count", 1 do
      assert_enqueued_emails 1 do
        result = Auth::InvitationService.invite!(
          email: "Nat.Test@Example.com", first_name: "Nat", last_name: "McCarty", invited_by: @admin
        )
      end
    end
    assert result.success?
    user = result.user
    assert_equal "nat.test@example.com", user.email
    assert_equal "Nat", user.first_name
    assert_equal @admin, user.invited_by
    assert user.invitation_token_digest.present?
    assert user.invitation_sent_at.present?
    assert_nil user.invitation_accepted_at
    assert_not user.password_set_manually
  end

  test "invite! refuses an email that already has an account" do
    result = nil
    assert_no_difference "User.count" do
      result = Auth::InvitationService.invite!(
        email: @admin.email, first_name: "X", last_name: "Y", invited_by: @admin
      )
    end
    assert_not result.success?
  end

  test "consume returns the user once, marks acceptance, and clears the token" do
    raw = invite_nat
    user = Auth::InvitationService.consume(raw)
    assert user
    assert user.invitation_accepted_at.present?
    assert_nil user.invitation_token_digest
    assert_nil Auth::InvitationService.consume(raw), "token must be single-use"
  end

  test "an expired invitation is rejected" do
    raw = invite_nat
    User.find_by(email: "nat.test@example.com")
        .update!(invitation_sent_at: (Auth::InvitationService::EXPIRY + 1.day).ago)
    assert_nil Auth::InvitationService.consume(raw)
  end

  test "a tampered token is rejected" do
    invite_nat
    assert_nil Auth::InvitationService.consume("forged-token")
  end

  test "resend! issues a fresh token but not for accepted accounts" do
    raw = invite_nat
    user = User.find_by(email: "nat.test@example.com")
    assert_enqueued_emails 1 do
      assert Auth::InvitationService.resend!(user).success?
    end
    assert_nil Auth::InvitationService.consume(raw), "old token must die on resend"

    user.reload.update!(invitation_accepted_at: Time.current)
    assert_not Auth::InvitationService.resend!(user).success?
  end

  private

  def invite_nat
    result = Auth::InvitationService.invite!(
      email: "nat.test@example.com", first_name: "Nat", last_name: "McCarty", invited_by: @admin
    )
    result.raw_token
  end
end
