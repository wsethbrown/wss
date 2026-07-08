# app/controllers/admin/bottles/reviews_controller.rb
# Admin-only moderation, no ownership check (distinct from ReviewsController).
class Admin::Bottles::ReviewsController < Admin::BaseController
  before_action :set_review

  def destroy
    @review.destroy!
    redirect_to admin_bottle_path(@bottle), notice: "Review deleted."
  end

  def destroy_image
    @review.images.purge
    redirect_to admin_bottle_path(@bottle), notice: "Review photos removed."
  end

  private

  # Scoped through the URL's bottle: a review addressed under the wrong
  # bottle's URL must 404, not act on (and reveal) another bottle's review.
  def set_review
    @bottle = Bottle.find_by!(slug: params[:bottle_id])
    @review = @bottle.reviews.find(params[:id])
  end
end
