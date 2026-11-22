# "Open" on the admin deck page: an admin opens one of a deck's files, whoever
# owns the deck.
#
#   GET /admin/presentations/:presentation_id/files/:slot          one-file slots
#   GET /admin/presentations/:presentation_id/files/supplemental_materials?n=2
#                                                                   the nth extra
#
# Only the slots in SLOTS are served, by name; there is no way to ask for an
# arbitrary blob. The file is handed out the way paid downloads are (see
# Presentations::DownloadsController): a short-lived service URL minted after
# the admin check, never the permanent signed blob URL. Admin opens are not
# buyer downloads, so no DownloadLog row is written; the log line is the record.
class Admin::PresentationFilesController < Admin::BaseController
  SLOTS = %w[pdf_file speaker_notes outline_file scorecard featured_image
             sneak_peek_file recommendations_sheet supplemental_materials].freeze

  URL_TTL = 5.minutes

  before_action :set_presentation

  def show
    slot = params[:slot].to_s
    unless SLOTS.include?(slot)
      Rails.logger.warn "Admin #{current_user.id} file open refused for presentation #{@presentation.id}: slot not on the list"
      head :not_found and return
    end

    attachment = attachment_for(slot)
    unless attachment
      Rails.logger.info "Admin #{current_user.id} file open for presentation #{@presentation.id}: #{slot} not attached"
      flash[:deck_tab] = "files"
      redirect_to edit_admin_presentation_path(@presentation, anchor: "files"),
                  alert: "That file isn't uploaded." and return
    end

    ActiveStorage::Current.url_options = { protocol: request.protocol, host: request.host, port: request.optional_port }
    url = attachment.blob.url(expires_in: URL_TTL, disposition: :inline)
    Rails.logger.info "Admin #{current_user.id} opened presentation #{@presentation.id} file #{slot} " \
                      "(blob #{attachment.blob.id}) short-lived URL issued"
    redirect_to url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error "Admin #{current_user&.id} file open failed for presentation #{@presentation&.id} slot #{slot}: #{e.class}: #{e.message}"
    flash[:deck_tab] = "files"
    redirect_to edit_admin_presentation_path(@presentation, anchor: "files"),
                alert: "That file couldn't be opened. Try again in a moment."
  end

  private

  def set_presentation
    @presentation = Presentation.find(params[:presentation_id])
  end

  def attachment_for(slot)
    if slot == "supplemental_materials"
      index = params[:n].to_i
      return nil unless index.positive?

      @presentation.supplemental_materials.attachments.order(:id).offset(index - 1).first
    else
      attachment = @presentation.public_send(slot)
      attachment.attached? ? attachment.attachment : nil
    end
  end
end
