module ActivityLogger
  extend ActiveSupport::Concern

  private

  def log_activity(activity_type, trackable = nil, metadata = {})
    return unless current_user

    # IP/UA ride in dedicated columns (see ActivityLog.log_activity); don't
    # duplicate them into the metadata JSON as well.
    ActivityLog.log_activity(
      current_user, activity_type, trackable, metadata,
      ip_address: request.remote_ip, user_agent: request.user_agent
    )
  rescue => e
    Rails.logger.error "Failed to log activity: #{e.message}"
  end

  # For system-initiated activities (like webhooks)
  def log_activity_for_user(user, activity_type, trackable = nil, metadata = {})
    return unless user

    ActivityLog.log_activity(
      user, activity_type, trackable, metadata.merge(initiated_by: 'system'),
      ip_address: request.remote_ip || 'system', user_agent: request.user_agent || 'webhook'
    )
  rescue => e
    Rails.logger.error "Failed to log activity: #{e.message}"
  end
end