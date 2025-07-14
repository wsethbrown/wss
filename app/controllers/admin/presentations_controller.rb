class Admin::PresentationsController < Admin::BaseController
  before_action :set_presentation, only: [:show, :edit, :update, :destroy]

  def index
    @presentations = Presentation.includes(:author, :user_presentations)
                                .order(created_at: :desc)
  end

  def show
    @purchases = @presentation.user_presentations
                              .includes(:user)
                              .order(created_at: :desc)
  end

  def new
    @presentation = Presentation.new
  end

  def create
    @presentation = Presentation.new(presentation_params)
    @presentation.author = current_user

    if @presentation.save
      redirect_to admin_presentation_path(@presentation), notice: 'Presentation created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @presentation.update(presentation_params)
      redirect_to admin_presentation_path(@presentation), notice: 'Presentation updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @presentation.destroy!
    redirect_to admin_presentations_path, notice: 'Presentation deleted successfully.'
  end

  private

  def set_presentation
    @presentation = Presentation.find(params[:id])
  end

  def presentation_params
    params.require(:presentation).permit(
      :title, 
      :description, 
      :content, 
      :category, 
      :price, 
      :duration,
      :difficulty,
      :published,
      :whiskey_recommendations,
      :tasting_notes,
      :image,
      :featured_image,
      :pdf_file,
      supplemental_materials: []
    )
  end
end