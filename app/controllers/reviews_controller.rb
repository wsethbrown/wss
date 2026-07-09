# The public review section (/reviews): bottle search plus the latest
# tastings feed. Member actions (edit/update/destroy) for solo reviews.
class ReviewsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :search, :show]
  before_action :set_review, only: [:edit, :update, :destroy]

  def index
    @sort = Bottle::SORTS.key?(params[:sort]) ? params[:sort] : "top"
    @tags = params[:tags].to_s.split(",").map { |t| t.downcase.strip }.compact_blank.uniq.first(6)
    @bottles = Bottle.with_score.order(Arel.sql(Bottle::SORTS.fetch(@sort)))
    @bottles = @bottles.search(params[:q]) if params[:q].present?
    @bottles = @bottles.where(id: Review.tagged(@tags).select(:bottle_id)) if @tags.any?
    @distillery = params[:distillery].to_s.strip.presence
    @bottles = @bottles.where("bottles.distillery ILIKE ?", @distillery) if @distillery
    # Separate param name from the tastings feed's params[:page] so the two
    # pagination controls on this page can't collide.
    @bottles = @bottles.with_attached_pinned_label_image.with_attached_label_image
                        .page(params[:bottle_page]).per(24)
    Bottle.preload_display_images(@bottles)
    # The record covers the people as well as the pours: a search also turns
    # up societies (policy-scoped — private ones stay invisible to outsiders).
    @societies = params[:q].present? ? policy_scope(Society).search(params[:q]).order(:name).limit(6) : Society.none
    @recent_reviews =
      if @tags.any? || @distillery
        feed = @tags.any? ? Review.tagged(@tags) : Review.all
        feed = feed.joins(:bottle).where("bottles.distillery ILIKE ?", @distillery) if @distillery
        feed.includes(:user, :bottle, event: [:society, :event_bottles]).recent_first.limit(30)
      else
        Review.includes(:user, :bottle, event: [:society, :event_bottles]).recent_first.limit(10)
      end
    @circle_reviews = current_user ? Review.for_circle(current_user) : nil
    # Distinguishes "nobody followed yet" from "followed, but no pours yet"
    # in the circle empty states. Managing follows lives on Account → Followed.
    @in_circle = current_user ? current_user.favorites.exists? : false
    @feed = params[:feed] if %w[circle hot nights].include?(params[:feed])
    @circle_feed_reviews = Review.for_circle(current_user, limit: 50) if @feed == "circle" && current_user
    @hot_reviews = Review.hot_ranked if @feed == "hot"
    if @feed == "nights"
      # Filter chip: public societies only — a private society's id in the URL
      # silently falls back to the unfiltered feed (same veiling as the cards).
      @night_society = params[:society].present? ? Society.public_societies.find_by(id: params[:society]) : nil
      # One card per night: the events themselves, newest first, each with
      # its per-bottle room scores (view aggregates from @night_pours).
      nights = Event.joins(:society).where(societies: { is_private: false })
      nights = nights.where(society_id: @night_society.id) if @night_society
      @nights = nights.joins(:reviews).distinct.includes(:society)
                      .order(start_time: :desc).limit(20)
      @night_pours = Review.where(event_id: @nights.map(&:id)).includes(:user, :bottle)
                           .group_by(&:event_id)
                           .transform_values { |rs| rs.group_by(&:bottle) }
      @night_societies = Society.public_societies
                                .joins(events: :reviews).distinct.order(:name).limit(12)
    end
  end

  # Entity-grouped autocomplete for the section search: bottles and societies,
  # same privacy scope as the page results. Deliberately NO add-a-bottle row —
  # cataloging happens in the start-a-review flow, where intent is explicit.
  def search
    q = params[:q].to_s.strip
    bottles  = q.length >= 2 ? Bottle.search(q).order(:name).limit(6) : Bottle.none
    societies = q.length >= 2 ? policy_scope(Society).search(q).order(:name).limit(4) : Society.none
    distilleries = q.length >= 2 ? Bottle.where("distillery ILIKE ?", "%#{Bottle.sanitize_sql_like(q)}%").distinct.order(:distillery).limit(4).pluck(:distillery) : []
    render json: {
      distilleries: distilleries.map { |d| { label: "#{d} — Distillery", url: reviews_path(distillery: d) } },
      bottles:   bottles.map { |b| { label: b.display_name, url: bottle_path(b) } },
      societies: societies.map { |s| { label: s.name, url: society_path(s) } }
    }
  end

  # Start a review: pick the bottle you tasted (or add it). The picker's
  # autocomplete links straight into each bottle's review form.
  def start; end

  # A review's own page — the drill-down target for every clamped card.
  def show
    @review = Review.includes(:user, :bottle, event: [:society, :event_bottles], images_attachments: :blob).find(params[:id])
  end

  def edit; end

  def update
    @review.images.attach(review_params[:images]) if review_params[:images].present?
    if @review.update(review_params.except(:images))
      redirect_to review_path(@review), notice: "Review updated."
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
    params.require(:review).permit(:rating, :notes, :nose, :palate, :finish, :body_notes, :price_paid, flavor_wheel: Review::DESCRIPTOR_LEXICON.keys, images: [])
  end
end
