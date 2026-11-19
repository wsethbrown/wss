require "test_helper"

class UserOauthRebindLogTest < ActiveSupport::TestCase
  test "a changed uid for the same provider is logged at warn with ids only" do
    user = users(:jane)
    user.update_columns(provider: "google_oauth2", uid: "old-uid")
    auth = OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "new-uid",
                                  info: { email: user.email, first_name: "J", last_name: "D" })
    io = StringIO.new
    old = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    begin
      assert_equal user, User.from_omniauth(auth)
    ensure
      Rails.logger = old
    end
    assert_equal "new-uid", user.reload.uid
    assert_match(/OAuth uid rebind: user #{user.id} provider google_oauth2/, io.string)
  end
end
