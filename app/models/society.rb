class Society < ApplicationRecord
  belongs_to :creator, class_name: 'User'

  # Active Storage attachments
  has_one_attached :profile_picture
  has_one_attached :banner_image

  # Associations
  has_many :society_memberships, dependent: :destroy
  has_many :members, through: :society_memberships, source: :user
  has_many :events, dependent: :destroy
  has_many :admins, -> { where(society_memberships: { role: 'admin', status: 'active' }) },
           through: :society_memberships, source: :user
  has_many :officers, -> { where(society_memberships: { role: 'officer', status: 'active' }) },
           through: :society_memberships, source: :user
  has_many :society_applications, dependent: :destroy
  has_many :favorites, as: :favoritable, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, length: { maximum: 1000 }
  validates :location, length: { maximum: 200 }
  validates :is_private, inclusion: { in: [true, false] }

  # Scopes
  scope :active, -> { joins(:society_memberships).where(society_memberships: { status: 'active' }).distinct }
  scope :public_societies, -> { where(is_private: false) }
  scope :private_societies, -> { where(is_private: true) }
  scope :by_location, ->(location) { where('location ILIKE ?', "%#{location}%") if location.present? }
  scope :search, ->(query) { where('name ILIKE :q OR description ILIKE :q', q: "%#{sanitize_sql_like(query)}%") if query.present? }

  # Callbacks
  after_create :add_creator_as_admin

  # Instance methods
  def member_count
    society_memberships.where(status: 'active').count
  end

  def admin_count
    society_memberships.where(role: 'admin', status: 'active').count
  end

  def officer_count
    society_memberships.where(role: 'officer', status: 'active').count
  end

  def upcoming_events
    events.where('start_time > ?', Time.current).order(:start_time)
  end

  def past_events
    events.where('start_time < ?', Time.current).order(start_time: :desc)
  end

  def has_admin?(user)
    return false unless user
    society_memberships.exists?(user: user, role: 'admin', status: 'active')
  end

  def has_officer?(user)
    return false unless user
    society_memberships.exists?(user: user, role: 'officer', status: 'active')
  end

  def has_member?(user)
    return false unless user
    society_memberships.exists?(user: user, status: 'active')
  end

  def can_manage?(user)
    return false unless user
    society_memberships.exists?(user: user, role: ['admin', 'officer'], status: 'active')
  end

  def pending_applications
    society_applications.where(status: 'pending')
  end

  # Shareable invite link token. Lazily generated; regenerating revokes old links.
  def invite_token!
    update!(invite_token: SecureRandom.urlsafe_base64(12)) if invite_token.blank?
    invite_token
  end

  def regenerate_invite_token!
    update!(invite_token: SecureRandom.urlsafe_base64(12))
  end

  def public?
    !is_private
  end

  def private?
    is_private
  end

  # How many members follow (favorite) this society, counter-cache column.
  def followers_count = favorites_count

  # Century badge: 100+ followers, same threshold as tasters.
  def century? = followers_count >= User::CENTURY_THRESHOLD

  private

  def add_creator_as_admin
    society_memberships.create!(
      user: creator,
      role: :admin,
      status: :active
    )
  end
end
