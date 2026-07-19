class Admin::DashboardController < Admin::BaseController
  def index
    # User metrics
    @total_users = User.count
    @active_subscriptions = User.where(subscription_status: "active").count
    @new_users_today = User.where("created_at >= ?", Date.current.beginning_of_day).count
    @new_users_this_week = User.where("created_at >= ?", 1.week.ago).count

    # Presentation metrics
    @total_presentations = Presentation.count
    @published_presentations = Presentation.published.count
    @total_purchases = UserPresentation.count

    # Download metrics
    @total_downloads_today = DownloadLog.today.count
    @total_downloads_week = DownloadLog.this_week.count

    # Revenue metrics. Deck sales are exact (from the purchase ledger); the
    # subscription figure is estimated MRR (active subscribers x live plan price).
    @deck_sales_total = calculate_total_revenue
    @deck_sales_this_month = calculate_monthly_revenue
    @subscription_mrr = SubscriptionRevenue.monthly_recurring

    # Recent activity
    @recent_users = User.order(created_at: :desc).limit(5)
    @recent_purchases = UserPresentation.includes(:user, :presentation)
                                       .order(created_at: :desc)
                                       .limit(10)
    @popular_presentations = Presentation.left_joins(:user_presentations)
                                        .group(:id)
                                        .order("COUNT(user_presentations.id) DESC")
                                        .limit(5)

    # Chart data for the last 7 days
    @signup_chart_data = generate_signup_chart_data

    # Subscription plan breakdown
    @plan_breakdown = User.where.not(subscription_plan: nil)
                          .group(:subscription_plan)
                          .count
                          .sort_by { |_, count| -count }
                          .to_h
  end

  private

  def calculate_total_revenue
    # Direct purchases only for now
    UserPresentation.where(purchase_type: "direct").sum(:purchase_price) || 0
  end

  def calculate_monthly_revenue
    UserPresentation.where(purchase_type: "direct")
                   .where("created_at >= ?", Date.current.beginning_of_month)
                   .sum(:purchase_price) || 0
  end

  def generate_signup_chart_data
    (6.days.ago.to_date..Date.current).map do |date|
      {
        date: date.strftime("%b %d"),
        count: User.where(created_at: date.beginning_of_day..date.end_of_day).count
      }
    end
  end
end
