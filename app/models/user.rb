class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2, :apple ]

  # OAuth methods
  def self.from_omniauth(auth)
    # First, try to find existing user with this exact provider and uid
    existing_user = where(provider: auth.provider, uid: auth.uid).first

    if existing_user
      return existing_user
    end

    # Check if there's an existing user with this email
    user_by_email = find_by(email: auth.info.email)

    if user_by_email
      # User exists with this email - check their OAuth status
      if user_by_email.provider.blank?
        # User has no OAuth provider yet, safe to add this one
        user_by_email.update!(
          provider: auth.provider,
          uid: auth.uid,
          first_name: auth.info.first_name || auth.info.name&.split(" ")&.first,
          last_name: auth.info.last_name || auth.info.name&.split(" ")&.last
        )
        return user_by_email
      elsif user_by_email.provider == auth.provider
        # Same provider, update uid if needed
        user_by_email.update!(uid: auth.uid) if user_by_email.uid != auth.uid
        return user_by_email
      else
        # User already has a different OAuth provider
        # For now, we'll reject the login and show an error
        Rails.logger.warn "User #{auth.info.email} already exists with provider #{user_by_email.provider}. Cannot add #{auth.provider}."
        user = User.new
        user.errors.add(:email, "This email is already associated with #{user_by_email.provider.humanize} login. Please use #{user_by_email.provider.humanize} to sign in, or use a different email address.")
        return user
      end
    end

    # No existing user found, create new one
    create!(
      email: auth.info.email,
      provider: auth.provider,
      uid: auth.uid,
      password: Devise.friendly_token[0, 20],
      password_set_manually: false,
      first_name: auth.info.first_name || auth.info.name&.split(" ")&.first,
      last_name: auth.info.last_name || auth.info.name&.split(" ")&.last
    )
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if session["devise.oauth_data"] && session["devise.oauth_data"]["extra"] && session["devise.oauth_data"]["extra"]["raw_info"]
        data = session["devise.oauth_data"]["extra"]["raw_info"]
        user.email = data["email"] if user.email.blank?
        user.first_name = data["first_name"] if user.first_name.blank?
        user.last_name = data["last_name"] if user.last_name.blank?
      end
    end
  end

  # Instance methods
  def full_name
    if first_name.present? && last_name.present?
      "#{first_name} #{last_name}"
    elsif first_name.present?
      first_name
    elsif last_name.present?
      last_name
    else
      email.split("@").first.titleize
    end
  end

  def display_name
    full_name
  end

  # Active Storage
  has_one_attached :profile_image

  # Profile image validation
  validate :profile_image_validation

  # Associations
  has_many :societies, foreign_key: :creator_id, dependent: :destroy
  has_many :society_memberships, dependent: :destroy
  has_many :member_societies, through: :society_memberships, source: :society
  has_many :society_applications, dependent: :destroy
  has_many :events, foreign_key: :organizer_id, dependent: :destroy
  has_many :event_rsvps, dependent: :destroy
  has_many :rsvped_events, through: :event_rsvps, source: :event
  has_many :presentations, foreign_key: :author_id, dependent: :destroy
  has_many :user_presentations, dependent: :destroy
  has_many :purchased_presentations, through: :user_presentations, source: :presentation
  has_many :user_tags, dependent: :destroy
  has_many :tags, through: :user_tags
  has_many :credit_transactions, dependent: :destroy
  has_many :activity_logs, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :shelf_items, -> { order(:position, :id) }, dependent: :destroy
  has_many :review_votes, dependent: :destroy
  has_many :review_reports, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :favorited_societies, -> { where(favorites: { favoritable_type: "Society" }) }, through: :favorites, source: :favoritable, source_type: "Society"
  has_many :favorited_users, -> { where(favorites: { favoritable_type: "User" }) }, through: :favorites, source: :favoritable, source_type: "User"
  has_many :favorited_by_records, class_name: "Favorite", as: :favoritable, dependent: :destroy # cleans up favorites OF this user

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Scopes
  scope :active, -> { where.not(encrypted_password: [ nil, "" ]) }


  # ---- Founding Members (first 50, owner-approved July 2026) ----------------
  # Two founding shapes, both consuming one of the 50 slots: the $5/mo
  # society-only plan (founding_society, NO deck credits) and the $5-off full
  # monthly plan (founding_monthly). Status is kept while the subscription
  # never CANCELS; pausing is fine. Revocation is permanent.
  FOUNDING_MEMBER_CAP = 50
  FOUNDING_PLANS = %w[founding_society founding_monthly].freeze

  def self.founding_slots_remaining
    [FOUNDING_MEMBER_CAP - where(founding_member: true).count, 0].max
  end

  # Eligible to TAKE a founding offer: never revoked, not already founding.
  def founding_eligible?
    !founding_member? && founding_revoked_at.nil?
  end

  # The $5 society-only plan runs societies but earns NO deck credits.
  def society_only_plan?
    subscription_plan == "founding_society"
  end

  # Admin role tiers, assigned via console. `full` can do everything including
  # hard-deleting records; `limited` is a full admin minus delete rights; `none`
  # is a normal user. admin_role is the single source of truth for admin access.
  enum :admin_role, { none: "none", limited: "limited", full: "full" }, prefix: :admin_role

  # Site-wide admin gate: any admin tier (limited or full).
  def admin?
    !admin_role_none?
  end

  # Only full admins may hard-delete records (decks, bottles, reviews, events,
  # users). Limited admins retain every other admin power.
  def can_delete?
    admin_role_full?
  end

  def member_of?(society)
    society_memberships.exists?(society: society, status: :active)
  end

  def admin_of?(society)
    society_memberships.exists?(society: society, role: :admin, status: :active)
  end

  def officer_of?(society)
    society_memberships.exists?(society: society, role: :officer, status: :active)
  end

  def can_manage?(society)
    society_memberships.exists?(society: society, role: [ :admin, :officer ], status: :active)
  end

  def can_manage_officers?(society)
    society_memberships.exists?(society: society, role: :admin, status: :active)
  end

  def applied_to?(society)
    society_applications.exists?(society: society)
  end

  def pending_application_for?(society)
    society_applications.exists?(society: society, status: "pending")
  end

  def favorite?(record) = favorites.exists?(favoritable: record)

  # How many members follow (favorite) this user. The count is public; who
  # follows whom stays private, favorites are only ever listed to their owner.
  # Reads the counter-cache column so per-row checks (review lists) stay O(1).
  def followers_count = favorites_count

  # Century badge: 100+ followers marks a taster whose reviews carry weight.
  CENTURY_THRESHOLD = 100
  def century? = followers_count >= CENTURY_THRESHOLD

  def rsvped_to?(event)
    event_rsvps.exists?(event: event, status: "confirmed")
  end

  def admin_societies
    societies.joins(:society_memberships).where(society_memberships: { user: self, role: :admin, status: :active })
  end

  def officer_societies
    member_societies.joins(:society_memberships).where(society_memberships: { user: self, role: :officer, status: :active })
  end

  def managed_societies
    member_societies.joins(:society_memberships).where(society_memberships: { user: self, role: [ :admin, :officer ], status: :active })
  end

  def administered_societies
    # Returns societies where the user can create events (created societies + admin/officer roles)
    Society.left_joins(:society_memberships)
           .where(
             "(societies.creator_id = ? OR " +
             "(society_memberships.user_id = ? AND society_memberships.role IN (?) AND society_memberships.status = ?))",
             id, id, [ "admin", "officer" ], "active"
           )
           .distinct
  end

  # Tag helper methods
  def tags_by_category(category)
    tags.where(category: category)
  end

  def whiskey_tags
    tags_by_category("whiskey")
  end

  def interest_tags
    tags_by_category("interests")
  end

  def skill_tags
    tags_by_category("skills")
  end

  def has_tag?(tag_name)
    tags.exists?(name: tag_name)
  end

  def add_tag(tag_name)
    tag = Tag.find_or_create_by(name: tag_name)
    user_tags.find_or_create_by(tag: tag) unless has_tag?(tag_name)
  end

  def remove_tag(tag_name)
    tag = Tag.find_by(name: tag_name)
    user_tags.where(tag: tag).destroy_all if tag
  end

  # Profile image helper methods
  def profile_image_url
    if profile_image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(profile_image, only_path: true)
    else
      nil
    end
  end

  def has_profile_image?
    profile_image.attached?
  end

  # Email change helper methods
  def has_pending_email_change?
    unconfirmed_email.present? && email_change_token.present? && email_change_token_expires_at&.future?
  end

  def pending_email_change_expired?
    unconfirmed_email.present? && email_change_token.present? && email_change_token_expires_at&.past?
  end

  def clear_expired_email_change
    if pending_email_change_expired?
      update!(unconfirmed_email: nil, email_change_token: nil, email_change_token_expires_at: nil)
    end
  end

  # TOTP secret and backup codes are encrypted at rest (ActiveRecord encryption;
  # keys in env, see config/initializers/active_record_encryption.rb).
  encrypts :otp_secret_key
  encrypts :backup_codes

  # 2FA helper methods
  def two_factor_enabled?
    otp_enabled? && otp_secret_key.present?
  end

  def otp_required_for_login?
    two_factor_enabled?
  end

  # Authentication method helpers
  def has_password?
    password_set_manually? && encrypted_password.present?
  end

  def passwordless_only?
    !password_set_manually?
  end

  def authentication_methods
    methods = []
    methods << "Magic Link" # All users have magic link capability
    methods << "Password" if has_password?
    methods
  end

  def primary_authentication_method
    return "Magic Link Only" if passwordless_only?
    "Magic Link + Password"
  end

  # Subscription helper methods
  def has_active_subscription?
    subscription_status == "active" && (subscription_ends_at.nil? || subscription_ends_at.future?)
  end

  def subscription_paused?
    subscription_paused_at.present?
  end

  def subscription_can_be_paused?
    has_active_subscription? && !subscription_paused?
  end

  def subscription_can_be_resumed?
    subscription_paused?
  end

  def subscription_status_display
    case subscription_status
    when "active"
      subscription_paused? ? "Paused" : "Active"
    when "paused"
      "Paused"
    when "cancelled"
      "Cancelled"
    when "past_due"
      "Past Due"
    when "incomplete"
      "Incomplete"
    when "trialing"
      "Trial"
    else
      "No Subscription"
    end
  end

  def subscription_plan_display
    case subscription_plan
    when "monthly"
      "Monthly ($19.99/month)"
    when "quarterly"
      "Quarterly ($38.97/quarter)"
    when "yearly"
      "Yearly ($119.88/year)"
    else
      "No Plan"
    end
  end

  def subscription_active?
    has_active_subscription?
  end

  def can_access_premium_content?
    has_active_subscription?
  end

  # Presentation access logic
  def owns_presentation?(presentation_id)
    user_presentations.exists?(presentation_id: presentation_id)
  end

  def can_access_presentation?(presentation_id)
    return false unless owns_presentation?(presentation_id)
    
    purchase = user_presentations.find_by(presentation_id: presentation_id)
    return false unless purchase
    
    case purchase.purchase_type
    when 'direct'
      # Direct purchases are always accessible
      true
    when 'credit'
      # Credit purchases require active subscription
      has_active_subscription?
    else
      false
    end
  end

  def presentation_access_type(presentation_id)
    purchase = user_presentations.find_by(presentation_id: presentation_id)
    return nil unless purchase
    
    case purchase.purchase_type
    when 'direct'
      'lifetime'
    when 'credit'
      has_active_subscription? ? 'subscription' : 'expired'
    else
      nil
    end
  end

  def days_until_renewal
    return nil unless subscription_ends_at
    return 0 if subscription_ends_at.past?

    (subscription_ends_at.to_date - Date.current).to_i
  end

  # Credit balance is a cache derived from the credit_transactions ledger; never write
  # it directly. Route all changes through CreditTransaction.record! and friends.
  def has_sufficient_credits?(amount)
    (credits || 0) >= amount
  end

  def next_credit_date
    # Credits are added on the 1st of each month
    return nil unless has_active_subscription?
    Date.today.next_month.beginning_of_month
  end

  def generate_otp_secret
    self.otp_secret_key = ROTP::Base32.random
  end

  def generate_backup_codes
    codes = 8.times.map { SecureRandom.hex(4).upcase }
    self.backup_codes = codes.to_json
    codes
  end

  def backup_codes_array
    backup_codes.present? ? JSON.parse(backup_codes) : []
  end

  def verify_otp(code)
    return false unless two_factor_enabled?

    # Check if it's a backup code
    if backup_codes_array.include?(code.upcase)
      # Remove used backup code
      codes = backup_codes_array
      codes.delete(code.upcase)
      update!(backup_codes: codes.to_json)
      return true
    end

    # Check TOTP code
    totp = ROTP::TOTP.new(otp_secret_key)
    totp.verify(code, drift_ahead: 30, drift_behind: 30)
  end

  def otp_qr_code
    return nil unless otp_secret_key.present?

    totp = ROTP::TOTP.new(otp_secret_key)
    issuer = "Whiskey Share Society"
    uri = totp.provisioning_uri(email, issuer_name: issuer)

    qr = RQRCode::QRCode.new(uri)
    qr.as_svg(
      module_size: 4,
      standalone: true,
      use_path: true,
      viewbox: true,
      svg_attributes: {
        class: "qr-code",
        style: "width: 200px; height: 200px;"
      }
    )
  end

  def initials
    if first_name.present? && last_name.present?
      "#{first_name[0]}#{last_name[0]}".upcase
    elsif first_name.present?
      first_name[0].upcase
    elsif last_name.present?
      last_name[0].upcase
    else
      email[0].upcase
    end
  end

  def avatar_color
    # Generate a consistent color based on the user's email
    colors = [
      "#EF4444", "#F97316", "#F59E0B", "#EAB308", "#84CC16",
      "#22C55E", "#10B981", "#14B8A6", "#06B6D4", "#0EA5E9",
      "#3B82F6", "#6366F1", "#8B5CF6", "#A855F7", "#D946EF",
      "#EC4899", "#F43F5E"
    ]

    # Use a simple hash of the email to pick a color
    hash = email.sum { |char| char.ord }
    colors[hash % colors.length]
  end

  private

  def profile_image_validation
    return unless profile_image.attached?

    # Check content type
    unless profile_image.content_type.in?(%w[image/jpeg image/jpg image/png image/gif image/webp])
      errors.add(:profile_image, "must be a valid image format")
    end

    # Check file size
    if profile_image.byte_size > 5.megabytes
      errors.add(:profile_image, "must be less than 5MB")
    end
  end
end
