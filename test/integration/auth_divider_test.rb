require "test_helper"

# The "or" divider separates the provider buttons from the email form. With no
# provider configured there is nothing above it, so it must not render.
class AuthDividerTest < ActionDispatch::IntegrationTest
  test "no divider when no sign-in provider is configured" do
    ActionView::Base.any_instance.stubs(:google_sign_in_available?).returns(false)
    ActionView::Base.any_instance.stubs(:apple_sign_in_available?).returns(false)
    get auth_path
    assert_response :success
    assert_select "span", text: "or", count: 0
    assert_select "#magic-link-email"
  end

  test "the divider shows under a provider button" do
    ActionView::Base.any_instance.stubs(:google_sign_in_available?).returns(true)
    ActionView::Base.any_instance.stubs(:apple_sign_in_available?).returns(false)
    get auth_path
    assert_response :success
    assert_select "span", text: "or", count: 1
    assert_select "span", text: "Continue with Google"
  end
end
