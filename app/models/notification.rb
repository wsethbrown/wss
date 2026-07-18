# In-app notifications (owner-approved, July 2026). One row per thing worth
# telling a user about; the bell in the nav counts unread, /notifications
# lists and clears them. Keep ACTIONS in sync with the text/link mapping in
# NotificationsHelper — an action without a renderer shows nothing.
class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  ACTIONS = %w[follow review_vote event_created society_invite invite_accepted invite_declined].freeze

  validates :action, inclusion: { in: ACTIONS }

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # Idempotent kinds: re-following or re-liking must not stack rows.
  DEDUPED_ACTIONS = %w[follow review_vote].freeze

  def self.notify!(user:, action:, actor: nil, notifiable: nil)
    return if user.nil? || (actor && user.id == actor.id)

    attrs = { user: user, actor: actor, notifiable: notifiable, action: action }
    if DEDUPED_ACTIONS.include?(action)
      find_or_create_by!(attrs)
    else
      create!(attrs)
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    Rails.logger.error "Notification skipped (#{action}) for user #{user.id}, actor #{actor&.id}, #{notifiable ? "#{notifiable.class.name}##{notifiable.id}" : 'no notifiable'}: #{e.message}"
    nil
  end

  def read?
    read_at.present?
  end
end
