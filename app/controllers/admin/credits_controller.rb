class Admin::CreditsController < Admin::BaseController
  def index
    users = User.all

    # Filter by credit balance
    users = if params[:filter].present?
              case params[:filter]
              when "has_credits" then users.where("credits > 0")
              when "no_credits" then users.where(credits: 0)
              when "negative" then users.where("credits < 0")
              else users
              end
            else
              users
            end

    # Search
    if params[:search].present?
      search_term = params[:search].strip.downcase
      users = users.where(
        "LOWER(first_name) LIKE :search OR
         LOWER(last_name) LIKE :search OR
         LOWER(email) LIKE :search OR
         LOWER(CONCAT(first_name, ' ', last_name)) LIKE :search",
        search: "%#{search_term}%"
      )
    end

    # Sort
    users = case params[:sort]
            when "most_credits" then users.order(credits: :desc)
            when "least_credits" then users.order(credits: :asc)
            when "name" then users.order(:first_name, :last_name)
            else users.order(credits: :desc)
            end

    @users = users.includes(:profile_image_attachment).page(params[:page]).per(25)

    # Stats
    @total_credits = User.sum(:credits)
    @users_with_credits = User.where("credits > 0").count
    @average_credits = User.average(:credits).to_f.round(2)
    @credit_transactions = CreditTransaction.includes(:user, :presentation)
                                            .order(created_at: :desc)
                                            .limit(10)
  end

  def bulk_add
    if request.post?
      credits_to_add = params[:credits_to_add].to_i
      user_ids = params[:user_ids] || []

      if credits_to_add > 0 && user_ids.any?
        users = User.where(id: user_ids)
        users.update_all("credits = credits + #{credits_to_add}")

        flash[:notice] = "Added #{credits_to_add} credits to #{users.count} users"
        redirect_to admin_credits_path
      else
        flash[:alert] = "Please select users and enter a valid credit amount"
        redirect_to admin_credits_path
      end
    end
  end

  def transactions
    @transactions = CreditTransaction.includes(:user, :presentation)
                                     .order(created_at: :desc)
                                     .page(params[:page])
                                     .per(50)
  end

  def grant_monthly
    # Grant monthly credits to all active subscribers
    active_users = User.where(subscription_status: "active")
    active_users.update_all("credits = credits + 1")

    flash[:notice] = "Granted 1 credit to #{active_users.count} active subscribers"
    redirect_to admin_credits_path
  end

  def adjust
    @user = User.find(params[:id])

    if request.post?
      adjustment = params[:adjustment].to_i
      reason = params[:reason]

      if adjustment != 0
        @user.increment!(:credits, adjustment)

        # Log this transaction
        CreditTransaction.create!(
          user: @user,
          amount: adjustment,
          transaction_type: 'admin_adjustment',
          description: "Admin adjustment by #{current_user.email}: #{reason}"
        )

        Rails.logger.info "Admin #{current_user.email} adjusted credits for #{@user.email} by #{adjustment}: #{reason}"

        flash[:notice] = "Credits adjusted successfully"
        redirect_to admin_credits_path
      else
        flash[:alert] = "Please enter a valid adjustment amount"
      end
    end
  end
end
