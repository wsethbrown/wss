class EventCommentPolicy < ApplicationPolicy
  # Authors moderate themselves; the people who run the night (organizer,
  # society admins, global admins — Event#managed_by?) moderate everything.
  def destroy?
    return false unless user.present?
    record.user_id == user.id || record.event.managed_by?(user)
  end
end
