require "test_helper"

# OmniAuth redirects to /users/auth/failure when a provider errors. This must
# land on the sign-in page with an explanation, never a 404 (Apple's first
# production failure surfaced as a bare 404 because the route was missing).
class OmniauthFailureTest < ActionDispatch::IntegrationTest
  test "provider failure redirects to the auth page with an alert" do
    get "/users/auth/failure", params: { message: "invalid curve name", strategy: "apple" }
    assert_redirected_to auth_path
    follow_redirect!
    assert_match(/Authentication failed/, @response.body)
  end
end
