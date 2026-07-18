# A society manager invites an existing account by email (owner-approved,
# July 2026). The invitee gets an in-app notification + branded email and
# accepts or declines from /notifications; the inviter is notified of the
# answer. Three declines end it: that person cannot be invited to that
# society again. This is the admin-initiated door into a society; the
# shareable invite link (societies.invite_token) remains the self-serve one.
class SocietyInvitation < ApplicationRecord
  MAX_DECLINES = 3

  belongs_to :society
  belongs_to :user
  belongs_to :invited_by, class_name: "User"

  STATUSES = %w[pending accepted declined].freeze
  validates :status, inclusion: { in: STATUSES }

  validate :not_already_member, on: :create
  validate :no_pending_invitation, on: :create
  validate :under_decline_cap, on: :create

  scope :pending, -> { where(status: "pending") }

  def accept!
    transaction do
      update!(status: "accepted", responded_at: Time.current)
      membership = society.society_memberships.find_or_initialize_by(user: user)
      membership.role ||= "member"
      membership.status = "active"
      membership.save!
    end
    Rails.logger.info "Society invitation #{id} accepted: user #{user_id} is now an active member of society #{society_id}"
    Notification.notify!(user: invited_by, actor: user, notifiable: self, action: "invite_accepted")
    SocietyActivity.record!(society: society, user: user, actor: invited_by, action: "invite_accepted")
    SocietyMailer.invitation_response(self).deliver_later
  end

  def decline!
    update!(status: "declined", responded_at: Time.current)
    Rails.logger.info "Society invitation #{id} declined by user #{user_id} (society #{society_id})"
    Notification.notify!(user: invited_by, actor: user, notifiable: self, action: "invite_declined")
    SocietyActivity.record!(society: society, user: user, actor: invited_by, action: "invite_declined")
    SocietyMailer.invitation_response(self).deliver_later
  end

  def pending?
    status == "pending"
  end

  private

  def not_already_member
    if society&.society_memberships&.exists?(user_id: user_id, status: "active")
      errors.add(:user, "is already a member of this society")
    end
  end

  def no_pending_invitation
    if society && SocietyInvitation.pending.exists?(society_id: society_id, user_id: user_id)
      errors.add(:user, "already has a pending invitation")
    end
  end

  def under_decline_cap
    if society && SocietyInvitation.where(society_id: society_id, user_id: user_id, status: "declined").count >= MAX_DECLINES
      errors.add(:user, "has declined #{MAX_DECLINES} invitations to this society and cannot be invited again")
    end
  end
end
