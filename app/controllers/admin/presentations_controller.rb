class Admin::PresentationsController < Admin::BaseController
  before_action :set_presentation, only: [:show, :edit, :update, :destroy, :publish, :unpublish]
  
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
    content_type = file.respond_to?(:original_filename) && DeckImport.content_type_for(file.original_filename)
    unless file.respond_to?(:read) && content_type
      redirect_to new_admin_presentation_path, alert: 'Choose a .pptx, .ppt, or .pdf file to import' and return
    end

    # Read the upload ONCE; every consumer gets its own copy. Re-reading the
    # request tempfile after attach caused ActiveStorage::IntegrityError (the
    # blob checksummed one read and uploaded another).
    data = file.read
    parsed = DeckImport.parse(data, file.original_filename)

    deck = Presentation.new(
      author: current_user,
      title: parsed.title,
      description: parsed.description,
      content: parsed.content.presence || parsed.description.presence || parsed.title,
      slides_preview: parsed.slides_preview,
      price: 0,
      published: false
    )

    deck.pdf_file.attach(io: StringIO.new(data), filename: file.original_filename,
                         content_type: content_type)

    # Model validations cap images at Presentation::MAX_IMAGE_SIZE, oversized embeds
    # are common in decks) must not sink the import. Use the largest that fits;
    # no cover just means the typographic char cover.
    usable_images = parsed.images.select { |i| i[:data].bytesize <= Presentation::MAX_IMAGE_SIZE }
    if (cover = usable_images.first)
      deck.featured_image.attach(io: StringIO.new(cover[:data]), filename: cover[:filename])
    end

    if deck.save
      # Slide rendering (LibreOffice) is slow and heavy, do it off the request.
      DeckSlideRenderJob.perform_later(deck.id)
      redirect_to edit_admin_presentation_path(deck),
                  notice: 'Draft imported. The slide previews are rendering and will appear shortly. Review each section, set a price, then publish.'
    else
      redirect_to new_admin_presentation_path,
                  alert: "Import failed: #{deck.errors.full_messages.to_sentence}"
    end
  rescue Zip::Error, Nokogiri::XML::SyntaxError => e
    redirect_to new_admin_presentation_path, alert: "Couldn't read that file as a deck: #{e.message}"
  end

  # Server-side Markdown preview for the story editor, same pipeline the
  # public reader uses, so the preview is exact.
  def create
    @presentation = Presentation.new(presentation_params)
    @presentation.author = current_user
    
    # Handle file uploads with empty strings
    handle_file_uploads(@presentation)
    
    # Process whiskey recommendations if present
    process_whiskey_recommendations(@presentation)

    if @presentation.save
      DeckSlideRenderJob.perform_later(@presentation.id) if @presentation.pdf_file.attached?
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
      # A new deck file makes the old slide previews stale, re-render.
      DeckSlideRenderJob.perform_later(@presentation.id) if presentation_params[:pdf_file].present?
      redirect_to admin_presentation_path(@presentation), notice: 'Presentation updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Publishing is an explicit action, never a form side-effect. The model
  # blocks publishing without the buyer-download deck file.
  def publish
    if @presentation.update(published: true)
      redirect_to admin_presentation_path(@presentation), notice: 'Published. The deck is live in the library.'
    else
      redirect_to admin_presentation_path(@presentation), alert: @presentation.errors.full_messages.to_sentence
    end
  end

  def unpublish
    @presentation.update_columns(published: false)
    redirect_to admin_presentation_path(@presentation), notice: 'Unpublished. The deck is back to draft.'
  end

  # Slide previews normally render automatically on import/upload; this is
  # the manual retry for renders that failed or never ran.
  def render_slides
    DeckSlideRenderJob.perform_later(@presentation.id)
    redirect_to admin_presentation_path(@presentation),
                notice: 'Slide render queued. Previews refresh in about a minute.'
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
      :tag_names,
      :price, 
      :duration,
      :difficulty,
      :whiskey_recommendations,
      :whiskey_recommendations_json,
      :tasting_notes,
      :nose_notes,
      :palate_notes,
      :finish_notes,
      :body_notes,
      :what_youll_learn,
      :image,
      :featured_image,
      :pdf_file,
      :preview_slide_count,
      :speaker_notes,
      :outline_file,
      :recommendations_sheet,
      :scorecard,
      supplemental_materials: []
    )
  end
end