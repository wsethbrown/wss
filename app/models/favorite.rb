# A user's private bookmark on a Society or User — visible only to the owner
# (ProfilesController only sets @favorites on your own profile). Favoriting a
# Society is gated by the same rule as viewing it (SocietyPolicy#show?).
class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :favoritable, polymorphic: true

  validates :favoritable_id, uniqueness: { scope: [:user_id, :favoritable_type] }
  validate :not_yourself
  validate :society_must_be_visible, if: -> { favoritable.is_a?(Society) }

  private

  def not_yourself
    errors.add(:favoritable, "can't be yourself") if favoritable.is_a?(User) && favoritable_id == user_id
  end

  def society_must_be_visible
    errors.add(:favoritable, "isn't visible to you") unless SocietyPolicy.new(user, favoritable).show?
  end
end
