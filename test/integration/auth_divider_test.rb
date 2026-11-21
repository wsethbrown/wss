require "test_helper"

# The "or" divider separates the provider buttons from the email form. With no
# provider configured there is nothing above it, so it must not render.
class AuthDividerTest < ActionDispatch::IntegrationTest
  # The helpers live in a module included in the controller's view class, which
  # shadows anything stubbed on ActionView::Base. Stub the view class itself.
  def view_class
    AuthController.view_context_class
  end

  test "no divider when no sign-in provider is configured" do
    view_class.any_instance.stubs(:google_sign_in_available?).returns(false)
    view_class.any_instance.stubs(:apple_sign_in_available?).returns(false)
    get auth_path
    assert_response :success
    assert_select "div.relative span", text: "or", count: 0
    assert_select "#magic-link-email"
  end

  test "the divider shows under a provider button" do
    view_class.any_instance.stubs(:google_sign_in_available?).returns(true)
    view_class.any_instance.stubs(:apple_sign_in_available?).returns(false)
    get auth_path
    assert_response :success
    assert_select "div.relative span", text: "or", count: 1
    assert_select "span", text: "Continue with Google"
  end
end
