# app/controllers/admin/bottles/edits_controller.rb
# Manual apply/reject for a single ghost-edit proposal. Distinct from
# BottleEdits::AutoApply (Task 3) but shares its "clear the field" step —
# applying manually still resolves every pending proposal on the field.
class Admin::Bottles::EditsController < Admin::BaseController
  before_action :set_bottle
  before_action :set_edit

  def apply
    field = @edit.field
    value = @edit.proposed_value
    applied = false

    ActiveRecord::Base.transaction do
      @bottle[field] = BottleEdits::Normalize.for_write(field, value)
      if @bottle.save
        applied = true
        pending = @bottle.bottle_edits.pending.for_field(field)
        pending.where(proposed_value: value)
               .update_all(status: "applied", applied_at: Time.current, applied_by_id: current_user.id)
        pending.where.not(proposed_value: value)
               .update_all(status: "rejected")
      end
    end

    if applied
      redirect_to admin_bottle_path(@bottle), notice: "Applied #{field}: #{value.inspect}."
    else
      redirect_to admin_bottle_path(@bottle), alert: "Couldn't apply that value: #{@bottle.errors.full_messages.to_sentence}"
    end
  end

  def destroy
    @edit.update!(status: "rejected")
    redirect_to admin_bottle_path(@bottle), notice: "Proposal rejected."
  end

  private

  def set_bottle
    @bottle = Bottle.find_by!(slug: params[:bottle_id])
  end

  # Scoped to pending: acting on an already-resolved proposal from a stale
  # admin page must 404, not flip an applied row to rejected (which would
  # leave applied_at set on a "rejected" row — audit trail mangled).
  def set_edit
    @edit = @bottle.bottle_edits.pending.find(params[:id])
  end
end
