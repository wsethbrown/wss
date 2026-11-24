class Admin::BaseController < ApplicationController
  before_action :authenticate_admin!
  layout "admin"

  private

  def authenticate_admin!
    unless current_user&.admin?
      Rails.logger.warn "Admin area refused #{current_user ? "user #{current_user.id}" : 'signed-out visitor'}: #{request.method} #{controller_path}##{action_name}"
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
