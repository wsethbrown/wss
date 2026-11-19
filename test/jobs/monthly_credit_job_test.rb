require "test_helper"

# B5 / M1: every member on every plan gets one deck credit per calendar month,
# not one per billing cycle. The daily job, the renewal webhook and the admin
# "grant monthly" button share one ledger key per (user, month), so no path can
# double-grant.
class MonthlyCreditJobTest < ActiveJob::TestCase
  setup do
    @user = users(:john)
  end

  def subscribe!(user, plan:, ends_at:, status: "active")
    user.update!(subscription_status: status, subscription_plan: plan, subscription_ends_at: ends_at,
                 stripe_customer_id: "cus_b5_#{user.id}")
  end

  def assert_ledger_invariant
    User.find_each do |u|
      assert_equal CreditTransaction.balance_for(u), u.credits, "credits cache drifted for user #{u.id}"
    end
  end

  test "a yearly member receives exactly one credit in each of 12 simulated months" do
    start = Time.utc(2027, 1, 14, 16, 0, 0)
    travel_to start do
      subscribe!(@user, plan: "yearly", ends_at: Time.utc(2028, 1, 14, 16))
      assert CreditTransaction.grant_welcome_credit(@user)
    end

    day = start.to_date
    last_day = Date.new(2027, 12, 31)
    while day <= last_day
      travel_to Time.utc(day.year, day.month, day.day, 11, 0, 0) do
        MonthlyCreditJob.perform_now
      end
      day += 1
    end

    grants = CreditTransaction.where(user: @user, transaction_type: "granted").order(:created_at)
    assert_equal 12, grants.count
    assert_equal 12, @user.reload.credits
    months = grants.map { |t| t.created_at.utc.strftime("%Y-%m") }
    assert_equal (1..12).map { |m| format("2027-%02d", m) }, months, "one grant in each calendar month"
    # Anchored to the subscription day (the 14th), not the 1st.
    assert grants.drop(1).all? { |t| t.created_at.utc.day == 14 }
    assert_ledger_invariant
  end

  test "the job does not grant before the member's anchor day" do
    travel_to Time.utc(2027, 3, 10, 11) do
      subscribe!(@user, plan: "quarterly", ends_at: Time.utc(2027, 5, 20, 9))
      assert_no_difference -> { @user.reload.credits } do
        MonthlyCreditJob.perform_now
      end
    end
    travel_to Time.utc(2027, 3, 20, 11) do
      assert_difference -> { @user.reload.credits }, 1 do
        MonthlyCreditJob.perform_now
      end
    end
  end

  test "an anchor past the end of a short month grants on the month's last day" do
    travel_to Time.utc(2027, 2, 28, 11) do
      subscribe!(@user, plan: "yearly", ends_at: Time.utc(2027, 10, 31, 9))
      assert_difference -> { @user.reload.credits }, 1 do
        MonthlyCreditJob.perform_now
      end
    end
  end

  test "running the job twice in a day grants once" do
    travel_to Time.utc(2027, 4, 20, 11) do
      subscribe!(@user, plan: "yearly", ends_at: Time.utc(2028, 1, 14, 9))
      assert_difference -> { @user.reload.credits }, 1 do
        MonthlyCreditJob.perform_now
        MonthlyCreditJob.perform_now
      end
    end
    assert_ledger_invariant
  end

  test "job, renewal grant and admin grant in one month yield exactly one credit" do
    travel_to Time.utc(2027, 5, 14, 11) do
      subscribe!(@user, plan: "monthly", ends_at: Time.utc(2027, 6, 14, 9))
      MonthlyCreditJob.perform_now
      CreditTransaction.grant_monthly_credit(@user, "Monthly subscription renewal")
      CreditTransaction.grant_monthly_credit(@user, "Monthly grant by admin")
    end
    travel_to Time.utc(2027, 5, 28, 11) do
      MonthlyCreditJob.perform_now
      CreditTransaction.grant_monthly_credit(@user, "Monthly grant by admin")
    end
    assert_equal 1, CreditTransaction.where(user: @user, transaction_type: "granted").count
    assert_equal 1, @user.reload.credits
    assert_ledger_invariant
  end

  test "the welcome credit counts as the first month's credit" do
    travel_to Time.utc(2027, 6, 3, 9) do
      subscribe!(@user, plan: "monthly", ends_at: Time.utc(2027, 7, 3, 9))
      assert CreditTransaction.grant_welcome_credit(@user)
    end
    travel_to Time.utc(2027, 6, 3, 11) do
      assert_no_difference -> { @user.reload.credits } do
        MonthlyCreditJob.perform_now
      end
    end
    travel_to Time.utc(2027, 7, 3, 11) do
      # Stripe renewed at 09:00 and moved the period end on a month.
      @user.update!(subscription_ends_at: Time.utc(2027, 8, 3, 9))
      assert_difference -> { @user.reload.credits }, 1 do
        MonthlyCreditJob.perform_now
      end
    end
    assert_ledger_invariant
  end

  test "a society-only founding member receives no monthly credit" do
    travel_to Time.utc(2027, 8, 14, 11) do
      subscribe!(@user, plan: "founding_society", ends_at: Time.utc(2027, 9, 1, 9))
      @user.update!(founding_member: true)
      assert_no_difference -> { CreditTransaction.count } do
        MonthlyCreditJob.perform_now
      end
    end
    assert_equal 0, @user.reload.credits
  end

  test "inactive, past-due and paused members receive nothing" do
    travel_to Time.utc(2027, 8, 14, 11) do
      subscribe!(@user, plan: "yearly", ends_at: Time.utc(2028, 1, 1, 9), status: "past_due")
      jane = users(:jane)
      subscribe!(jane, plan: "yearly", ends_at: Time.utc(2028, 1, 1, 9))
      jane.update!(subscription_paused_at: 2.days.ago)
      assert_no_difference -> { CreditTransaction.count } do
        MonthlyCreditJob.perform_now
      end
    end
  end

  test "the grant key is unique in the database" do
    travel_to Time.utc(2027, 9, 14, 11) do
      subscribe!(@user, plan: "yearly", ends_at: Time.utc(2028, 1, 14, 9))
      CreditTransaction.grant_monthly_credit(@user)
      key = CreditTransaction.monthly_grant_key(@user)
      assert_equal 1, CreditTransaction.where(grant_key: key).count
      assert_raises(ActiveRecord::RecordNotUnique) do
        CreditTransaction.transaction(requires_new: true) do
          CreditTransaction.create!(user: @user, amount: 1, transaction_type: "granted", grant_key: key)
        end
      end
    end
  end

  test "owed report counts the credits quarterly and yearly members missed" do
    travel_to Time.utc(2027, 1, 14, 16) do
      subscribe!(@user, plan: "yearly", ends_at: Time.utc(2028, 1, 14, 16))
      CreditTransaction.grant_welcome_credit(@user)
    end
    travel_to Time.utc(2027, 4, 20, 11) do
      before = CreditTransaction.count
      rows = MonthlyCreditJob.owed_report
      assert_equal before, CreditTransaction.count, "the report must not grant"
      row = rows.find { |r| r[:user_id] == @user.id }
      assert_equal "yearly", row[:plan]
      assert_equal 4, row[:expected] # Jan, Feb, Mar, Apr (anchor 14 reached)
      assert_equal 1, row[:received]
      assert_equal 3, row[:owed]
    end
  end

  test "credits:owed prints the report and grants nothing" do
    travel_to Time.utc(2027, 1, 14, 16) do
      subscribe!(@user, plan: "quarterly", ends_at: Time.utc(2027, 4, 14, 16))
      CreditTransaction.grant_welcome_credit(@user)
    end
    Rails.application.load_tasks unless Rake::Task.task_defined?("credits:owed")
    travel_to Time.utc(2027, 3, 20, 11) do
      out, = capture_io do
        assert_no_difference -> { CreditTransaction.count } do
          Rake::Task["credits:owed"].execute
        end
      end
      assert_match(/#{@user.id}\s+quarterly\s+2027-01-14\s+3\s+1\s+2/, out)
      assert_match "Nothing was granted", out
    end
  end

  # --- Month-end anchors and late subscribers (advisor follow-up) ----------

  # Next period end the way Stripe computes it: same anchor day, clamped to the
  # last day of a shorter month (Jan 31 -> Feb 28 -> Mar 31).
  def next_period_end(anchor_day, after)
    nxt = after.to_date.next_month
    Time.utc(nxt.year, nxt.month, [ anchor_day, Date.new(nxt.year, nxt.month, -1).day ].min, 9)
  end

  # Day by day: at 09:00 Stripe renews a monthly member whose period has ended
  # (period end advances, the renewal webhook path grants), at 11:00 the job runs.
  def simulate_days(user, from:, to:, monthly_anchor: nil)
    (from..to).each do |day|
      if monthly_anchor
        travel_to Time.utc(day.year, day.month, day.day, 9) do
          if user.reload.subscription_ends_at <= Time.current
            user.update!(subscription_ends_at: next_period_end(monthly_anchor, user.subscription_ends_at))
            CreditTransaction.grant_monthly_credit(user, "Monthly subscription renewal")
          end
        end
      end
      travel_to(Time.utc(day.year, day.month, day.day, 11)) { MonthlyCreditJob.perform_now }
    end
  end

  def grant_dates(user)
    CreditTransaction.where(user: user, transaction_type: "granted").order(:created_at).map { |t| t.created_at.utc.to_date }
  end

  def assert_one_per_month_without_gaps(dates, months)
    assert_equal months, dates.map { |d| d.strftime("%Y-%m") }, "exactly one credit per calendar month"
    dates.each_cons(2) do |a, b|
      assert (b - a) <= 31, "gap of #{(b - a).to_i} days between #{a} and #{b}"
    end
  end

  JAN_TO_MAY = %w[2027-01 2027-02 2027-03 2027-04 2027-05].freeze

  test "a monthly member anchored on the 31st gets one credit a month, on the last day of short months" do
    travel_to Time.utc(2027, 1, 31, 8) do
      subscribe!(@user, plan: "monthly", ends_at: Time.utc(2027, 2, 28, 9))
      assert CreditTransaction.grant_welcome_credit(@user)
    end
    simulate_days(@user, from: Date.new(2027, 1, 1), to: Date.new(2027, 5, 31), monthly_anchor: 31)

    dates = grant_dates(@user)
    assert_one_per_month_without_gaps(dates, JAN_TO_MAY)
    assert_equal [ Date.new(2027, 1, 31), Date.new(2027, 2, 28), Date.new(2027, 3, 31),
                   Date.new(2027, 4, 30), Date.new(2027, 5, 31) ], dates
    assert_equal 5, @user.reload.credits
    assert_ledger_invariant
  end

  test "a yearly member anchored on the 31st gets one credit a month, Feb and Apr on the last day" do
    travel_to Time.utc(2026, 12, 31, 16) do
      subscribe!(@user, plan: "yearly", ends_at: Time.utc(2027, 12, 31, 16))
    end
    simulate_days(@user, from: Date.new(2027, 1, 1), to: Date.new(2027, 5, 31))

    dates = grant_dates(@user)
    assert_one_per_month_without_gaps(dates, JAN_TO_MAY)
    assert_equal [ Date.new(2027, 1, 31), Date.new(2027, 2, 28), Date.new(2027, 3, 31),
                   Date.new(2027, 4, 30), Date.new(2027, 5, 31) ], dates
    assert_ledger_invariant
  end

  test "members anchored on the 29th and 30th get one credit a month, February on the 28th" do
    jane = users(:jane)
    travel_to Time.utc(2026, 12, 29, 16) do
      subscribe!(@user, plan: "yearly", ends_at: Time.utc(2027, 12, 29, 16))
    end
    travel_to Time.utc(2027, 1, 30, 8) do
      subscribe!(jane, plan: "monthly", ends_at: Time.utc(2027, 2, 28, 9))
      assert CreditTransaction.grant_welcome_credit(jane)
    end
    simulate_days(jane, from: Date.new(2027, 1, 1), to: Date.new(2027, 5, 31), monthly_anchor: 30)

    yearly = grant_dates(@user)
    assert_one_per_month_without_gaps(yearly, JAN_TO_MAY)
    assert_equal [ 29, 28, 29, 29, 29 ], yearly.map(&:day)

    monthly = grant_dates(jane)
    assert_one_per_month_without_gaps(monthly, JAN_TO_MAY)
    assert_equal [ Date.new(2027, 1, 30), Date.new(2027, 2, 28), Date.new(2027, 3, 30),
                   Date.new(2027, 4, 30), Date.new(2027, 5, 30) ], monthly
    assert_ledger_invariant
  end

  test "a member who subscribes late in a month gets the welcome, then one credit a month on the anchor day" do
    travel_to Time.utc(2027, 1, 28, 15) do
      subscribe!(@user, plan: "monthly", ends_at: Time.utc(2027, 2, 28, 15))
      assert CreditTransaction.grant_welcome_credit(@user)
    end
    simulate_days(@user, from: Date.new(2027, 1, 28), to: Date.new(2027, 5, 31), monthly_anchor: 28)

    dates = grant_dates(@user)
    assert_one_per_month_without_gaps(dates, JAN_TO_MAY)
    assert_equal [ Date.new(2027, 1, 28), Date.new(2027, 2, 28), Date.new(2027, 3, 28),
                   Date.new(2027, 4, 28), Date.new(2027, 5, 28) ], dates
    assert_equal CreditTransaction::WELCOME_DESCRIPTION,
                 CreditTransaction.where(user: @user).order(:created_at).first.description
    assert_equal 5, @user.reload.credits
    assert_ledger_invariant
  end

  test "a yearly member who subscribes late in a month gets the welcome, then one credit a month" do
    travel_to Time.utc(2027, 1, 28, 15) do
      subscribe!(@user, plan: "yearly", ends_at: Time.utc(2028, 1, 28, 15))
      assert CreditTransaction.grant_welcome_credit(@user)
    end
    simulate_days(@user, from: Date.new(2027, 1, 28), to: Date.new(2027, 5, 31))

    dates = grant_dates(@user)
    assert_one_per_month_without_gaps(dates, JAN_TO_MAY)
    assert dates.all? { |d| d.day == 28 }
    assert_ledger_invariant
  end
end
