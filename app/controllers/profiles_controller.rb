class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show]

  def show
    # Membership in a PRIVATE society is not public record: profiles list only
    # public societies (plus all of your own when viewing yourself).
    @visible_societies =
      if @user == current_user
        @user.member_societies.includes(:creator)
      else
        @user.member_societies.where(is_private: false).includes(:creator)
      end
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "User not found"
  end
end