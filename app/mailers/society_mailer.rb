# Society invitation emails (owner-approved, July 2026):
#   invitation          -> the invitee: you've been invited, respond on-site
#   invitation_response -> the inviter: they accepted / declined
class SocietyMailer < ApplicationMailer
  def invitation(invitation)
    @invitation = invitation
    @society = invitation.society
    @inviter = invitation.invited_by
    @user = invitation.user
    mail(to: @user.email, subject: "You're invited to join #{@society.name}")
  end

  def invitation_response(invitation)
    @invitation = invitation
    @society = invitation.society
    @responder = invitation.user
    @verb = invitation.status == "accepted" ? "accepted" : "declined"
    mail(to: invitation.invited_by.email,
         subject: "#{@responder.full_name} #{@verb} your invitation to #{@society.name}")
  end
end
