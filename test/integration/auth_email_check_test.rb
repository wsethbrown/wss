require "test_helper"

# The password path's branch decision: does this email have an account?
class AuthEmailCheckTest < ActionDispatch::IntegrationTest
  test "an existing email reports exists" do
    post "/auth/email_check", params: { email: users(:john).email }, as: :json
    assert_response :success
    assert JSON.parse(response.body)["exists"]
  end

  test "case and whitespace are normalized" do
    post "/auth/email_check", params: { email: "  #{users(:john).email.upcase}  " }, as: :json
    assert JSON.parse(response.body)["exists"]
  end

  test "an unknown email reports not exists" do
    post "/auth/email_check", params: { email: "nobody@example.com" }, as: :json
    assert_not JSON.parse(response.body)["exists"]
  end

  test "a malformed email reports not exists" do
    post "/auth/email_check", params: { email: "not-an-email" }, as: :json
    assert_not JSON.parse(response.body)["exists"]
  end
end
