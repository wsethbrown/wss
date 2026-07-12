class SocietyPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    # Anonymous visitors see only public societies. Authenticated users
    # additionally see private societies they created or are an *active* member
    # of. Previously this returned `scope.all`, leaking every private society
    # into public listings.
    def resolve
      return scope.where(is_private: false) unless user

      scope.left_outer_joins(:society_memberships)
           .where(
             "societies.is_private = FALSE OR societies.creator_id = :uid OR " \
             "(society_memberships.user_id = :uid AND society_memberships.status = 'active')",
             uid: user.id
           )
           .distinct
    end
  end

  def index?
    true
  end

  # Public societies are visible to anyone. Private societies are visible only
  # to the creator, a manager, a global admin, or an active member.
  def show?
    return true unless record.is_private
    return false unless user

    owner_or_manager? || record.has_member?(user)
  end

  def new?
    create?
  end

  # Starting a society is a paid membership benefit, free accounts can JOIN
  # societies but not create one. Global admins are exempt (superuser).
  def create?
    return false unless user
    user.admin? || user.has_active_subscription?
  end

  # Creators, society admins/officers, and global admins may edit.
  def edit?
    owner_or_manager?
  end
  alias_method :update?, :edit?

  # Destroying a society is reserved for its creator (and global admins as a
  # superuser escape hatch), not delegated society admins.
  def destroy?
    return false unless user
    record.creator_id == user.id || user.admin?
  end

  def join?
    return false unless user
    # Private societies are invite-only: membership comes from the society's own
    # admins, never from a self-serve join. Without the public? check anyone
    # signed in could POST /societies/:id/join straight past the privacy flag.
    record.public? && !record.has_member?(user)
  end

  # Anyone but the creator may leave a society they belong to.
  def leave?
    return false unless user
    record.has_member?(user) && record.creator_id != user.id
  end

  def manage_members?
    owner_or_manager?
  end

  private

  def owner_or_manager?
    return false unless user && record.is_a?(Society)
    record.creator_id == user.id || user.admin? || record.can_manage?(user)
  end
end
