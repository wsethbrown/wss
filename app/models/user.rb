class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :societies, foreign_key: :creator_id, dependent: :destroy
  has_many :society_memberships, dependent: :destroy
  has_many :member_societies, through: :society_memberships, source: :society
  has_many :society_applications, dependent: :destroy
  has_many :events, foreign_key: :organizer_id, dependent: :destroy
  has_many :event_rsvps, dependent: :destroy
  has_many :rsvped_events, through: :event_rsvps, source: :event
  has_many :presentations, foreign_key: :author_id, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Scopes
  scope :active, -> { where.not(encrypted_password: [nil, '']) }

  # Instance methods
  def full_name
    email.split('@').first.titleize
  end

  def admin?
    # For now, simple admin check - can be enhanced later
    email.end_with?('@whiskeysharesociety.com')
  end

  def member_of?(society)
    society_memberships.exists?(society: society, status: 'active')
  end

  def admin_of?(society)
    society_memberships.exists?(society: society, role: 'admin', status: 'active')
  end

  def officer_of?(society)
    society_memberships.exists?(society: society, role: 'officer', status: 'active')
  end

  def can_manage?(society)
    society_memberships.exists?(society: society, role: ['admin', 'officer'], status: 'active')
  end

  def can_manage_officers?(society)
    society_memberships.exists?(society: society, role: 'admin', status: 'active')
  end

  def applied_to?(society)
    society_applications.exists?(society: society)
  end

  def pending_application_for?(society)
    society_applications.exists?(society: society, status: 'pending')
  end

  def rsvped_to?(event)
    event_rsvps.exists?(event: event, status: 'confirmed')
  end

  def admin_societies
    societies.joins(:society_memberships).where(society_memberships: { user: self, role: 'admin', status: 'active' })
  end

  def officer_societies
    member_societies.joins(:society_memberships).where(society_memberships: { user: self, role: 'officer', status: 'active' })
  end

  def managed_societies
    member_societies.joins(:society_memberships).where(society_memberships: { user: self, role: ['admin', 'officer'], status: 'active' })
  end
end
