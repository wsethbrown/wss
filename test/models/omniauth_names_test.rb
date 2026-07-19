require "test_helper"

# Apple sends no name on Hide My Email and on repeat sign-ins, and the
# strategy then puts the EMAIL in auth.info.name. Splitting that on " " used
# to store the whole address as both first and last name, which is what
# blew the admin users table past the viewport.
class OmniauthNamesTest < ActiveSupport::TestCase
  def auth(email:, name: nil, first: nil, last: nil, uid: "uid-#{SecureRandom.hex(4)}")
    OmniAuth::AuthHash.new(
      provider: "apple", uid: uid,
      info: { email: email, name: name, first_name: first, last_name: last }
    )
  end

  test "an email-shaped name is treated as no name" do
    user = User.from_omniauth(auth(email: "y2yp@privaterelay.appleid.com", name: "y2yp@privaterelay.appleid.com"))
    assert_nil user.first_name
    assert_nil user.last_name
    assert_equal "Y2yp", user.full_name, "falls back to the address prefix"
  end

  test "a real name still splits into first and last" do
    user = User.from_omniauth(auth(email: "nat@example.com", name: "Nat McCarty"))
    assert_equal ["Nat", "McCarty"], [user.first_name, user.last_name]
  end

  test "a multi-word surname stays intact" do
    user = User.from_omniauth(auth(email: "pappy@example.com", name: "Julian Van Winkle"))
    assert_equal ["Julian", "Van Winkle"], [user.first_name, user.last_name]
  end

  test "a single-word name is a first name, not duplicated into last" do
    user = User.from_omniauth(auth(email: "cher@example.com", name: "Cher"))
    assert_equal "Cher", user.first_name
    assert_nil user.last_name
  end

  test "explicit first/last from the provider win" do
    user = User.from_omniauth(auth(email: "seth@example.com", name: "ignored@example.com", first: "Seth", last: "Brown"))
    assert_equal ["Seth", "Brown"], [user.first_name, user.last_name]
  end
end
