class Admin::PresentationsController < Admin::BaseController
  before_action :set_presentation, only: [:show, :edit, :update, :destroy]
  
  # Temporary fix for schema caching issue
  before_action :reset_column_information, only: [:new, :create, :edit, :update]

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

  # Import a .pptx: parse it into a DRAFT deck (unpublished, price 0) with the
  # file attached and fields pre-filled, then land on the edit form to polish.
  def import
    file = params[:deck_file]
    unless file.respond_to?(:read) && file.original_filename.to_s.end_with?('.pptx')
      redirect_to new_admin_presentation_path, alert: 'Choose a .pptx file to import' and return
    end

    parsed = DeckImport.parse(file.read)

    deck = Presentation.new(
      author: current_user,
      title: parsed.title,
      description: parsed.description,
      content: parsed.content.presence || parsed.description,
      slides_preview: parsed.slides_preview,
      price: 0,
      published: false
    )

    file.rewind
    deck.pdf_file.attach(io: file, filename: file.original_filename,
                         content_type: 'application/vnd.openxmlformats-officedocument.presentationml.presentation')

    if (cover = parsed.images.first)
      deck.featured_image.attach(io: StringIO.new(cover[:data]), filename: cover[:filename])
    end
    parsed.images.drop(1).first(3).each do |img|
      deck.preview_images.attach(io: StringIO.new(img[:data]), filename: img[:filename])
    end

    file.rewind
    DeckImport.render_slides(file.read).each do |s|
      deck.slide_images.attach(io: StringIO.new(s[:data]), filename: s[:filename], content_type: "image/png")
    end

    if deck.save
      redirect_to edit_admin_presentation_path(deck),
                  notice: 'Draft imported from your deck — review each section, set a price, then publish.'
    else
      redirect_to new_admin_presentation_path,
                  alert: "Import failed: #{deck.errors.full_messages.to_sentence}"
    end
  rescue Zip::Error, Nokogiri::XML::SyntaxError => e
    redirect_to new_admin_presentation_path, alert: "Couldn't read that file as a deck: #{e.message}"
  end

  def create
    @presentation = Presentation.new(presentation_params)
    @presentation.author = current_user
    
    # Handle file uploads with empty strings
    handle_file_uploads(@presentation)
    
    # Process whiskey recommendations if present
    process_whiskey_recommendations(@presentation)

    if @presentation.save
      redirect_to admin_presentation_path(@presentation), notice: 'Presentation created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Handle file uploads with empty strings
    handle_file_uploads(@presentation)
    
    # Process whiskey recommendations if present
    process_whiskey_recommendations(@presentation)
    
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
  
  def reset_column_information
    Presentation.reset_column_information
  end

  def set_presentation
    @presentation = Presentation.find(params[:id])
  end
  
  def handle_file_uploads(presentation)
    # Handle preview images - remove empty strings from array
    if params[:presentation][:preview_images].present?
      params[:presentation][:preview_images].reject!(&:blank?)
    end
    
    # Handle supplemental materials - remove empty strings from array
    if params[:presentation][:supplemental_materials].present?
      params[:presentation][:supplemental_materials].reject!(&:blank?)
    end
  end
  
  def process_whiskey_recommendations(presentation)
    # Process the pipe-separated whiskey recommendations into JSON format
    if params[:presentation][:whiskey_recommendations].present?
      recommendations = []
      params[:presentation][:whiskey_recommendations].split("\n").each do |line|
        parts = line.split('|')
        next if parts.length < 4
        
        recommendations << {
          name: parts[0].strip,
          region: parts[1].strip,
          price: parts[2].strip,
          style: parts[3].strip,
          notes: parts[4]&.strip
        }
      end
      
      # Store as JSON
      presentation.whiskey_recommendations_json = recommendations if recommendations.any?
    end
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
      :whiskey_recommendations_json,
      :tasting_notes,
      :nose_notes,
      :palate_notes,
      :finish_notes,
      :body_notes,
      :what_youll_learn,
      :slides_preview,
      :image,
      :featured_image,
      :pdf_file,
      :sneak_peek_file,
      :speaker_notes,
      :outline_file,
      :recommendations_sheet,
      supplemental_materials: [],
      preview_images: []
    )
  end
end