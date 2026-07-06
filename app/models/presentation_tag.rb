class PresentationTag < ApplicationRecord
  belongs_to :presentation
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :presentation_id }
end
