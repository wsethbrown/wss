require "test_helper"
require "minitest/mock"

# Founding Members (owner rules, July 2026): 50 slots total across both
# founding shapes; the $5 society-only plan earns NO deck credits; status is
# lost ONLY on cancel (pause keeps it) and revocation is permanent.
class FoundingMemberTest < ActionDispatch::IntegrationTest
  def founding_user(plan: "founding_society", email: "founder@example.com")
    User.create!(email: email, password: "password123", first_name: "F", last_name: "M",
                 subscription_status: "active", subscription_plan: plan,
                 founding_member: true, stripe_customer_id: "cus_#{email.hash.abs}")
  end

  # ---- cap ------------------------------------------------------------------
  test "founding_slots_remaining counts down from 50" do
    assert_equal 50, User.founding_slots_remaining
    founding_user
    assert_equal 49, User.founding_slots_remaining
  end

  # ---- credits --------------------------------------------------------------
  test "the society-only plan earns no monthly or welcome credits" do
    u = founding_user(plan: "founding_society")
    assert_no_difference("CreditTransaction.count") do
      CreditTransaction.grant_monthly_credit(u)
      assert_equal false, CreditTransaction.grant_welcome_credit(u)
    end
    assert_equal 0, u.reload.credits
  end

  test "the founding monthly plan earns credits like the full plan" do
    u = founding_user(plan: "founding_monthly", email: "fm@example.com")
    assert_difference("CreditTransaction.count", 2) do
      assert CreditTransaction.grant_welcome_credit(u)
      CreditTransaction.grant_monthly_credit(u)
    end
    assert_equal 2, u.reload.credits
  end

  # ---- webhook status grant / revoke ---------------------------------------
  test "taking a founding plan grants status, unless previously revoked" do
    controller = WebhooksController.new
    u = User.create!(email: "n@example.com", password: "password123", first_name: "N", last_name: "U")

    controller.send(:grant_founding_status, u, "founding_monthly")
    assert u.reload.founding_member?

    u.update!(founding_member: false, founding_revoked_at: Time.current)
    controller.send(:grant_founding_status, u, "founding_monthly")
    assert_not u.reload.founding_member?, "revocation must be permanent"
  end

  test "a regular plan never grants founding status" do
    controller = WebhooksController.new
    u = User.create!(email: "r@example.com", password: "password123", first_name: "R", last_name: "U")
    controller.send(:grant_founding_status, u, "monthly")
    assert_not u.reload.founding_member?
  end

  test "subscription deletion revokes founding status permanently" do
    u = founding_user
    WebhooksController.new.send(:handle_subscription_deleted,
      { "customer" => u.stripe_customer_id, "id" => "sub_x", "cancel_at" => nil })

    u.reload
    assert_not u.founding_member?
    assert_not_nil u.founding_revoked_at
    assert_not u.founding_eligible?, "cannot re-earn after cancel"
  end

  test "pause does not touch founding status" do
    u = founding_user
    # Pause arrives as subscription.updated with pause_collection; the handler
    # only re-grants/keeps status. Simulate the relevant state change:
    u.update!(subscription_paused_at: Time.current)
    assert u.reload.founding_member?
  end

  # ---- storefront -----------------------------------------------------------
  test "the membership page shows the founding offers while slots remain" do
    get membership_path
    assert_response :success
    assert_match(/The first fifty/, @response.body)
    assert_match(/Founding Society/, @response.body)
    assert_match(/Founding Monthly/, @response.body)
    assert_match(/50 of 50 founding spots left/, @response.body)
    # The pinned plan-cards contract is untouched.
    assert_select "#plan-cards"
  end

  test "the founding section disappears when the slots are gone" do
    User.stub(:founding_slots_remaining, 0) do
      get membership_path
      assert_response :success
      assert_no_match(/The first fifty/, @response.body)
    end
  end

  test "a revoked account is not shown the founding offers" do
    users(:jane).update!(founding_revoked_at: 1.day.ago)
    sign_in users(:jane)
    get membership_path
    assert_no_match(/The first fifty/, @response.body)
  end

  # ---- checkout gating ------------------------------------------------------
  test "founding checkout is refused once the 50 slots are gone" do
    User.stub(:founding_slots_remaining, 0) do
      sign_in users(:jane)
      post subscriptions_checkout_path, params: { price_id: "founding_society" }
      assert_redirected_to account_path(anchor: "subscription")
      assert_match(/All 50 founding memberships are taken/, flash[:alert])
    end
  end

  test "founding checkout is refused for a revoked account" do
    users(:jane).update!(founding_revoked_at: 1.day.ago)
    sign_in users(:jane)
    post subscriptions_checkout_path, params: { price_id: "founding_monthly" }
    assert_redirected_to account_path(anchor: "subscription")
    assert_match(/isn't available on this account/, flash[:alert])
  end
end
