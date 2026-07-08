# app/controllers/admin/bottles_controller.rb
# Pin/unpin the label image. Delete flows live in Bottles::ReviewsController.
class Admin::BottlesController < Admin::BaseController
  before_action :set_bottle, except: [ :index ]

  def index
    @bottles = Bottle.with_score.order(:name)
  end

  def show
    @reviews = @bottle.reviews.includes(:user, images_attachments: :blob).order(created_at: :desc)
  end

  def pin_image
    if params.dig(:bottle, :pinned_label_image).blank?
      redirect_to admin_bottle_path(@bottle), alert: "Choose an image to pin."
    else
      @bottle.pinned_label_image.attach(bottle_params[:pinned_label_image])
      redirect_to admin_bottle_path(@bottle), notice: "Label image pinned."
    end
  end

  def unpin_image
    @bottle.pinned_label_image.purge_later
    redirect_to admin_bottle_path(@bottle), notice: "Pin removed — the derived image (or placeholder) shows again."
  end

  private

  def set_bottle
    @bottle = Bottle.find_by!(slug: params[:id])
  end

  def bottle_params
    params.require(:bottle).permit(:pinned_label_image)
  end
end
