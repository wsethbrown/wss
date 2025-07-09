class SocietyPolicy < ApplicationPolicy
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

  def new?
    create?
  end

  def create?
    user.present?
  end

  def update?
    return false unless user.present?
    user.admin? || record.has_admin?(user)
  end

  def destroy?
    return false unless user.present?
    user.admin? || record.has_admin?(user)
  end

  def join?
    return false unless user.present?
    !record.has_member?(user)
  end

  def leave?
    return false unless user.present?
    record.has_member?(user) && !record.has_admin?(user)
  end

  def manage_members?
    return false unless user.present?
    user.admin? || record.has_admin?(user)
  end
end
