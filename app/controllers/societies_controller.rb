class SocietiesController < ApplicationController
  include ActivityLogger
  
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_society, only: [:show, :edit, :update, :destroy]

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
    @upcoming_events = @society.upcoming_events.limit(5)
    @past_events = @society.past_events.limit(5)
    @recent_members = @society.members.limit(10)
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

  private

  def set_society
    @society = Society.with_attached_profile_picture.with_attached_banner_image.find(params[:id])
  end

  def society_params
    permitted = params.require(:society).permit(:name, :description, :location, :is_private, :profile_picture, :banner_image, :banner_position)

    # Convert is_private string to boolean
    if permitted[:is_private].present?
      permitted[:is_private] = ActiveModel::Type::Boolean.new.cast(permitted[:is_private])
    end

    permitted
  end

  def apply_search_filters(scope)
    # Name search
    if params[:search].present?
      search_term = params[:search].strip
      scope = scope.where("name ILIKE ? OR description ILIKE ?", "%#{search_term}%", "%#{search_term}%")
    end

    # Zip code and range search (geolocation)
    if params[:zip_code].present? && params[:range].present?
      zip_code = params[:zip_code].strip
      range_miles = params[:range].to_i
      
      # For now, we'll do a simple text match on location
      # In production, you'd want to use a geocoding service and proper distance calculation
      if zip_code.match?(/^\d{5}(-\d{4})?$/) # Valid US zip code
        scope = scope.where("location ILIKE ?", "%#{zip_code}%")
        
        # Future enhancement: Add proper geolocation with lat/lng coordinates
        # scope = scope.near([latitude, longitude], range_miles)
      end
    end

    # Public only filter
    if params[:public_only] == '1'
      scope = scope.where(is_private: false)
    end

    scope
  end

  # Future method for proper geocoding
  # def geocode_zip_code(zip_code)
  #   # Use a geocoding service like Google Maps API or Geocoder gem
  #   # to convert zip code to latitude/longitude coordinates
  #   # Returns [latitude, longitude] or nil if not found
  # end
end
