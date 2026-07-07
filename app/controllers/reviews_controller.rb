# The public review section (/reviews): bottle search plus the latest
# tastings feed. Member actions (edit/update/destroy) for solo reviews.
class ReviewsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :search, :show]
  before_action :set_review, only: [:edit, :update, :destroy]

  def index
    @sort = Bottle::SORTS.key?(params[:sort]) ? params[:sort] : "top"
    @bottles = Bottle.with_score.order(Arel.sql(Bottle::SORTS.fetch(@sort)))
    @bottles = @bottles.search(params[:q]) if params[:q].present?
    # The record covers the people as well as the pours: a search also turns
    # up societies (policy-scoped — private ones stay invisible to outsiders).
    @societies = params[:q].present? ? policy_scope(Society).search(params[:q]).order(:name).limit(6) : Society.none
    @recent_reviews = Review.includes(:user, :bottle, event: [:society, :event_bottles]).recent_first.limit(10)
  end

  # Entity-grouped autocomplete for the section search: bottles and societies,
  # same privacy scope as the page results. Deliberately NO add-a-bottle row —
  # cataloging happens in the start-a-review flow, where intent is explicit.
  def search
    q = params[:q].to_s.strip
    bottles  = q.length >= 2 ? Bottle.search(q).order(:name).limit(6) : Bottle.none
    societies = q.length >= 2 ? policy_scope(Society).search(q).order(:name).limit(4) : Society.none
    render json: {
      bottles:   bottles.map { |b| { label: b.display_name, url: bottle_path(b) } },
      societies: societies.map { |s| { label: s.name, url: society_path(s) } }
    }
  end

  # Start a review: pick the bottle you tasted (or add it). The picker's
  # autocomplete links straight into each bottle's review form.
  def start; end

  # A review's own page — the drill-down target for every clamped card.
  def show
    @review = Review.includes(:user, :bottle, event: [:society, :event_bottles]).find(params[:id])
  end

  def edit; end

  def update
    if @review.update(review_params)
      redirect_to bottle_path(@review.bottle), notice: "Review updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @review.destroy
    redirect_to bottle_path(@review.bottle), notice: "Review removed."
  end

  private

  def set_review
    @review = current_user.reviews.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:rating, :notes, :nose, :palate, :finish, :body_notes)
  end
end
