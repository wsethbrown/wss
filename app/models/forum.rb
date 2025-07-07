class Forum < ApplicationRecord
  belongs_to :society

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :description, length: { maximum: 500 }

  # Scopes
  scope :ordered, -> { order(:name) }

  # Instance methods
  def display_name
    name.presence || "General Discussion"
  end
end
