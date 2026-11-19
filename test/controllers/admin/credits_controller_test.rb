require "test_helper"

# B5 / M17: the admin "grant monthly" button uses the same per-month ledger key
# as the daily job and the renewal webhook, so pressing it twice (or after the
# job has run) grants nothing more.
class Admin::CreditsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = users(:john)
    @member.update!(subscription_status: "active", subscription_plan: "monthly",
                    subscription_ends_at: 20.days.from_now)
    sign_in users(:admin)
  end

  test "grant monthly is idempotent per month" do
    assert_difference -> { @member.reload.credits }, 1 do
      post grant_monthly_admin_credits_path
    end
    assert_redirected_to admin_credits_path
    assert_match "Granted 1 credit to 1 active subscribers", flash[:notice]

    assert_no_difference -> { @member.reload.credits } do
      post grant_monthly_admin_credits_path
    end
    assert_match "Granted 1 credit to 0 active subscribers", flash[:notice]
    assert_equal CreditTransaction.balance_for(@member), @member.credits
  end

  test "grant monthly after the daily job grants nothing more" do
    @member.update!(subscription_ends_at: Time.current.change(day: [ Time.current.day, 28 ].min) + 1.month)
    MonthlyCreditJob.perform_now
    assert_equal 1, @member.reload.credits

    assert_no_difference -> { @member.reload.credits } do
      post grant_monthly_admin_credits_path
    end
  end

  test "grant monthly skips society-only founding members" do
    @member.update!(subscription_plan: "founding_society", founding_member: true)
    assert_no_difference -> { CreditTransaction.count } do
      post grant_monthly_admin_credits_path
    end
  end

  test "the credits page still offers the grant monthly action" do
    get admin_credits_path
    assert_response :success
    assert_select "form[action='#{grant_monthly_admin_credits_path}'] button, form[action='#{grant_monthly_admin_credits_path}'] input[type=submit]"
  end
end
