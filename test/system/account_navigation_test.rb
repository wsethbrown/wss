require "application_system_test_case"

class AccountNavigationTest < ApplicationSystemTestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    )
  end

  # Password sign-in through the unified /auth page: the email goes in the
  # magic-link field, "Use a password instead" reveals the password form for an
  # existing account, which copies the email into #signin-email.
  def sign_in_user
    visit auth_path

    fill_in "magic-link-email", with: @user.email
    find("#password-toggle").click

    assert_selector "#password-signin", visible: true
    assert_selector "#signin-password", visible: true
    assert_equal @user.email, find("#signin-email", visible: :all).value
    fill_in "signin-password", with: "password123"
    within("#password-signin") { click_button "Sign in" }

    # Signed in once the nav offers "Sign out" (the sign-in redirect target may vary).
    assert_link "Sign out"

    visit account_path
    assert_current_path account_path
    wait_for_account_tabs
  end

  # The account-tabs Stimulus controller sets data-account-tabs-ready as the
  # last step of connect(), after its click listener is bound and the initial
  # tab is active. Wait for it before any click: on a cold first page load the
  # controller is imported asynchronously and an early click would be lost.
  def wait_for_account_tabs
    assert_selector "[data-controller~='account-tabs'][data-account-tabs-ready='true']"
  end

  def assert_tab_selected(name)
    assert_selector "[data-tab='#{name}'][role='tab'][aria-selected='true']"
    assert_selector "#tab-#{name}", count: 1
    assert_selector "##{name}-content[role='tabpanel']", visible: true
  end

  def assert_only_panel_visible(name)
    assert_selector "##{name}-content", visible: true
    %w[profile account-details presentations societies followed subscription billing].each do |other|
      next if other == name
      assert_selector "##{other}-content", visible: :hidden
    end
  end

  test "account page loads with profile tab active by default" do
    sign_in_user

    assert_text "Account"
    assert_selector "[data-tab='profile']", text: "Profile"
    assert_selector "[data-tab='account-details']", text: "Account details"

    # Profile tab is selected and its panel is the only one showing
    assert_tab_selected("profile")
    assert_only_panel_visible("profile")
    assert_selector "[data-tab='account-details'][aria-selected='false']"
  end

  test "clicking account details tab shows account details content" do
    sign_in_user

    find("[data-tab='account-details']").click

    assert_tab_selected("account-details")
    assert_selector "[data-tab='profile'][aria-selected='false']"
    assert_only_panel_visible("account-details")
    assert_text "Email address"
    assert_text "Password & security"
  end

  test "clicking between tabs works correctly" do
    sign_in_user

    assert_only_panel_visible("profile")

    find("[data-tab='account-details']").click
    assert_tab_selected("account-details")
    assert_only_panel_visible("account-details")

    find("[data-tab='presentations']").click
    assert_tab_selected("presentations")
    assert_only_panel_visible("presentations")

    find("[data-tab='profile']").click
    assert_tab_selected("profile")
    assert_only_panel_visible("profile")
  end

  test "all navigation tabs are present and clickable" do
    sign_in_user

    tabs = [
      { name: "Profile", tab: "profile" },
      { name: "Account details", tab: "account-details" },
      { name: "My presentations", tab: "presentations" },
      { name: "My societies", tab: "societies" },
      { name: "Followed", tab: "followed" },
      { name: "Subscription", tab: "subscription" },
      { name: "Billing", tab: "billing" }
    ]

    # Check all tabs exist, inside the tab list
    assert_selector "nav[aria-label='Account sections'] [data-tab]", count: tabs.size
    tabs.each do |t|
      assert_selector "[data-tab='#{t[:tab]}']", text: t[:name]
    end

    # Each tab selects itself and shows only its own panel
    tabs.each do |t|
      find("[data-tab='#{t[:tab]}']").click
      assert_tab_selected(t[:tab])
      assert_only_panel_visible(t[:tab])
    end
  end
end
