# Society managers remove members or change roles (member <-> officer).
# The creator's membership is untouchable; a society's admins are managed by
# the creator (or a global admin) only, so an officer cannot demote or remove
# the people above them.
class SocietyMembershipsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_membership
  after_action :verify_authorized

  def update
    authorize @membership.society, :manage_members?
    new_role = params[:role]

    unless %w[member officer].include?(new_role) && @membership.user_id != @membership.society.creator_id
      Rails.logger.warn "Society #{@membership.society_id}: role change of membership #{@membership.id} (user #{@membership.user_id}) to #{new_role.inspect} by user #{current_user.id} refused: not allowed"
      redirect_to @membership.society, alert: "That role change is not allowed" and return
    end

    unless may_manage_target?
      Rails.logger.warn "Society #{@membership.society_id}: role change of admin membership #{@membership.id} (user #{@membership.user_id}) by user #{current_user.id} refused: only the founder manages admins"
      redirect_to @membership.society, alert: "That role change is not allowed" and return
    end

    @membership.update!(role: new_role)
    Rails.logger.info "Society #{@membership.society_id}: user #{@membership.user_id} made #{new_role} by user #{current_user.id}"
    SocietyActivity.record!(society: @membership.society, user: @membership.user, actor: current_user,
                            action: "role_changed", detail: "now #{new_role == 'officer' ? 'an officer' : 'a member'}")
    redirect_to @membership.society, notice: "#{@membership.user.full_name} is now #{new_role == 'officer' ? 'an officer' : 'a member'}."
  end

  def destroy
    authorize @membership.society, :manage_members?

    if @membership.user_id == @membership.society.creator_id
      Rails.logger.warn "Society #{@membership.society_id}: removal of the founder (user #{@membership.user_id}) by user #{current_user.id} refused"
      redirect_to @membership.society, alert: "The founder can't be removed" and return
    end

    unless may_manage_target?
      Rails.logger.warn "Society #{@membership.society_id}: removal of admin membership #{@membership.id} (user #{@membership.user_id}) by user #{current_user.id} refused: only the founder manages admins"
      redirect_to @membership.society, alert: "You are not authorized to perform this action." and return
    end

    @membership.destroy
    Rails.logger.info "Society #{@membership.society_id}: user #{@membership.user_id} removed by user #{current_user.id}"
    SocietyActivity.record!(society: @membership.society, user: @membership.user, actor: current_user, action: "removed")
    redirect_to @membership.society, notice: "#{@membership.user.full_name} was removed from the society."
  end

  private

  def set_membership
    @membership = SocietyMembership.find(params[:id])
  end

  # Members and officers are fair game for any manager. A society admin can
  # only be demoted or removed by the founder or a global admin.
  def may_manage_target?
    return true unless @membership.admin?

    current_user.id == @membership.society.creator_id || current_user.admin?
  end
end
