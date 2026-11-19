class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :show, :edit, :update, :update_role, :resend_invitation ]

  def index
    @users = User.all

    # Search functionality
    if params[:search].present?
      search_term = params[:search].strip.downcase

      @users = @users.where(
        "LOWER(first_name) LIKE :search OR
         LOWER(last_name) LIKE :search OR
         LOWER(email) LIKE :search OR
         LOWER(CONCAT(first_name, ' ', last_name)) LIKE :search OR
         id::text = :exact_search",
        search: "%#{search_term}%",
        exact_search: search_term
      )
    end

    # Filter by subscription status
    if params[:subscription_status].present?
      case params[:subscription_status]
      when "active"
        @users = @users.where(subscription_status: "active")
      when "inactive"
        @users = @users.where.not(subscription_status: "active").or(@users.where(subscription_status: nil))
      when "canceled"
        @users = @users.where(subscription_status: "canceled")
      end
    end

    # Sort
    case params[:sort]
    when "newest"
      @users = @users.order(created_at: :desc)
    when "oldest"
      @users = @users.order(created_at: :asc)
    when "name"
      @users = @users.order(:first_name, :last_name)
    when "credits"
      @users = @users.order(credits: :desc)
    else
      @users = @users.order(created_at: :desc)
    end

    # Pagination
    @users = @users.page(params[:page]).per(25)

    # Stats for dashboard
    @total_users = User.count
    @active_subscriptions = User.where(subscription_status: "active").count
    @total_credits = User.sum(:credits)
  end

  def show
    @society_memberships = @user.society_memberships.includes(:society)
    @recent_purchases = @user.user_presentations.includes(:presentation).order(created_at: :desc).limit(5)
    @recent_activities = [] # TODO: Implement activity tracking
  end

  def edit
  end

  # Email is the account credential (magic links sign in whoever holds the
  # mailbox), so an admin email change is guarded (S1): full admins only, and
  # never on another admin's record. An allowed change revokes every sign-in
  # credential tied to the old address.
  def update
    attrs = user_params
    email_changing = attrs.key?(:email) &&
                     attrs[:email].to_s.strip.downcase != @user.email.to_s.downcase

    if email_changing && (refusal = email_change_refusal(@user))
      Rails.logger.warn "Admin #{current_user.id} refused email change on user #{@user.id}: #{refusal}"
      redirect_to edit_admin_user_path(@user), alert: refusal and return
    end
    attrs = attrs.except(:email) unless email_changing

    @user.assign_attributes(attrs)
    changed_fields = @user.changed

    if email_changing
      # Revoke the old address's sign-in paths: magic link, invitation,
      # password reset, and every remember-me cookie (expire_all_remember_me_on_sign_out
      # is on, so clearing remember_created_at invalidates outstanding cookies).
      @user.assign_attributes(
        magic_link_token: nil, magic_link_sent_at: nil,
        invitation_token_digest: nil,
        reset_password_token: nil, reset_password_sent_at: nil,
        remember_created_at: nil
      )
    end

    if @user.save
      if changed_fields.any?
        Rails.logger.info "Admin #{current_user.id} updated user #{@user.id}: #{changed_fields.join(', ')}" \
                          "#{' (sign-in tokens and remembered sessions revoked)' if email_changing}"
      else
        Rails.logger.info "Admin #{current_user.id} saved user #{@user.id} with no changes"
      end
      redirect_to admin_user_path(@user), notice: "User updated successfully."
    else
      Rails.logger.warn "Admin #{current_user.id} update of user #{@user.id} failed validation: #{@user.errors.attribute_names.join(', ')}"
      render :edit, status: :unprocessable_entity
    end
  end

  # Grant or revoke admin tiers. Guards: only FULL admins may change roles (a
  # limited admin must not be able to escalate anyone, least of all themselves),
  # and nobody may change their own role (no self-promotion, no locking
  # yourself out). The role value is whitelisted against the enum.
  def update_role
    unless current_user.admin_role_full?
      Rails.logger.warn "Admin #{current_user.id} refused role change on user #{@user.id}: not a full admin"
      redirect_to admin_user_path(@user), alert: "Only full administrators can change roles." and return
    end
    if @user == current_user
      Rails.logger.warn "Admin #{current_user.id} refused role change on own account"
      redirect_to admin_user_path(@user), alert: "You can't change your own role." and return
    end

    role = params[:admin_role].to_s
    unless User.admin_roles.key?(role)
      Rails.logger.warn "Admin #{current_user.id} refused role change on user #{@user.id}: unknown role"
      redirect_to admin_user_path(@user), alert: "Unknown role." and return
    end

    previous = @user.admin_role
    @user.update!(admin_role: role)
    Rails.logger.info "Admin #{current_user.id} changed role of user #{@user.id} from #{previous} to #{role}"
    redirect_to admin_user_path(@user), notice: "Role updated: #{@user.email} is now #{role_label(role)}."
  end

  def resend_invitation
    result = Auth::InvitationService.resend!(@user)
    if result.success?
      redirect_to admin_user_path(@user), notice: result.message
    else
      redirect_to admin_user_path(@user), alert: result.message
    end
  end

  private

  # nil when current_user may change this user's email, else the refusal message.
  def email_change_refusal(user)
    return "Only full administrators can change email addresses." unless current_user.admin_role_full?
    return "You can't change another administrator's email." if user != current_user && user.admin?
    nil
  end

  def email_editable?(user)
    email_change_refusal(user).nil?
  end
  helper_method :email_editable?

  def role_label(role)
    { "none" => "a regular user", "limited" => "an administrator (no delete)", "full" => "a full administrator" }.fetch(role)
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :first_name,
      :last_name,
      :email,
      :bio
    )
  end
end
