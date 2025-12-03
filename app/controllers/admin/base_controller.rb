class Admin::BaseController < ApplicationController
  before_action :authenticate_admin!
  layout "admin"

  private

  def authenticate_admin!
    unless current_user&.is_admin?
      flash[:alert] = "You are not authorized to access this area."
      redirect_to root_path
    end
  end
end
