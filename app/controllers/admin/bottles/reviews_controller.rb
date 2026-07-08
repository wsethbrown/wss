# app/controllers/admin/bottles/reviews_controller.rb
# Admin-only moderation, no ownership check (distinct from ReviewsController).
class Admin::Bottles::ReviewsController < Admin::BaseController
  before_action :set_review

  def destroy
    bottle = @review.bottle
    @review.destroy!
    redirect_to admin_bottle_path(bottle), notice: "Review deleted."
  end

  def destroy_image
    @review.images.purge
    redirect_to admin_bottle_path(@review.bottle), notice: "Review photos removed."
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end
end
