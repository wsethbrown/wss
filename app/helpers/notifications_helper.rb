# Text + destination for each Notification action. A nil text means the
# underlying record is gone; the row is skipped rather than rendered broken.
module NotificationsHelper
  def notification_text(notification)
    actor = notification.actor&.full_name
    target = notification.notifiable
    case notification.action
    when "follow"
      "#{actor} followed you" if actor
    when "review_vote"
      return unless actor && target
      "#{actor} liked your review of #{target.bottle.name}"
    when "event_created"
      return unless target
      "New tasting night in #{target.society.name}: #{target.title}"
    when "society_invite"
      return unless actor && target
      "#{actor} invited you to join #{target.society.name}"
    when "invite_accepted"
      return unless actor && target
      "#{actor} accepted your invitation to #{target.society.name}"
    when "invite_declined"
      return unless actor && target
      "#{actor} declined your invitation to #{target.society.name}"
    end
  end

  def notification_url(notification)
    target = notification.notifiable
    case notification.action
    when "follow"
      profile_path(notification.actor) if notification.actor
    when "review_vote"
      review_path(target) if target
    when "event_created"
      society_event_path(target.society, target) if target
    when "invite_accepted", "invite_declined"
      society_path(target.society) if target
    end
  end
end
