class EventPolicy < ApplicationPolicy
  # NOTE: Up to Pundit v2.3.1, the inheritance was declared as
  # `Scope < Scope` rather than `Scope < ApplicationPolicy::Scope`.
  # In most cases the behavior will be identical, but if updating existing
  # code, beware of possible changes to the ancestors:
  # https://gist.github.com/Burgestrand/4b4bc22f31c8a95c425fc0e30d7ef1f5

  class Scope < ApplicationPolicy::Scope
    # An event is only as visible as its society: private societies' calendars
    # are not public record (owner directive, 2026-07-07). Reuses the society
    # scope so the two rules can't drift.
    def resolve
      scope.where(society_id: SocietyPolicy::Scope.new(user, Society).resolve.select(:id))
    end
  end

  def index?
    true
  end

  def show?
    SocietyPolicy.new(user, record.society).show?
  end

  def create?
    return false unless user.present?
    user.admin? || record.society.has_admin?(user)
  end

  def update?
    return false unless user.present?
    user.admin? || record.organizer == user || record.society.has_admin?(user)
  end

  def destroy?
    return false unless user.present?
    # Organizers and society admins delete their own events; site admin-override
    # delete needs full rights.
    user.can_delete? || record.organizer == user || record.society.has_admin?(user)
  end

  def rsvp?
    return false unless user.present?
    record.can_rsvp?(user)
  end

  # Table talk: society members, the organizer, and global admins. The
  # week-after-the-night window is enforced by EventComment, not here.
  def comment?
    return false unless user.present?
    user.admin? || record.organizer == user || record.society.has_member?(user)
  end

  def manage_rsvps?
    return false unless user.present?
    user.admin? || record.organizer == user || record.society.has_admin?(user)
  end

  # RSVP replies (statuses + notes): managers plus the event's host.
  def view_rsvps?
    return false unless user.present?
    record.host_id == user.id || manage_rsvps?
  end

  # The pour list: managers plus the event's host (they run the night).
  # Host pour rights do NOT extend to editing the event itself.
  def manage_pours?
    return false unless user.present?
    record.host_id == user.id || update?
  end

  # The night's deck: same circle as the pours (managers + host).
  def manage_deck?
    manage_pours?
  end
end
