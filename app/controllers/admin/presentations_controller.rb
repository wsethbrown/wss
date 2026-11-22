class Admin::PresentationsController < Admin::BaseController
  # The deck page's tabs (edit.html.erb), in order. A redirect back to the page
  # names one of these as its anchor; anything else falls back to the first.
  TABS = %w[overview slides pours listing files sales].freeze

  before_action :require_delete_rights!, only: :destroy
  before_action :set_presentation, only: [ :show, :edit, :update, :destroy, :publish, :unpublish, :render_slides ]

  def index
    @presentations = Presentation.includes(:author, :user_presentations)
                                .order(created_at: :desc)
  end

  # One page per deck: the old view page is the edit page now. The flash
  # (a package summary included) is kept so it still shows once there.
  def show
    flash.keep
    redirect_to edit_admin_presentation_path(@presentation)
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
    # File fields are cleaned BEFORE the record is built from the params.
    handle_file_uploads(nil)
    @presentation = Presentation.new(presentation_params)
    @presentation.author = current_user

    if @presentation.save
      DeckSlideRenderJob.perform_later(@presentation.id) if @presentation.pdf_file.attached?
      Rails.logger.info "Admin #{current_user.id} created presentation #{@presentation.id} from the form"
      redirect_to edit_admin_presentation_path(@presentation), notice: "Presentation created successfully."
    else
      Rails.logger.warn "Admin #{current_user.id} create of a presentation refused: #{@presentation.errors.full_messages.to_sentence}"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_purchases
  end

  def update
    handle_file_uploads(@presentation)

    if @presentation.update(presentation_params)
      # A new deck file makes the old slide previews stale, re-render.
      DeckSlideRenderJob.perform_later(@presentation.id) if presentation_params[:pdf_file].present?
      Rails.logger.info "Admin #{current_user.id} saved presentation #{@presentation.id} (tab #{tab_param})"
      redirect_to deck_page(tab_param), notice: "Presentation updated successfully."
    else
      Rails.logger.warn "Admin #{current_user.id} update of presentation #{@presentation.id} refused (tab #{tab_param}): #{@presentation.errors.full_messages.to_sentence}"
      load_purchases
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
      redirect_to deck_page(tab_param), notice: "Published. The deck is live in the library."
    else
      Rails.logger.warn "Admin #{current_user.id} publish of presentation #{@presentation.id} refused: #{@presentation.errors.full_messages.to_sentence}"
      redirect_to deck_page(tab_param), alert: @presentation.errors.full_messages.to_sentence
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
    redirect_to deck_page(tab_param),
                notice: "Unpublished. The deck is out of the library and can't be bought. #{owners_note}"
  end

  # Slide previews normally render automatically on import/upload; this is
  # the manual retry for renders that failed or never ran.
  def render_slides
    unless @presentation.pdf_file.attached?
      Rails.logger.warn "Admin #{current_user.id} refused slide re-render for presentation #{@presentation.id}: no deck file attached"
      redirect_to deck_page(tab_param("files")),
                  alert: "This deck has no deck file to render. Upload one first."
      return
    end

    DeckSlideRenderJob.perform_later(@presentation.id)
    Rails.logger.info "Admin #{current_user.id} queued slide re-render for presentation #{@presentation.id}"
    redirect_to deck_page(tab_param("files")),
                notice: "Slide render queued. Previews refresh in about a minute."
  rescue StandardError => e
    Rails.logger.error "Slide re-render enqueue failed for presentation #{@presentation&.id} (admin #{current_user&.id}): #{e.class}: #{e.message}"
    redirect_to deck_page(tab_param("files")),
                alert: "Could not queue the slide render. Try again in a moment."
  end

  # "What the customer sees" on the Listing tab, refreshed as the admin types:
  # the parts of the deck page a visitor who has not bought the deck sees
  # (the top, the takeaways, the story teaser and the extra sections),
  # rendered by the deck page's own partials from the submitted fields.
  #
  # The deck it renders is a NEW, unsaved Presentation built from those
  # fields only, so this never saves anything, never touches files or pours,
  # never runs the publish checks, and never reads the stored story or slide
  # script: the story shown is the teaser of the text that was sent. The
  # stored deck (member route) lends only its cover and slide count, which
  # the deck page shows everyone. Fires on typing, so it logs at debug.
  PREVIEW_FIELDS = %w[title subtitle description category difficulty duration what_youll_learn content sections].freeze

  def preview
    saved = Presentation.find(params[:id]) if params[:id]
    deck = Presentation.new(presentation_params.slice(*PREVIEW_FIELDS))
    cover = saved && helpers.deck_cover_attachment(saved)
    slides_count = saved ? saved.slide_images.count : 0
    Rails.logger.debug { "Admin #{current_user.id} previewed #{saved ? "presentation #{saved.id}" : 'a new presentation'}" }
    render partial: "admin/presentations/customer_view",
           locals: { presentation: deck, cover_image: cover, slides_count: slides_count }
  rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing => e
    Rails.logger.warn "Admin #{current_user.id} preview of presentation #{params[:id] || 'new'} refused: #{e.class}"
    head(e.is_a?(ActiveRecord::RecordNotFound) ? :not_found : :bad_request)
  rescue StandardError => e
    Rails.logger.warn "Admin #{current_user.id} preview of presentation #{params[:id] || 'new'} failed: #{e.class}"
    head :unprocessable_entity
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

  def load_purchases
    @purchases = @presentation.user_presentations
                              .includes(:user)
                              .order(created_at: :desc)
  end

  # The tab to return to, from the form's hidden "tab" field (or a button's
  # param). Whitelisted: it ends up in a URL.
  def tab_param(default = TABS.first)
    params[:tab].presence_in(TABS) || default
  end

  # Back to the deck page on that tab. The anchor serves full page loads;
  # Turbo follows redirects with fetch, which drops the anchor, so the tab
  # also rides in the flash for the page's hidden "tab" field (deck-tabs
  # opens it when the URL has no anchor).
  def deck_page(tab)
    flash[:deck_tab] = tab
    edit_admin_presentation_path(@presentation, anchor: tab)
  end

  # Every file field accepts uploaded files only. Active Storage also takes a
  # STRING as a signed blob id, so a crafted request could otherwise attach
  # any stored blob (another deck's paid file) to this deck, and a garbage
  # string raises InvalidSignature. Anything that isn't an upload is dropped
  # and logged (field names only).
  #
  # "Anything else" (supplemental_materials) is a has_many_attached, and
  # assigning one replaces the whole set: an empty array deletes every extra.
  # So nothing is passed when no file was chosen, and new uploads are ADDED
  # to the deck's extras (the existing ones ride along by signed blob id,
  # added here, after the filter, which keeps them attached as they are).
  # `presentation` is nil on create.
  SINGLE_FILE_FIELDS = %w[featured_image pdf_file speaker_notes outline_file recommendations_sheet scorecard image].freeze

  def handle_file_uploads(presentation)
    attrs = params[:presentation]
    return unless attrs.respond_to?(:key?)

    deck_label = presentation&.id ? "presentation #{presentation.id}" : "a new presentation"
    dropped = []

    SINGLE_FILE_FIELDS.each do |field|
      next unless attrs.key?(field)
      next if upload?(attrs[field])

      dropped << field unless attrs[field].blank?
      attrs.delete(field)
    end

    if attrs.key?(:supplemental_materials)
      values = Array(attrs[:supplemental_materials])
      uploads = values.select { |value| upload?(value) }
      dropped << "supplemental_materials" if values.reject(&:blank?).size > uploads.size

      if uploads.empty?
        attrs.delete(:supplemental_materials)
      else
        kept = presentation&.persisted? ? presentation.supplemental_materials.blobs.map(&:signed_id) : []
        attrs[:supplemental_materials] = kept + uploads
        Rails.logger.info "Admin #{current_user.id} adding #{uploads.size} extra file(s) to #{deck_label}, keeping #{kept.size}"
      end
    end

    return if dropped.empty?

    Rails.logger.warn "Admin #{current_user.id} save of #{deck_label}: dropped non-upload value(s) in #{dropped.uniq.join(', ')}"
  end

  def upload?(value)
    value.is_a?(ActionDispatch::Http::UploadedFile)
  end

  def presentation_params
    params.require(:presentation).permit(
      :title,
      :subtitle,
      :description,
      :content,
      :category,
      :tag_names,
      :price,
      :duration,
      :difficulty,
      :tasting_notes,
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
      # The extra sections: one { heading, lines } per card on the Listing
      # tab, lines as one textarea string (Presentation#sections= splits it).
      sections: [ :heading, :lines ],
      # The deck's pour list rides along as nested rows, so it saves with the
      # deck like every other section (see PresentationBottle).
      presentation_bottles_attributes: [ :id, :bottle_id, :name, :origin, :style,
                                         :price, :notes, :label, :position, :_destroy ]
    )
  end
end
