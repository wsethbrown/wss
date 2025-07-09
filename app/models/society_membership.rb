class SocietyMembership < ApplicationRecord
  belongs_to :user
  belongs_to :society

  # Enums
  enum :role, member: :member, admin: :admin, officer: :officer
  enum :status, active: :active, inactive: :inactive, banned: :banned

  # Validations
  validates :user_id, uniqueness: { scope: :society_id, message: 'is already a member of this society' }
  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :status, presence: true, inclusion: { in: statuses.keys }

  # Note: Rails generates scopes automatically for enums
  # .member, .admin, .officer, .active, .inactive, .banned are available
  scope :active_members, -> { active }
  scope :admins, -> { admin.active }
  scope :officers, -> { officer.active }
  scope :managers, -> { where(role: [:admin, :officer]).active }

  # Instance methods
  def admin?
    role == 'admin'
  end

  def officer?
    role == 'officer'
  end

  def can_manage?
    admin? || officer?
  end

  def can_manage_officers?
    admin? # Only admins can manage officers
  end
end
