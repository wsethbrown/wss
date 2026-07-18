# Invite a new member: the admin fills in a name + email, we create the
# account and email a 14-day single-use claim link (Auth::InvitationService).
class Admin::InvitationsController < Admin::BaseController
  def new
  end

  def create
    result = Auth::InvitationService.invite!(
      email: invitation_params[:email],
      first_name: invitation_params[:first_name],
      last_name: invitation_params[:last_name],
      invited_by: current_user
    )
    if result.success?
      redirect_to admin_user_path(result.user), notice: result.message
    else
      flash.now[:alert] = result.message
      @invitation = invitation_params
      render :new, status: :unprocessable_entity
    end
  end

  private

  def invitation_params
    params.require(:invitation).permit(:first_name, :last_name, :email)
  end
end
