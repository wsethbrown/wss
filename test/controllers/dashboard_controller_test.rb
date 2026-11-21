require "test_helper"

# The signed-in dashboard (finding 3): what is coming up across the member's
# societies, what is waiting on them, and their societies. Same privacy scopes
# as everywhere else.
class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @seth = users(:seth) # member of single_malt; yes to spring_blind (past) and mystery_flight (upcoming)
    @society = societies(:single_malt)
  end

  def section(id) = css_select("section[aria-labelledby='#{id}']").first

  def new_event(society, start:, title:, organizer: users(:admin), hidden: false)
    Event.new(society: society, organizer: organizer, title: title, description: "x", location: "The back room",
              start_time: start, end_time: start + 2.hours, pours_hidden_until_complete: hidden,
              time_zone: "America/New_York").tap { |e| e.save!(validate: false) }
  end

  test "signed out visitors are sent to sign in" do
    get dashboard_path
    assert_redirected_to new_user_session_path
  end

  test "next tastings lists upcoming events in the member's societies with time, zone, place and answer" do
    cookies[:browser_timezone] = "America/Los_Angeles"
    sign_in @seth
    get dashboard_path
    assert_response :success

    next_up = section("next-tastings-heading")
    assert_includes next_up.text, "The Mystery Flight"
    assert_includes next_up.text, @society.name
    assert_includes next_up.text, "Online"
    assert_match(/P[SD]T/, next_up.text, "times carry the viewer's zone abbreviation")
    assert_includes next_up.text, "You said yes"
  end

  test "tastings are listed soonest first" do
    later = new_event(@society, start: 20.days.from_now, title: "Later night")
    sooner = new_event(@society, start: 1.day.from_now, title: "Sooner night")
    sign_in @seth
    get dashboard_path
    text = section("next-tastings-heading").text
    assert_operator text.index(sooner.title), :<, text.index(later.title)
  end

  test "unanswered nights wait on you with a link to answer; answered ones do not" do
    open_night = new_event(@society, start: 4.days.from_now, title: "Unanswered night")
    sign_in @seth
    get dashboard_path
    waiting = section("waiting-heading")
    assert_select waiting, "a[href='#{society_event_path(@society, open_night)}']"
    assert_not_includes waiting.text, "The Mystery Flight"
  end

  test "revealed pours from yes nights you have not reviewed link to the review form" do
    sign_in @seth
    get dashboard_path
    waiting = section("waiting-heading")
    event = events(:spring_blind)
    assert_select waiting, "a[href='#{new_event_review_path(event, bottle_id: bottles(:four_roses_sb).to_param)}']", text: "Review this pour"
    assert_select waiting, "a[href='#{new_event_review_path(event, bottle_id: bottles(:ardbeg_10).to_param)}']", count: 0
  end

  test "pours still secret are not offered for review" do
    live = new_event(@society, start: 1.hour.ago, title: "Secret night", hidden: true)
    EventBottle.create!(event: live, bottle: bottles(:lagavulin), position: 1)
    EventRsvp.new(event: live, user: @seth, status: "yes").save!(validate: false)
    sign_in @seth
    get dashboard_path
    assert_select section("waiting-heading"), "a[href*='#{new_event_review_path(live)}']", count: 0
  end

  test "a private society's nights stay with its members" do
    private_night = new_event(societies(:bourbon_club), start: 3.days.from_now, title: "Private cask night", organizer: users(:jane))
    sign_in @seth
    get dashboard_path
    assert_not_includes response.body, private_night.title

    sign_in users(:jane)
    get dashboard_path
    assert_includes section("next-tastings-heading").text, private_night.title
  end

  test "public societies you do not belong to are not on your dashboard" do
    outsider_night = new_event(societies(:whiskey_lovers), start: 3.days.from_now, title: "Not my club night", organizer: users(:john))
    sign_in @seth
    get dashboard_path
    assert_not_includes response.body, outsider_night.title
  end

  test "your societies are listed with your role" do
    sign_in users(:john) # founded whiskey_lovers, member of single_malt
    get dashboard_path
    yours = section("dashboard-societies-heading")
    assert_includes yours.text, societies(:whiskey_lovers).name
    assert_includes yours.text, "Creator"
    assert_includes yours.text, @society.name
  end

  test "someone in no society sees one sentence and one action in each empty section" do
    sign_in users(:one)
    get dashboard_path
    assert_response :success
    assert_includes section("next-tastings-heading").text, "Join a society to see its tastings here."
    assert_includes section("waiting-heading").text, "Nothing is waiting on you."
    assert_includes section("dashboard-societies-heading").text, "You don't belong to any societies yet."
  end

  test "the account page is still the account page" do
    sign_in @seth
    get account_path
    assert_response :success
    assert_select "#account-details-content, [data-tab]", minimum: 1
  end

  test "the nav logo goes to the dashboard when signed in and the homepage when not" do
    get root_path
    assert_select "nav a[href='#{root_path}'] img[alt='Whiskey Share Society']"
    sign_in @seth
    get root_path
    assert_select "nav a[href='#{dashboard_path}'] img[alt='Whiskey Share Society']"
  end
end
