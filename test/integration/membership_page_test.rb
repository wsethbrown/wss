require "test_helper"

class MembershipPageTest < ActionDispatch::IntegrationTest
  test "membership page renders the club pitch and all three plans" do
    get membership_path
    assert_response :success

    # Hero pitch
    assert_select "h1", text: /Start your own\s+whiskey club\./m

    # Same plan cards as the homepage (shared partial, fallback prices in test)
    assert_select "h3", text: "Monthly"
    assert_select "h3", text: "Quarterly"
    assert_select "h3", text: "Yearly"
    assert_select "span", text: /Best Value/
  end

  test "membership page shows the free-vs-member comparison" do
    get membership_path
    assert_response :success

    Membership::FREE.each do |item|
      assert_select "li span", text: item
    end
    Membership::BENEFITS.each do |benefit|
      assert_select "li span", text: benefit
    end
  end

  test "nav and footer link to the membership page" do
    get root_path
    assert_response :success

    assert_select "nav a[href=?]", membership_path, text: "Membership"
    assert_select "footer a[href=?]", membership_path, text: "Membership"
  end
end
