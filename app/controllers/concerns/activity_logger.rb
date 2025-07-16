module ActivityLogger
  extend ActiveSupport::Concern

  private

  def log_activity(activity_type, trackable = nil, metadata = {})
    return unless current_user

    metadata.merge!(
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    ActivityLog.log_activity(current_user, activity_type, trackable, metadata)
  rescue => e
    Rails.logger.error "Failed to log activity: #{e.message}"
  end

  # For system-initiated activities (like webhooks)
  def log_activity_for_user(user, activity_type, trackable = nil, metadata = {})
    return unless user

    metadata.merge!(
      ip_address: request.remote_ip || 'system',
      user_agent: request.user_agent || 'webhook',
      initiated_by: 'system'
    )

    ActivityLog.log_activity(user, activity_type, trackable, metadata)
  rescue => e
    Rails.logger.error "Failed to log activity: #{e.message}"
  end
end