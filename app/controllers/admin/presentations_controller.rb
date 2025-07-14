class Admin::PresentationsController < AdminController
  layout 'admin'
  before_action :set_presentation, only: [:show, :edit, :update, :destroy]

  def index
    @presentations = Presentation.all.order(:created_at)
  end

  def show
  end

  def new
    @presentation = Presentation.new
  end

  def create
    @presentation = Presentation.new(presentation_params)
    @presentation.user = current_user

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
    @presentation.destroy
    redirect_to admin_presentations_path, notice: 'Presentation deleted successfully.'
  end

  private

  def set_presentation
    @presentation = Presentation.find(params[:id])
  end

  def presentation_params
    params.require(:presentation).permit(:title, :description, :content, :price, :category, :duration, :difficulty, :image, :published)
  end
end