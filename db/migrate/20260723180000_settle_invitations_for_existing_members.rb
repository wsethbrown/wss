# Backfill for the "member still shows as Awaiting reply" bug: before the
# SocietyMembership callback existed, joining via the shareable invite link (or
# any path other than accepting the admin invitation) created a membership but
# left a separate pending admin invitation behind, so the person lingered in
# their society's "Awaiting reply" list forever.
#
# This resolves those stale rows: any pending invitation whose user is already
# an active member of that society is marked accepted. Quiet by design (raw
# UPDATE, no notifications) — these people joined long ago.
class SettleInvitationsForExistingMembers < ActiveRecord::Migration[8.0]
  def up
    resolved = execute(<<~SQL).cmd_tuples
      UPDATE society_invitations inv
      SET status = 'accepted', responded_at = NOW()
      FROM society_memberships m
      WHERE inv.status = 'pending'
        AND m.user_id = inv.user_id
        AND m.society_id = inv.society_id
        AND m.status = 'active'
    SQL
    say "Settled #{resolved} pending invitation(s) whose invitee was already a member"
  end

  def down
    # One-way cleanup: there's no honest way to tell which accepted invitations
    # were originally these, and reverting would resurrect the bug.
  end
end
