require "test_helper"

# B11 (S7): the half-built two-factor sign-in was removed. It had no challenge
# step, so a user with otp_enabled = true could not sign in by password, while
# every other path ignored it. The otp columns are kept (ignored by the model)
# until a later migration drops them; a row with otp_enabled = true must now sign
# in normally on every path.
class TwoFactorRemovedTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    # The column is ignored by the model, so it is set with raw SQL.
    ActiveRecord::Base.connection.execute(
      "UPDATE users SET otp_enabled = TRUE, otp_secret_key = 'LEFTOVERSECRET' WHERE id = #{@user.id.to_i}"
    )
    clear_oauth_mocks
  end

  teardown do
    clear_oauth_mocks
  end

  test "the otp columns are ignored by the model" do
    %w[otp_enabled otp_secret_key backup_codes].each do |column|
      assert_includes User.ignored_columns, column
      assert_not User.column_names.include?(column), "#{column} should not be readable"
    end
    assert_not_respond_to @user, :otp_enabled
    assert_not_respond_to @user, :two_factor_enabled?
  end

  test "a user with otp_enabled in the database signs in by password" do
    post user_session_path, params: { user: { email: @user.email, password: "password" } }

    assert_redirected_to dashboard_path
    assert_nil session[:user_id_for_2fa]
    follow_redirect!
    assert_response :success
    get account_path
    assert_response :success
  end

  test "a user with otp_enabled in the database signs in by magic link" do
    raw = "two-factor-removed-raw-token"
    @user.update!(magic_link_token: Auth::MagicLinkService.digest(raw), magic_link_sent_at: Time.current)

    get magic_link_path(token: raw)

    assert_redirected_to dashboard_path # sign-in lands on the dashboard when no page is waiting
    get account_path
    assert_response :success
  end

  test "a user with otp_enabled in the database signs in by Google" do
    google_user = User.create!(
      email: "test@gmail.com", password: "password", password_confirmation: "password",
      provider: "google_oauth2", uid: "test_google_uid_456", first_name: "Test", last_name: "Google"
    )
    ActiveRecord::Base.connection.execute(
      "UPDATE users SET otp_enabled = TRUE WHERE id = #{google_user.id.to_i}"
    )
    setup_oauth_mock(:google_oauth2, :success)

    assert_no_difference "User.count" do
      post user_google_oauth2_omniauth_callback_path
    end

    assert_redirected_to dashboard_path # sign-in lands on the dashboard when no page is waiting
    get account_path
    assert_response :success
  end

  test "the 2FA account endpoints are not routable" do
    %w[setup_2fa enable_2fa disable_2fa regenerate_backup_codes].each do |action|
      assert_raises(ActionController::RoutingError, "/account/#{action} should not route") do
        Rails.application.routes.recognize_path("/account/#{action}", method: :post)
      end
    end
  end
end
