# The deck's pour list, linked to catalog bottles. Admin-only (decks are
# authored in the admin panel); mirrors Events::EventBottlesController so the
# two pour lists behave alike. Append-only positions, same as events.
class Admin::PresentationBottlesController < Admin::BaseController
  before_action :set_presentation

  def create
    bottle = Bottle.find_by(id: params.dig(:presentation_bottle, :bottle_id))
    if bottle.nil?
      Rails.logger.warn "Deck #{@presentation.id}: pour add rejected, no bottle picked from the search results"
      redirect_to edit_admin_presentation_path(@presentation, anchor: "pours"),
                  alert: "Pick a bottle from the search results first." and return
    end

    pour = @presentation.presentation_bottles.new(
      bottle: bottle,
      label: params.dig(:presentation_bottle, :label),
      position: (@presentation.presentation_bottles.maximum(:position) || 0) + 1
    )

    if pour.save
      Rails.logger.info "Deck #{@presentation.id}: bottle #{bottle.id} added to the pour list by admin #{current_user.id}"
      redirect_to edit_admin_presentation_path(@presentation, anchor: "pours"), notice: "#{bottle.name} is on this deck's pour list."
    else
      Rails.logger.warn "Deck #{@presentation.id}: pour add failed for bottle #{bottle.id}: #{pour.errors.full_messages.to_sentence}"
      redirect_to edit_admin_presentation_path(@presentation, anchor: "pours"), alert: pour.errors.full_messages.to_sentence
    end
  end

  def destroy
    pour = @presentation.presentation_bottles.find(params[:id])
    bottle_id = pour.bottle_id
    pour.destroy
    Rails.logger.info "Deck #{@presentation.id}: bottle #{bottle_id} removed from the pour list by admin #{current_user.id}"
    redirect_to edit_admin_presentation_path(@presentation, anchor: "pours"), notice: "Pour removed."
  end

  private

  def set_presentation
    @presentation = Presentation.find(params[:presentation_id])
  end
end
