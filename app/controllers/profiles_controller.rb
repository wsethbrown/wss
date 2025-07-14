class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show]

  def show
    # Users can view their own profile and other users' profiles
    # This will show the public profile view
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "User not found"
  end
end