require "test_helper"

# "Your societies" on /societies lists every society the viewer belongs to:
# ones they created plus active memberships, each once, with their role, and
# none of them repeated under Discover.
class YourSocietiesTest < ActionDispatch::IntegrationTest
  def your_section = css_select("section[aria-labelledby='your-societies-heading']").first
  def discover_section = css_select("section[aria-labelledby='discover-heading']").first

  def names_in(section)
    section.css("h3").map { |h| h.text.strip }
  end

  test "a member who founded nothing sees the societies they joined, with their role" do
    sign_in users(:seth) # active member of single_malt, founded nothing
    get societies_path
    assert_response :success

    assert_includes names_in(your_section), societies(:single_malt).name
    assert_includes your_section.text, "Member"
    assert_not_includes your_section.text, "You haven't joined any societies yet"
    assert_not_includes names_in(discover_section), societies(:single_malt).name
  end

  test "a founder who also belongs to another society sees each once" do
    sign_in users(:john) # founded whiskey_lovers, member of single_malt
    get societies_path

    yours = names_in(your_section)
    assert_equal 1, yours.count(societies(:whiskey_lovers).name)
    assert_equal 1, yours.count(societies(:single_malt).name)
    assert_includes your_section.text, "Creator"
    assert_not_includes names_in(discover_section), societies(:whiskey_lovers).name
    assert_not_includes names_in(discover_section), societies(:single_malt).name
  end

  test "officer and admin roles are shown" do
    user = users(:one)
    SocietyMembership.create!(user: user, society: societies(:whiskey_lovers), role: "officer", status: "active")
    SocietyMembership.create!(user: user, society: societies(:single_malt), role: "admin", status: "active")
    sign_in user
    get societies_path
    assert_includes your_section.text, "Officer"
    assert_includes your_section.text, "Society admin"
  end

  test "an inactive membership does not count" do
    user = users(:one)
    SocietyMembership.create!(user: user, society: societies(:whiskey_lovers), role: "member", status: "inactive")
    sign_in user
    get societies_path
    assert_not_includes names_in(your_section), societies(:whiskey_lovers).name
    assert_includes your_section.text, "You haven't joined any societies yet"
  end
end
