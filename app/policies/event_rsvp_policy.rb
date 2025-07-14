class EventRsvpPolicy < ApplicationPolicy
  # NOTE: Up to Pundit v2.3.1, the inheritance was declared as
  # `Scope < Scope` rather than `Scope < ApplicationPolicy::Scope`.
  # In most cases the behavior will be identical, but if updating existing
  # code, beware of possible changes to the ancestors:
  # https://gist.github.com/Burgestrand/4b4bc22f31c8a95c425fc0e30d7ef1f5

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  def create?
    return false unless user.present?
    return false unless record.event.present?
    
    # User must be able to RSVP to the event
    record.event.can_rsvp?(user)
  end

  def update?
    return false unless user.present?
    return false unless record.event.present?
    
    # User can only update their own RSVP
    record.user == user && record.event.upcoming?
  end

  def destroy?
    return false unless user.present?
    return false unless record.event.present?
    
    # User can only delete their own RSVP and only if event is upcoming
    record.user == user && record.can_change_response?
  end

  def show?
    # Allow viewing RSVPs for event organizers and admins
    return true if user&.admin?
    return true if record.event.organizer == user
    return true if record.event.society.has_admin?(user)
    
    # Users can view their own RSVP
    record.user == user
  end
end