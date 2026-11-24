# Upload a finished deck package (.zip) from the admin.
#
#   /admin/deck_packages/new                  "Upload a package": a new draft deck.
#                                             Never overwrites another deck: a
#                                             taken title is refused, pointing at
#                                             that deck's "Replace with a package".
#   /admin/presentations/:id/package/new      "Replace with a package": updates
#                                             THAT deck, whatever its title, keeping
#                                             its price, published state, featured
#                                             flag, author and owners.
#
# The zip is opened by DeckPackageZip (hostile-input checks, temp folder always
# removed) and loaded by DeckPackageImport (everything checked first, saved in
# one transaction). The import is quick (the slides arrive rendered), so it
# runs in the request. Open to limited admins, like every deck action but delete.
class Admin::DeckPackagesController < Admin::BaseController
  before_action :set_presentation

  def new
  end

  def create
    upload = params[:package]
    unless upload.respond_to?(:path) && upload.respond_to?(:original_filename)
      return refuse("Choose the package's .zip file to upload.", "no file")
    end

    importer = nil
    deck = DeckPackageZip.open(upload.path) do |dir|
      importer = DeckPackageImport.new(dir, author: current_user, into: @presentation, create_only: @presentation.nil?)
      importer.call
    end

    Rails.logger.info "Admin #{current_user.id} #{importer.created? ? 'created' : 'updated'} presentation #{deck.id} " \
                      "from a deck package: #{deck.slide_images.count} slides, #{deck.presentation_bottles.count} pours, " \
                      "published=#{deck.published?}, #{importer.warnings.size} warning(s)"
    flash[:package_summary] = { "created" => importer.created?, "warnings" => importer.warnings }
    redirect_to edit_admin_presentation_path(deck),
                notice: importer.created? ? "Package uploaded. The new deck is a draft." : "Package loaded into this deck."
  rescue DeckPackageImport::TitleTaken => e
    @taken_deck = e.deck
    refuse(e.message, "title taken by presentation #{e.deck.id}")
  rescue DeckPackageZip::Invalid, DeckPackageImport::Invalid => e
    refuse(e.message, e.message)
  rescue StandardError => e
    Rails.logger.error "Admin #{current_user.id} deck package upload failed for #{target_label}: #{e.class}: #{e.message}"
    refuse("Something went wrong loading the package, and nothing was changed. Try again, and if it happens again, " \
           "send the zip to the developer.", "unexpected error")
  end

  private

  def set_presentation
    @presentation = Presentation.find(params[:presentation_id]) if params[:presentation_id]
  end

  def target_label
    @presentation ? "presentation #{@presentation.id}" : "a new deck"
  end

  def refuse(message, reason)
    Rails.logger.warn "Admin #{current_user.id} deck package upload refused for #{target_label}: #{reason}"
    @error = message
    @presentation&.reload
    render :new, status: :unprocessable_entity
  end
end
