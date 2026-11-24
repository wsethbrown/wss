# An address that asked to hear when a new deck is published. No account is
# involved, and this has nothing to do with paid membership ("subscription" in
# this app); user-facing copy never calls it one.
#
# Rows are written only by MailingList::SignupService. The email is personal
# data: never log it (log the row id).
class MailingListSubscriber < ApplicationRecord
  SOURCE_MAX = 30

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }
  validates :source, length: { maximum: SOURCE_MAX }

  # On the list: confirmed from the emailed link and not unsubscribed since.
  scope :active, -> { where.not(confirmed_at: nil).where(unsubscribed_at: nil) }
  scope :awaiting_confirmation, -> { where(confirmed_at: nil, unsubscribed_at: nil) }
  scope :unsubscribed, -> { where.not(unsubscribed_at: nil) }

  def active?
    confirmed_at.present? && unsubscribed_at.nil?
  end
end
