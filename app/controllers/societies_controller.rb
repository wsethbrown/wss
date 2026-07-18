class SocietiesController < ApplicationController
  include ActivityLogger

  before_action :authenticate_user!, except: [:index, :show, :join_by_invite]
  before_action :set_society, only: [:show, :edit, :update, :destroy]

  # Society-specific authorization failures redirect back to the listing with a
  # message describing the attempted action, rather than the app-wide default.
  rescue_from Pundit::NotAuthorizedError, with: :society_not_authorized

  def index
    if user_signed_in?
      # Get user's societies (separate from searchable societies)
      @user_societies = current_user.societies.includes(:creator, :society_memberships, :members, :events)
                                             .with_attached_profile_picture
                                             .with_attached_banner_image
                                             .order(created_at: :desc)
      
      # For search results, show all societies the user has access to (excluding their own)
      scope = policy_scope(Society).includes(:creator, :society_memberships, :members, :events)
                                   .with_attached_profile_picture
                                   .with_attached_banner_image
                                   .where.not(id: @user_societies.pluck(:id))
      
      # Apply search filters
      scope = apply_search_filters(scope)
      
      @societies = scope.order(created_at: :desc)
    else
      # For unauthorized users, show only public societies
      @user_societies = []
      scope = Society.includes(:creator, :society_memberships, :members, :events)
                     .with_attached_profile_picture
                     .with_attached_banner_image
                     .where(is_private: false)
      
      # Apply search filters for public users too
      scope = apply_search_filters(scope)
      
      @societies = scope.order(created_at: :desc)
    end
  end

  def show
    authorize @society
    @upcoming_events = @society.upcoming_events.limit(5)
    @past_events = @society.past_events.limit(5)
    @recent_members = @society.members.limit(10)

    # The review board: bottles ranked by THIS society's event reviews only
    # (spec's aggregation table, solo reviews never count here). Inherits
    # the page's visibility from `authorize @society` above; no new gate.
    # Board math (owner decision 2026-07-07): each member counts once per
    # bottle, their LATEST review at this society's events. A re-taster's
    # newer score replaces their older one instead of double-weighting them,
    # and "N reviewers" is exactly the mean's denominator.
    @review_board = @society.review_board
    @board_reviews = Review.joins(:event).where(events: { society_id: @society.id })
                           .includes(:user).recent_first.group_by(&:bottle_id)
  end

  def new
    @society = Society.new
    authorize @society
  end

  def create
    @society = current_user.societies.build(society_params)
    authorize @society

    if @society.save
      redirect_to @society, notice: 'Society was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @society
  end

  def update
    authorize @society

    if @society.update(society_params)
      redirect_to @society, notice: 'Society was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @society

    @society.destroy
    redirect_to societies_url, notice: 'Society was successfully deleted.'
  end

  def join
    @society = Society.find(params[:id])
    authorize @society, :join?

    membership = @society.society_memberships.build(user: current_user, role: :member, status: :active)

    if membership.save
      log_activity(:society_joined, @society)
      redirect_to @society, notice: 'Successfully joined the society!'
    else
      redirect_to @society, alert: 'Unable to join the society.'
    end
  end

  def leave
    @society = Society.find(params[:id])
    authorize @society, :leave?

    membership = @society.society_memberships.find_by(user: current_user)

    if membership&.destroy
      log_activity(:society_left, @society)
      redirect_to societies_path, notice: 'Successfully left the society.'
    else
      redirect_to @society, alert: 'Unable to leave the society.'
    end
  end

  # Join via invite link, valid for private societies (the link IS the invite).
  def join_by_invite
    society = Society.find_by(invite_token: params[:token])
    unless society
      # Never log the presented token; a stale link after regeneration is the usual cause.
      Rails.logger.warn "Invite link rejected: no society matches the presented token"
      redirect_to(user_signed_in? ? societies_path : root_path, alert: "That invite link is no longer valid") and return
    end

    unless user_signed_in?
      # The public peek (owner-approved July 2026): the link IS the invite,
      # so the society introduces itself here, private ones included, but
      # member identities stay off the page. The token rides the session;
      # whichever way they sign up or in, consume_pending_invite joins them.
      session[:pending_invite_token] = society.invite_token
      Rails.logger.info "Invite peek for society #{society.id}: token stored in session for post-sign-in join"
      @society = society
      @top_board = society.review_board.limit(3)
      render :invite and return
    end

    if society.has_member?(current_user)
      redirect_to society, notice: "You are already a member" and return
    end

    society.society_memberships.create!(user: current_user, role: :member, status: :active)
    Rails.logger.info "Invite link join: user #{current_user.id} joined society #{society.id}"
    log_activity(:society_joined, society)
    redirect_to society, notice: "Welcome to #{society.name}!"
  end

  def regenerate_invite
    society = Society.find(params[:id])
    authorize society, :manage_members?
    society.regenerate_invite_token!
    Rails.logger.info "Society #{society.id}: invite link regenerated by user #{current_user.id}; prior links are dead"
    redirect_to society, notice: "New invite link generated. Old links no longer work."
  end

  private

  def society_not_authorized
    message =
      case action_name
      when "show"                     then "You are not authorized to view this society."
      when "edit", "update"           then "You are not authorized to edit this society."
      when "destroy"                  then "You are not authorized to delete this society."
      else                                 "You are not authorized to perform this action."
      end
    redirect_to societies_url, alert: message
  end

  def set_society
    @society = Society.with_attached_profile_picture.with_attached_banner_image.find(params[:id])
  end

  def society_params
    permitted = params.require(:society).permit(:name, :description, :about, :location, :is_private, :profile_picture, :banner_image, :banner_position)

    # Convert is_private string to boolean
    if permitted[:is_private].present?
      permitted[:is_private] = ActiveModel::Type::Boolean.new.cast(permitted[:is_private])
    end

    permitted
  end

  def apply_search_filters(scope)
    # Name/description search
    if params[:search].present?
      search_term = params[:search].strip
      scope = scope.where("name ILIKE ? OR description ILIKE ?", "%#{search_term}%", "%#{search_term}%")
    end

    # Location text search (city/state). The previous ZIP-radius search was
    # decorative, no coordinates or geocoding existed. If radius search is
    # ever wanted for real, add lat/lng columns + the geocoder gem.
    scope = scope.by_location(params[:location]) if params[:location].present?

    scope
  end
end
