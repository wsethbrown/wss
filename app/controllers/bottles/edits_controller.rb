# app/controllers/bottles/edits_controller.rb
# "Suggest a correction" — any signed-in user proposes new values for the
# five whitelisted bottle fields. Only fields that actually changed become
# BottleEdit rows; each triggers an auto-apply check immediately after
# creation (BottleEdits::AutoApply, Task 3).
class Bottles::EditsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bottle

  def new
  end

  def create
    changed_fields = []

    BottleEdit::FIELDS.each do |field|
      submitted = edit_params[field]
      next if submitted.nil?

      normalized = BottleEdits::Normalize.for_storage(field, submitted)
      current = BottleEdits::Normalize.for_storage(field, @bottle[field])
      next if normalized == current

      edit = @bottle.bottle_edits.pending.for_field(field).find_by(user: current_user)
      next if edit # already has a live proposal on this field — resubmission is a no-op

      @bottle.bottle_edits.create!(user: current_user, field: field, proposed_value: normalized)
      changed_fields << field
    end

    changed_fields.each { |field| BottleEdits::AutoApply.call(bottle: @bottle, field: field) }

    redirect_to bottle_path(@bottle), notice:
      changed_fields.any? ? "Thanks — your correction is on the record." : "No changes to suggest."
  end

  private

  def set_bottle
    @bottle = Bottle.find_by!(slug: params[:bottle_id])
  end

  def edit_params
    params.require(:bottle_edit).permit(*BottleEdit::FIELDS)
  end
end
