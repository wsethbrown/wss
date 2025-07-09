class UserTag < ApplicationRecord
  belongs_to :user
  belongs_to :tag

  validates :user_id, uniqueness: { scope: :tag_id }

  scope :by_category, ->(category) { joins(:tag).where(tags: { category: category }) }
  scope :whiskey, -> { by_category("whiskey") }
  scope :interests, -> { by_category("interests") }
  scope :skills, -> { by_category("skills") }
end
