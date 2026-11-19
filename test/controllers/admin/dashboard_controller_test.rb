require "test_helper"

# D8: the admin shell (sidebar + phone menu) and the dashboard built from the
# admin/shared pattern partials. Asserts content and structure, not styling.
class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "a full admin sees the dashboard figures" do
    sign_in users(:admin)
    get admin_root_path
    assert_response :success

    assert_select "h1", "Dashboard"
    assert_select "dl dt", text: "Total users"
    assert_select "dl dd", text: User.count.to_s
    assert_select "dl dt", text: "Presentations"
    assert_select "dl dd", text: "#{Presentation.count} total, #{UserPresentation.count} purchases"
    assert_select "h2", "Recent signups"
    assert_select "h2", "Recent users"
    assert_select "a[href=?]", new_admin_presentation_path, text: "Add new presentation"
  end

  test "the sidebar and phone menu link every section and mark the current one" do
    sign_in users(:admin)
    get admin_credits_path
    assert_response :success

    [ admin_root_path, admin_presentations_path, admin_bottles_path, admin_moderation_path,
      admin_users_path, admin_subscriptions_path, admin_credits_path,
      admin_reviews_analytics_path, admin_activities_path, admin_downloads_analytics_path ].each do |path|
      # Once in the desktop sidebar, once in the phone menu.
      assert_select "nav[aria-label='Admin sections'] a[href=?]", path, count: 2
    end
    assert_select "nav a[aria-current=page][href=?]", admin_credits_path, count: 2
    assert_select "nav a[aria-current=page]", count: 2
  end

  test "a limited admin can open the dashboard" do
    sign_in users(:limited_admin)
    get admin_root_path
    assert_response :success
    assert_select "h1", "Dashboard"
  end

  test "a non-admin is kept out" do
    sign_in users(:john)
    get admin_root_path
    assert_response :redirect
  end
end
