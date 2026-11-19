class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [ :create ]
  before_action :configure_account_update_params, only: [ :update ]

  def create
    super do |resource|
      if resource.persisted?
        # Mark password as manually set for normal registrations
        resource.update_column(:password_set_manually, true)
      end
    end
  end

  # Self-service deletion is disabled: User#destroy cascades into other members'
  # data and leaves Stripe billing running (docs/redesign/ACCOUNT_DELETION.md).
  # Deliberately does not call super.
  def destroy
    Rails.logger.info "[Account] Self-service deletion refused for user #{current_user&.id.inspect}; redirected to contact"
    redirect_to contact_path, notice: "To delete your account, please contact us."
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end
end
