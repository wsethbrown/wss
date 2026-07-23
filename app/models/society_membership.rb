class SocietyMembership < ApplicationRecord
  belongs_to :user
  belongs_to :society

  # Enums
  enum :role, { member: "member", admin: "admin", officer: "officer" }
  enum :status, { active: "active", inactive: "inactive", banned: "banned" }

  # Every path into a society (public join, invite link, email invitation,
  # admin add) lands here, so the Activity ledger records joins at the model.
  # Leaves/removals/role changes are recorded in their controllers, where
  # the acting user is known.
  # Plain (non-commit) callbacks on purpose: the ledger row lives and dies
  # inside the same transaction as the membership itself.
  after_create :record_join_activity, if: :active?
  after_update :record_join_activity, if: -> { active? && saved_change_to_status? }

  # However someone became a member — accepting the admin invitation, using the
  # shareable link, or being added — any still-pending admin invitation for them
  # is now moot. Resolving it here, at the one place every join lands, keeps a
  # member from lingering in a society's "Awaiting reply" list. accept! already
  # marks its own invitation, so this only catches the OTHER paths.
  after_create :settle_pending_invitations, if: :active?
  after_update :settle_pending_invitations, if: -> { active? && saved_change_to_status? }

  # Validations
  validates :user_id, uniqueness: { scope: :society_id, message: "is already a member of this society" }
  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :status, presence: true, inclusion: { in: statuses.keys }

  # Note: Rails generates scopes automatically for enums
  # .member, .admin, .officer, .active, .inactive, .banned are available
  scope :active_members, -> { active }
  scope :admins, -> { admin.active }
  scope :officers, -> { officer.active }
  scope :managers, -> { where(role: [ :admin, :officer ]).active }

  # Instance methods
  def admin?
    role == "admin"
  end

  def officer?
    role == "officer"
  end

  def can_manage?
    admin? || officer?
  end

  def can_manage_officers?
    admin? # Only admins can manage officers
  end

  private

  def record_join_activity
    SocietyActivity.record!(society: society, user: user, action: "joined")
  end

  # Quietly mark any pending admin invitation as accepted: update_all skips
  # validations and callbacks on purpose, so it can't re-send the inviter the
  # "they accepted" email — they joined another way, and the join itself is
  # already recorded.
  def settle_pending_invitations
    resolved = society.society_invitations.pending.where(user_id: user_id)
                      .update_all(status: "accepted", responded_at: Time.current)
    Rails.logger.info "Society #{society_id}: #{resolved} pending invitation(s) settled by user #{user_id} joining" if resolved.positive?
  end
end
