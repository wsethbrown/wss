class SocietyApplication < ApplicationRecord
  belongs_to :user
  belongs_to :society

  # Enums
  enum :status, pending: :pending, approved: :approved, rejected: :rejected

  # Validations
  validates :user_id, uniqueness: { scope: :society_id, message: 'has already applied to this society' }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :message, length: { maximum: 1000 }

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  # Callbacks
  before_validation :set_default_status, on: :create
  after_update :handle_status_change, if: :saved_change_to_status?

  # Instance methods
  def approve!
    update!(status: 'approved')
  end

  def reject!
    update!(status: 'rejected')
  end

  def pending?
    status == 'pending'
  end

  def approved?
    status == 'approved'
  end

  def rejected?
    status == 'rejected'
  end

  private

  def set_default_status
    self.status ||= :pending
  end

  def handle_status_change
    case status
    when 'approved'
      # Create membership when application is approved
      society.society_memberships.create!(
        user: user,
        role: :member,
        status: :active
      )
    when 'rejected'
      # Could send notification to user about rejection
      # For now, just leave as rejected
    end
  end
end
