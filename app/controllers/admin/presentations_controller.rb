class Admin::PresentationsController < Admin::BaseController
  before_action :require_delete_rights!, only: :destroy
  before_action :set_presentation, only: [ :show, :edit, :update, :destroy, :publish, :unpublish, :render_slides ]

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

  # Import a deck file into a DRAFT deck (unpublished, price 0) with the file
  # attached and fields pre-filled, then land on the edit form to polish.
  # A .pptx is parsed here (pure XML). A .ppt/.pdf needs LibreOffice/pdftotext,
  # which never run in the web process: the draft starts from the filename and
  # DeckImportJob fills in its text. Slides always render in DeckSlideRenderJob.
  def import
    file = params[:deck_file]
    content_type = file.respond_to?(:original_filename) && DeckImport.content_type_for(file.original_filename)
    unless file.respond_to?(:read) && content_type
      Rails.logger.warn "Admin #{current_user.id} deck import refused: missing or unsupported file"
      redirect_to new_admin_presentation_path, alert: "Choose a .pptx, .ppt, or .pdf file to import" and return
    end

    # Read the upload ONCE; every consumer gets its own copy. Re-reading the
    # request tempfile after attach caused ActiveStorage::IntegrityError (the
    # blob checksummed one read and uploaded another).
    data = file.read
    inline = DeckImport.inline_parse?(file.original_filename)
    parsed = inline ? DeckImport.parse(data, file.original_filename) : DeckImport.placeholder(file.original_filename)

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
      # Text extraction (.ppt/.pdf) and slide rendering are slow and heavy, do
      # them off the request, in that order, on the renders queue.
      DeckImportJob.perform_later(deck.id) unless inline
      DeckSlideRenderJob.perform_later(deck.id)
      Rails.logger.info "Admin #{current_user.id} imported deck #{deck.id} (#{File.extname(file.original_filename).downcase}); " \
                        "#{inline ? 'text parsed inline' : 'text extraction queued'}, slide render queued"
      notice = if inline
        "Draft imported. The slide previews are rendering and will appear shortly. Review each section, set a price, then publish."
      else
        "Draft imported. The deck's text and slide previews are being extracted and will appear shortly. Review each section, set a price, then publish."
      end
      redirect_to edit_admin_presentation_path(deck), notice: notice
    else
      Rails.logger.warn "Admin #{current_user.id} deck import failed validation: #{deck.errors.full_messages.to_sentence}"
      redirect_to new_admin_presentation_path,
                  alert: "Import failed: #{deck.errors.full_messages.to_sentence}"
    end
  rescue Zip::Error, Nokogiri::XML::SyntaxError => e
    Rails.logger.warn "Admin #{current_user.id} deck import unreadable: #{e.class}: #{e.message}"
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

    if @presentation.save
      DeckSlideRenderJob.perform_later(@presentation.id) if @presentation.pdf_file.attached?
      redirect_to admin_presentation_path(@presentation), notice: "Presentation created successfully."
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

    if @presentation.update(presentation_params)
      # A new deck file makes the old slide previews stale, re-render.
      DeckSlideRenderJob.perform_later(@presentation.id) if presentation_params[:pdf_file].present?
      redirect_to admin_presentation_path(@presentation), notice: "Presentation updated successfully."
    else
      Rails.logger.warn "Admin #{current_user.id} update of presentation #{@presentation.id} refused: #{@presentation.errors.full_messages.to_sentence}"
      render :edit, status: :unprocessable_entity
    end
  end

  # Publishing is an explicit action, never a form side-effect. The model
  # blocks publishing without the buyer-download deck file.
  def publish
    @presentation.free_confirmed = params[:free_confirmed] == "1"
    if @presentation.update(published: true)
      Rails.logger.info "Admin #{current_user.id} published presentation #{@presentation.id} at price #{@presentation.price}" \
                        "#{' (confirmed free)' if @presentation.free?}"
      redirect_to admin_presentation_path(@presentation), notice: "Published. The deck is live in the library."
    else
      Rails.logger.warn "Admin #{current_user.id} publish of presentation #{@presentation.id} refused: #{@presentation.errors.full_messages.to_sentence}"
      redirect_to admin_presentation_path(@presentation), alert: @presentation.errors.full_messages.to_sentence
    end
  end

  # Unpublishing takes the deck out of the library, search and new purchases.
  # Its owners keep it (see Presentation#visible_to?), and the admin is told
  # how many there are.
  def unpublish
    @presentation.update_columns(published: false)
    owners = @presentation.user_presentations.count
    Rails.logger.info "Admin #{current_user.id} unpublished presentation #{@presentation.id} (#{owners} owner(s) keep access)"
    owners_note = owners.zero? ? "Nobody owns it yet." : "#{helpers.pluralize(owners, 'person')} #{owners == 1 ? 'owns' : 'own'} this deck and #{owners == 1 ? 'keeps' : 'keep'} it."
    redirect_to admin_presentation_path(@presentation),
                notice: "Unpublished. The deck is out of the library and can't be bought. #{owners_note}"
  end

  # Slide previews normally render automatically on import/upload; this is
  # the manual retry for renders that failed or never ran.
  def render_slides
    unless @presentation.pdf_file.attached?
      Rails.logger.warn "Admin #{current_user.id} refused slide re-render for presentation #{@presentation.id}: no deck file attached"
      redirect_to admin_presentation_path(@presentation),
                  alert: "This deck has no deck file to render. Upload one first."
      return
    end

    DeckSlideRenderJob.perform_later(@presentation.id)
    Rails.logger.info "Admin #{current_user.id} queued slide re-render for presentation #{@presentation.id}"
    redirect_to admin_presentation_path(@presentation),
                notice: "Slide render queued. Previews refresh in about a minute."
  rescue StandardError => e
    Rails.logger.error "Slide re-render enqueue failed for presentation #{@presentation&.id} (admin #{current_user&.id}): #{e.class}: #{e.message}"
    redirect_to admin_presentation_path(@presentation),
                alert: "Could not queue the slide render. Try again in a moment."
  end

  def destroy
    if @presentation.destroy
      Rails.logger.info "Admin #{current_user.id} deleted presentation #{@presentation.id}"
      redirect_to admin_presentations_path, notice: "Presentation deleted successfully."
    else
      Rails.logger.warn "Admin #{current_user.id} refused deleting presentation #{@presentation.id}: #{@presentation.errors.full_messages.to_sentence}"
      redirect_to admin_presentations_path,
                  alert: "This deck has owners or credit history, so it can't be deleted. Unpublish it instead."
    end
  end

  private

  def set_presentation
    @presentation = Presentation.find(params[:id])
  end

  def handle_file_uploads(presentation)
    # Handle supplemental materials - remove empty strings from array
    if params[:presentation][:supplemental_materials].present?
      params[:presentation][:supplemental_materials].reject!(&:blank?)
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
      :featured,
      :free_confirmed,
      supplemental_materials: [],
      # The deck's pour list rides along as nested rows, so it saves with the
      # deck like every other section (see PresentationBottle).
      presentation_bottles_attributes: [ :id, :bottle_id, :name, :origin, :style,
                                         :price, :notes, :label, :position, :_destroy ]
    )
  end
end
