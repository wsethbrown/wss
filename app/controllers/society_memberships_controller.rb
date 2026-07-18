# Society managers remove members or change roles (member <-> officer).
# The creator's membership is untouchable; admins are managed by the creator only.
class SocietyMembershipsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_membership

  def update
    authorize @membership.society, :manage_members?
    new_role = params[:role]

    unless %w[member officer].include?(new_role) && @membership.user_id != @membership.society.creator_id
      redirect_to @membership.society, alert: 'That role change is not allowed' and return
    end

    @membership.update!(role: new_role)
    SocietyActivity.record!(society: @membership.society, user: @membership.user, actor: current_user,
                            action: "role_changed", detail: "now #{new_role == 'officer' ? 'an officer' : 'a member'}")
    redirect_to @membership.society, notice: "#{@membership.user.full_name} is now #{new_role == 'officer' ? 'an officer' : 'a member'}."
  end

  def destroy
    authorize @membership.society, :manage_members?

    if @membership.user_id == @membership.society.creator_id
      redirect_to @membership.society, alert: "The founder can't be removed" and return
    end

    @membership.destroy
    SocietyActivity.record!(society: @membership.society, user: @membership.user, actor: current_user, action: "removed")
    redirect_to @membership.society, notice: "#{@membership.user.full_name} was removed from the society."
  end

  private

  def set_membership
    @membership = SocietyMembership.find(params[:id])
  end
end
