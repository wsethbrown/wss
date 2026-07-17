# One entry on a user's public whiskey shelf. Linked entries point at a real
# Bottle; free-text entries keep whatever the user typed (custom_name) and
# deliberately never create catalog records — the shelf is low-intent input,
# so cataloging stays behind the explicit "Add a review" flow.
class ShelfItem < ApplicationRecord
  belongs_to :user
  belongs_to :bottle, optional: true

  validates :position, presence: true
  validates :custom_name, length: { maximum: 200 }
  validate :exactly_one_source
  validates :bottle_id, uniqueness: { scope: :user_id }, if: -> { bottle_id.present? }
  validate :custom_name_unique_for_user, if: -> { custom_name.present? }

  scope :ordered, -> { order(:position, :id) }

  def display_name
    bottle ? bottle.name : custom_name
  end

  private

  def exactly_one_source
    if bottle_id.present? == custom_name.present?
      errors.add(:base, "Shelf entries need a bottle or a name")
    end
  end

  def custom_name_unique_for_user
    clash = ShelfItem.where(user_id: user_id)
                     .where("lower(custom_name) = ?", custom_name.downcase)
    clash = clash.where.not(id: id) if persisted?
    errors.add(:custom_name, "is already on your shelf") if clash.exists?
  end
end
