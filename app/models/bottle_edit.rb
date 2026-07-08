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

  validates :field, inclusion: { in: FIELDS }
  validates :status, inclusion: { in: STATUSES }
  validates :proposed_value, presence: true
  validates :user_id, uniqueness: {
    scope: [ :bottle_id, :field ],
    conditions: -> { where(status: "pending") },
    message: "has already been taken"
  }, if: -> { status == "pending" }

  scope :pending, -> { where(status: "pending") }
  scope :for_field, ->(field) { where(field: field) }
end
