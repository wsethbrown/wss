# Adds/removes entries on the signed-in user's whiskey shelf (the chip editor
# on the account profile tab). Linked entries carry a bottle_id from the
# autocomplete; free-text entries carry custom_name and never touch the
# bottle catalog.
class Account::ShelfItemsController < ApplicationController
  before_action :authenticate_user!

  def create
    item = current_user.shelf_items.new(shelf_item_params)
    item.position = (current_user.shelf_items.maximum(:position) || 0) + 1
    unless item.save
      @alert = item.errors.full_messages.to_sentence
      Rails.logger.info "Shelf item rejected for user #{current_user.id}: #{@alert}"
    end
    respond
  end

  def destroy
    current_user.shelf_items.find(params[:id]).destroy
    respond
  end

  private

  def respond
    respond_to do |format|
      format.turbo_stream { render :refresh }
      format.html { redirect_to account_path(anchor: "profile"), alert: @alert }
    end
  end

  def shelf_item_params
    permitted = params.require(:shelf_item).permit(:bottle_id, :custom_name)
    # A picked bottle wins over whatever text is left in the search box.
    if permitted[:bottle_id].present?
      { bottle_id: permitted[:bottle_id] }
    else
      { custom_name: permitted[:custom_name].to_s.strip.presence }
    end
  end
end
