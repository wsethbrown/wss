# A community-proposed correction to one field on a bottle. Lives as
# "pending" until enough distinct users agree on the identical value
# (BottleEdits::AutoApply, Task 3) or an admin applies/rejects it by hand
# (Admin::BottleEditsController, Task 4). Applied/rejected rows are kept —
# they're the "who proposed, when applied" audit trail, not scratch data.
class BottleEdit < ApplicationRecord
  FIELDS = %w[name distillery region style abv].freeze
  STATUSES = %w[pending applied rejected].freeze

  belongs_to :bottle
  belongs_to :user
  belongs_to :applied_by, class_name: "User", optional: true

  # Normalization IS the grouping contract: identical proposals must store
  # byte-identical proposed_value ("45"/"45.0"/"45.00" are ONE abv proposal).
  # Controllers normalize too, but enforcing it here means no write path —
  # console, import, future feature — can silently split a vote group.
  before_validation :normalize_proposed_value

  validates :field, inclusion: { in: FIELDS }
  validates :status, inclusion: { in: STATUSES }
  # Length cap: the whitelisted bottle columns cap at 200; without a cap
  # here a signed-in user could store multi-MB strings that the admin
  # proposals page then renders inline.
  validates :proposed_value, presence: true, length: { maximum: 500 }
  validates :user_id, uniqueness: {
    scope: [ :bottle_id, :field ],
    conditions: -> { where(status: "pending") },
    message: "has already been taken"
  }, if: -> { status == "pending" }

  scope :pending, -> { where(status: "pending") }
  scope :for_field, ->(field) { where(field: field) }

  private

  def normalize_proposed_value
    return if field.blank? || proposed_value.blank?

    self.proposed_value = BottleEdits::Normalize.for_storage(field, proposed_value)
  end
end
