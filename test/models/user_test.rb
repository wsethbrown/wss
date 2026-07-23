require "test_helper"

class UserTest < ActiveSupport::TestCase
  # full_name gently capitalizes for display: a name entered in lowercase reads
  # properly, an intentional inner capital survives, and matching (which always
  # downcases) is unaffected.
  test "full_name capitalizes the first letter of each word" do
    user = User.new(first_name: "ethan", last_name: "frank")
    assert_equal "Ethan Frank", user.full_name
  end

  test "full_name preserves an intentional inner capital" do
    assert_equal "McDonald", User.new(first_name: "McDonald").full_name
    assert_equal "Jane Smith", User.new(first_name: "Jane", last_name: "Smith").full_name
  end

  test "gently_capitalize never lowercases anything it did not raise" do
    assert_equal "Van Gogh", User.gently_capitalize("van gogh")
    assert_equal "O'Brien", User.gently_capitalize("O'Brien")
    assert_equal "", User.gently_capitalize("")
  end

  test "a lowercase name still matches case-insensitive lookups" do
    # The capitalization is display-only, so anyone searching keeps finding them.
    user = User.new(first_name: "ethan", last_name: "frank")
    assert user.full_name.downcase.include?("ethan frank")
  end
end
