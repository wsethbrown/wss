class Admin::BaseController < ApplicationController
  before_action :authenticate_admin!
  layout "admin"

  private

  def authenticate_admin!
    unless current_user&.admin?
      flash[:alert] = "You are not authorized to access this area."
      redirect_to root_path
    end
  end

  # Guard hard-delete actions: only full admins may permanently remove records.
  def require_delete_rights!
    return if current_user&.can_delete?

    redirect_back fallback_location: admin_dashboard_path,
                  alert: "Your admin role does not have delete rights."
  end
end
