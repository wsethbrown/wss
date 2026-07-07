class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show]

  def show
    # Membership in a PRIVATE society is not public record. Profiles show:
    # all of your own societies; for others, their public societies plus any
    # private ones you share with them (fellow members already know).
    @visible_societies =
      if @user == current_user
        @user.member_societies.includes(:creator)
      else
        @user.member_societies
             .where(is_private: false)
             .or(@user.member_societies.where(id: current_user.member_societies.select(:id)))
             .distinct.includes(:creator)
      end

    @tastings = @user.reviews.includes(:bottle).recent_first.limit(20)
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "User not found"
  end
end