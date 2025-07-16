class Presentations::DownloadsController < ApplicationController
  include ActivityLogger
  
  before_action :set_presentation
  before_action :check_access, except: [:sneak_peek]
  
  def sneak_peek
    if @presentation.sneak_peek_file.attached?
      # Log activity and download
      if user_signed_in?
        log_activity(:presentation_preview_downloaded, @presentation)
        track_download('sneak_peek')
      end
      
      # Redirect to the file URL
      redirect_to rails_blob_url(@presentation.sneak_peek_file)
    else
      redirect_to @presentation, alert: 'Preview file not available'
    end
  end
  
  def full_presentation
    if @presentation.pdf_file.attached?
      @presentation.increment_download_count!
      log_activity(:presentation_downloaded, @presentation, { file_type: 'full_presentation' })
      track_download('full_presentation')
      
      redirect_to rails_blob_url(@presentation.pdf_file)
    else
      redirect_to @presentation, alert: 'Presentation file not available'
    end
  end
  
  def speaker_notes
    if @presentation.speaker_notes.attached?
      log_activity(:presentation_downloaded, @presentation, { file_type: 'speaker_notes' })
      track_download('speaker_notes')
      
      redirect_to rails_blob_url(@presentation.speaker_notes)
    else
      redirect_to @presentation, alert: 'Speaker notes not available'
    end
  end
  
  def outline
    if @presentation.outline_file.attached?
      log_activity(:presentation_downloaded, @presentation, { file_type: 'outline' })
      track_download('outline')
      
      redirect_to rails_blob_url(@presentation.outline_file)
    else
      redirect_to @presentation, alert: 'Outline not available'
    end
  end
  
  def recommendations
    if @presentation.recommendations_sheet.attached?
      log_activity(:presentation_downloaded, @presentation, { file_type: 'recommendations' })
      track_download('recommendations')
      
      redirect_to rails_blob_url(@presentation.recommendations_sheet)
    else
      redirect_to @presentation, alert: 'Recommendations sheet not available'
    end
  end
  
  private
  
  def set_presentation
    @presentation = Presentation.find(params[:presentation_id])
  end
  
  def check_access
    unless user_signed_in? && @presentation.can_download_full_presentation?(current_user)
      if !user_signed_in?
        redirect_to auth_path, alert: 'Please sign in to download this file'
      else
        redirect_to new_presentation_purchase_path(@presentation), alert: 'Please purchase this presentation to download files'
      end
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
    Rails.logger.error "Failed to track download: #{e.message}"
  end
end