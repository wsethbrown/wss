class PresentationPolicy < ApplicationPolicy
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

  def index?
    true
  end

  def show?
    true
  end

  def create?
    return false unless user.present?
    user.admin? || user.societies.exists?
  end

  def update?
    return false unless user.present?
    user.admin? || record.author == user
  end

  def destroy?
    return false unless user.present?
    # Authors delete their own decks; admin-override delete needs full rights.
    user.can_delete? || record.author == user
  end

  def purchase?
    return false unless user.present?
    record.paid? && record.author != user
  end

  def manage?
    return false unless user.present?
    user.admin? || user.role == "admin"
  end
end
