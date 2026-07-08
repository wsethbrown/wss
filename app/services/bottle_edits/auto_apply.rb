# BottleEdits::AutoApply — runs after a proposal is created (see
# Bottles::EditsController#create, Task 5). Checks whether any proposed
# value for the given bottle+field now has enough DISTINCT proposing users
# to auto-apply; if so, writes it onto the bottle, marks the winning rows
# applied, and clears (rejects) every other pending proposal on that field
# — competing values included, per spec.
module BottleEdits
  class AutoApply
    def self.call(bottle:, field:) = new(bottle, field).call

    def initialize(bottle, field)
      @bottle = bottle
      @field = field
    end

    def call
      # MIN(created_at) rides along for the tie rule: most distinct users
      # wins; a tie goes to the earliest-created group. Without it,
      # Hash ordering out of GROUP BY is plan-dependent — nondeterministic.
      groups = BottleEdit.pending.for_field(@field).where(bottle: @bottle)
                          .group(:proposed_value)
                          .pluck(Arel.sql("proposed_value, COUNT(DISTINCT user_id), MIN(created_at)"))
      threshold = Rails.application.config.x.bottle_edits.auto_apply_threshold
      winning_value, distinct_count, _earliest =
        groups.min_by { |_value, count, earliest| [ -count, earliest ] }
      return false if winning_value.nil? || distinct_count < threshold

      apply(winning_value)
    end

    private

    # Explicit flag rather than relying on transaction/save return values —
    # a failed bottle save (e.g., an out-of-range abv) must leave every
    # proposal row untouched and report false, not partially update rows.
    def apply(winning_value)
      applied = false
      ActiveRecord::Base.transaction do
        @bottle[@field] = BottleEdits::Normalize.for_write(@field, winning_value)
        if @bottle.save
          applied = true
          pending = BottleEdit.pending.for_field(@field).where(bottle: @bottle)
          pending.where(proposed_value: winning_value)
                 .update_all(status: "applied", applied_at: Time.current, applied_by_id: nil)
          pending.where.not(proposed_value: winning_value)
                 .update_all(status: "rejected")
        end
      end
      applied
    end
  end
end
