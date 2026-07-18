# Claim link from an admin invitation email. The signed, single-use token is
# the authorization: consuming it signs the invitee in and shows the welcome
# page that explains how sign-in works from here (magic link or Google).
class InvitationsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def show
    user = Auth::InvitationService.consume(params[:token])
    if user
      sign_in(user)
      log_activity(:login, nil, { method: "invitation" })
      @user = user
      render :welcome
    else
      redirect_to auth_path, alert: "That invitation link is no longer valid. Enter your email below and we'll send you a magic link instead."
    end
  end
end
