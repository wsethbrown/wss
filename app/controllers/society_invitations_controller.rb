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
      return redirect_to society, alert: "No account uses #{email}. Share the society's invite link instead; it works for anyone."
    end

    invitation = SocietyInvitation.new(society: society, user: invitee, invited_by: current_user)
    if invitation.save
      Notification.notify!(user: invitee, actor: current_user, notifiable: invitation, action: "society_invite")
      SocietyMailer.invitation(invitation).deliver_later
      redirect_to society, notice: "Invitation sent to #{invitee.full_name}."
    else
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
