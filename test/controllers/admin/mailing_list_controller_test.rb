require "test_helper"

class Admin::MailingListControllerTest < ActionDispatch::IntegrationTest
  setup do
    MailingListSubscriber.create!(email: "active.one@example.com", source: "library", confirmed_at: 2.days.ago)
    MailingListSubscriber.create!(email: "active.two@example.com", source: "deck", confirmed_at: 1.day.ago)
    MailingListSubscriber.create!(email: "waiting@example.com", source: "deck")
    MailingListSubscriber.create!(email: "gone@example.com", source: "library", confirmed_at: 3.days.ago, unsubscribed_at: 1.day.ago)
  end

  test "requires an admin" do
    get admin_mailing_list_path
    assert_redirected_to root_path

    sign_in users(:john)
    get admin_mailing_list_path
    assert_redirected_to root_path
  end

  test "any admin tier sees the counts and the active addresses only" do
    [ users(:admin), users(:limited_admin) ].each do |admin|
      sign_in admin
      get admin_mailing_list_path
      assert_response :success

      assert_select "h1", text: "Mailing list"
      figures = css_select("dl dt").map { |dt| dt.text.strip }.zip(css_select("dl dd.font-display").map { |dd| dd.text.strip }).to_h
      assert_equal({ "Confirmed and active" => "2", "Waiting for confirmation" => "1", "Unsubscribed" => "1" }, figures)

      assert_select "tbody tr", 2
      assert_select "td", text: "active.one@example.com"
      assert_select "td", text: "active.two@example.com"
      assert_no_match(/waiting@example\.com|gone@example\.com/, response.body)
      assert_select "main form", 0, "read-only: no export, delete or send controls"
    end
  end

  test "the sidebar links to it" do
    sign_in users(:admin)
    get admin_dashboard_path
    assert_select "a[href='#{admin_mailing_list_path}']", minimum: 1
  end
end
