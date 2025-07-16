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
    
    # Download trends (for charts) - last 30 days
    start_date = 30.days.ago.to_date
    end_date = Date.current
    
    # Get downloads grouped by date
    downloads_by_date = @downloads
      .where(downloaded_at: start_date.beginning_of_day..end_date.end_of_day)
      .group("DATE(downloaded_at)")
      .count
    
    # Fill in missing dates with zeros
    @daily_downloads = {}
    (start_date..end_date).each do |date|
      @daily_downloads[date.strftime("%Y-%m-%d")] = downloads_by_date[date] || 0
    end
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
    
    # Download timeline - last 30 days
    start_date = 30.days.ago.to_date
    end_date = Date.current
    
    # Get downloads grouped by date
    downloads_by_date = @downloads
      .where(downloaded_at: start_date.beginning_of_day..end_date.end_of_day)
      .group("DATE(downloaded_at)")
      .count
    
    # Fill in missing dates with zeros
    @download_timeline = {}
    (start_date..end_date).each do |date|
      @download_timeline[date.strftime("%Y-%m-%d")] = downloads_by_date[date] || 0
    end
  end
end