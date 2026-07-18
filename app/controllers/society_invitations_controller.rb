# Society email invitations. Create: managers only, existing accounts only
# (unknown emails get pointed at the shareable invite link). Accept/decline:
# the invitee only, from the notifications page. Three declines close the
# door (enforced in the model).
class SocietyInvitationsController < ApplicationController
  before_action :authenticate_user!

  def create
    society = Society.find(params[:society_id])
    authorize society, :manage_members?

    email = params[:email].to_s.strip.downcase
    invitee = User.find_by(email: email)
    if invitee.nil?
      Rails.logger.info "Society #{society.id} invitation by user #{current_user.id}: no account for the entered email"
      return redirect_to society, alert: "No account uses #{email}. Share the society's invite link instead; it works for anyone."
    end

    invitation = SocietyInvitation.new(society: society, user: invitee, invited_by: current_user)
    if invitation.save
      Rails.logger.info "Society invitation #{invitation.id} created: user #{invitee.id} invited to society #{society.id} by user #{current_user.id}"
      Notification.notify!(user: invitee, actor: current_user, notifiable: invitation, action: "society_invite")
      SocietyActivity.record!(society: society, user: invitee, actor: current_user, action: "invite_sent")
      SocietyMailer.invitation(invitation).deliver_later
      redirect_to society, notice: "Invitation sent to #{invitee.full_name}."
    else
      Rails.logger.info "Society #{society.id} invitation of user #{invitee.id} refused: #{invitation.errors.full_messages.to_sentence}"
      redirect_to society, alert: invitation.errors.full_messages.to_sentence
    end
  end

  def accept
    invitation = current_user.society_invitations.pending.find(params[:id])
    invitation.accept!
    redirect_to invitation.society, notice: "Welcome to #{invitation.society.name}."
  end

  def decline
    invitation = current_user.society_invitations.pending.find(params[:id])
    invitation.decline!
    redirect_to notifications_path, notice: "Invitation declined."
  end
end
