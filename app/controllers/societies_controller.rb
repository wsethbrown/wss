class SocietiesController < ApplicationController
  before_action :set_society, only: [:show, :edit, :update, :destroy]

  def index
    if user_signed_in?
      # For authorized users, show their societies and searchable public societies
      @societies = Society.includes(:creator, :society_memberships, :members, :events)
                         .joins(:society_memberships)
                         .where(society_memberships: { user: current_user })
                         .search(params[:search])
                         .by_location(params[:location])
                         .order(created_at: :desc)
                         .page(params[:page])
    else
      # For unauthorized users, just set empty array since we show placeholder content
      @societies = []
    end
  end

  def show
    @upcoming_events = @society.upcoming_events.limit(5)
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

    membership = @society.society_memberships.build(user: current_user, role: 'member', status: 'active')

    if membership.save
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
      redirect_to societies_path, notice: 'Successfully left the society.'
    else
      redirect_to @society, alert: 'Unable to leave the society.'
    end
  end

  private

  def set_society
    @society = Society.find(params[:id])
  end

  def society_params
    params.require(:society).permit(:name, :description, :location)
  end
end
