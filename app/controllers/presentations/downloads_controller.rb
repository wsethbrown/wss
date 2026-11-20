class Presentations::DownloadsController < ApplicationController
  include ActivityLogger

  before_action :set_presentation
  before_action :check_access, except: [ :sneak_peek ]

  def sneak_peek
    if @presentation.sneak_peek_file.attached?
      # Log activity and download
      if user_signed_in?
        track_download("sneak_peek")
      end

      # Redirect to the file URL
      redirect_to rails_blob_url(@presentation.sneak_peek_file)
    else
      redirect_to @presentation, alert: "Preview file not available"
    end
  end

  def full_presentation
    if @presentation.pdf_file.attached?
      @presentation.increment_download_count!
      track_download("full_presentation")

      redirect_to_private_file(@presentation.pdf_file)
    else
      redirect_to @presentation, alert: "Presentation file not available"
    end
  end

  def speaker_notes
    if @presentation.speaker_notes.attached?
      track_download("speaker_notes")

      redirect_to_private_file(@presentation.speaker_notes)
    else
      redirect_to @presentation, alert: "Speaker notes not available"
    end
  end

  def outline
    if @presentation.outline_file.attached?
      track_download("outline")

      redirect_to_private_file(@presentation.outline_file)
    else
      redirect_to @presentation, alert: "Outline not available"
    end
  end

  def recommendations
    if @presentation.recommendations_sheet.attached?
      track_download("recommendations")

      redirect_to_private_file(@presentation.recommendations_sheet)
    else
      redirect_to @presentation, alert: "Recommendations sheet not available"
    end
  end

  # The deck's custom tasting scorecard, if the author uploaded one. When they
  # haven't, fall back to the standard blank card so the link is always safe.
  def scorecard
    if @presentation.scorecard.attached?
      track_download("scorecard")

      redirect_to_private_file(@presentation.scorecard)
    else
      redirect_to blank_scorecard_presentation_downloads_path(@presentation)
    end
  end

  # The standard blank WSS scorecard, one static asset, identical for every
  # deck, always available to owners as a fallback for pouring their own bottles.
  def blank_scorecard
    track_download("blank_scorecard")

    send_file BLANK_SCORECARD_PATH,
              filename: "wss-tasting-scorecard.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  # An "Extra" (supplemental material). Scoped to this deck's own extras so an
  # attachment id from another deck or slot is a 404.
  def supplemental
    attachment = @presentation.supplemental_materials.attachments.find(params[:attachment_id])
    track_download("supplemental")

    redirect_to_private_file(attachment)
  end

  private

  BLANK_SCORECARD_PATH = Rails.root.join("app/assets/documents/wss_scorecard_blank.pdf").freeze

  # How long a paid file's download URL stays valid. Short on purpose: it is
  # minted per request, after the access check, and never stored or shared.
  PRIVATE_URL_TTL = 5.minutes

  # Paid files are never handed out by the permanent signed-id blob URL (that
  # link works forever for anyone who has it). Instead mint a service URL that
  # expires and forces a download. On R2 this is a presigned URL; on the Disk
  # service it is a signed, expiring /rails/active_storage/disk URL, which needs
  # the request's host in ActiveStorage::Current.
  def redirect_to_private_file(attachment)
    ActiveStorage::Current.url_options = { protocol: request.protocol, host: request.host, port: request.optional_port }
    url = attachment.blob.url(expires_in: PRIVATE_URL_TTL, disposition: :attachment)
    Rails.logger.info "Download: user #{current_user.id} presentation #{@presentation.id} " \
                      "file #{action_name} (blob #{attachment.blob.id}) short-lived URL issued"
    redirect_to url, allow_other_host: true
  end

  def set_presentation
    @presentation = Presentation.find(params[:presentation_id])
    # Drafts are not for sale/download: 404 for non-admins (see PresentationsController).
    raise ActiveRecord::RecordNotFound unless @presentation.published? || current_user&.admin?
  end

  def check_access
    return if user_signed_in? && @presentation.can_download_full_presentation?(current_user)

    if !user_signed_in?
      redirect_to auth_path, alert: "Sign in to download this file"
    elsif @presentation.purchased_by?(current_user)
      # Owns the deck via a credit but the membership has lapsed, downloads
      # come back when the membership does.
      redirect_to membership_path(anchor: "pricing"),
                  alert: "This deck was unlocked with a credit. Reactivate your membership to download it"
    else
      redirect_to new_presentation_purchase_path(@presentation),
                  alert: "Get this deck to download its files"
    end
  end

  def track_download(file_type)
    return unless user_signed_in?

    DownloadLog.create!(
      user: current_user,
      presentation: @presentation,
      file_type: file_type,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      downloaded_at: Time.current
    )
  rescue => e
    Rails.logger.error "Failed to track download: user #{current_user&.id} presentation #{@presentation&.id} " \
                       "file #{file_type}: #{e.class}: #{e.message}"
  end
end
