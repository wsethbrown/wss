require "test_helper"

class ContactPageTest < ActionDispatch::IntegrationTest
  test "contact page lists the three public addresses" do
    get contact_path
    assert_response :success

    assert_select "a[href='mailto:hello@whiskeysharesociety.com']"
    assert_select "a[href='mailto:support@whiskeysharesociety.com']"
    assert_select "a[href='mailto:partners@whiskeysharesociety.com']"
    # The owner's personal address stays off the site.
    assert_no_match(/seth@whiskeysharesociety\.com/, response.body)
    assert_no_match(/wseth\.brown@icloud\.com/, response.body)
  end

  test "footer links to the contact page" do
    get root_path
    assert_select "footer a[href=?]", contact_path, text: "Contact"
  end
end
