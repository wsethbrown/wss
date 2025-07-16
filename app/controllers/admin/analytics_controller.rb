class Admin::AnalyticsController < Admin::BaseController
  def downloads
    @date_range = params[:date_range] || 'week'
    
    # Get date filter
    case @date_range
    when 'today'
      @downloads = DownloadLog.today
    when 'week'
      @downloads = DownloadLog.this_week
    when 'month'
      @downloads = DownloadLog.this_month
    else
      @downloads = DownloadLog.all
    end
    
    # Download statistics
    @total_downloads = @downloads.count
    @unique_users = @downloads.distinct.count(:user_id)
    @downloads_by_type = @downloads.group(:file_type).count
    
    # Popular presentations
    @popular_presentations = @downloads
      .group(:presentation_id)
      .count
      .sort_by { |_, count| -count }
      .first(10)
      .map { |id, count| [Presentation.find(id), count] }
    
    # Recent downloads
    @recent_downloads = DownloadLog
      .includes(:user, :presentation)
      .recent
      .limit(20)
    
    # Download trends (for charts)
    @daily_downloads = @downloads
      .group_by_day(:downloaded_at, last: 30)
      .count
  end
  
  def presentation_downloads
    @presentation = Presentation.find(params[:id])
    @downloads = DownloadLog.by_presentation(@presentation)
    
    # Download stats by file type
    @downloads_by_type = @downloads.group(:file_type).count
    
    # Unique downloaders
    @unique_downloaders = @downloads.distinct.count(:user_id)
    
    # Recent downloads
    @recent_downloads = @downloads
      .includes(:user)
      .recent
      .limit(50)
    
    # Download timeline
    @download_timeline = @downloads
      .group_by_day(:downloaded_at, last: 30)
      .count
  end
end