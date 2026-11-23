require "test_helper"

# The homepage's drawn slides for beats three and four, and the pricing
# section's plan cards. Each face shows real public data when it exists and a
# designed fallback when it does not.
class HomeFacesTest < ActionDispatch::IntegrationTest
  def face_text(selector)
    css_select(selector).map(&:text).join(" ")
  end

  PHOTO_ALT = "Five friends at a whiskey tasting in a lamp-lit living room. One stands by the TV with a glass raised, presenting, and four listen from the sofas, laughing, with glasses in hand.".freeze

  # The photograph shares the face with the invite: printed through
  # shared/_duotone, lazy, sized, never behind the invite's words.
  def assert_gathering_photo
    assert_select ".f3 .sl figure.duotone img", count: 1 do |imgs|
      img = imgs.first
      assert_match %r{tasting-night-living-room.*\.jpg}, img["src"]
      assert_equal PHOTO_ALT, img["alt"]
      assert_equal "lazy", img["loading"]
      assert_equal "1280", img["width"]
      assert_equal "512", img["height"]
    end
    assert_select ".f3 .invite-body figure", count: 0
    # One photograph per view: the face's, and the story frame's copy of it,
    # which is presentational (no alt) and shown only when the face is not.
    assert_select ".face figure.duotone", count: 1
    assert_select ".mm[aria-hidden=true] figure.duotone img[alt='']", count: 1
    assert_select "figure.duotone", count: 2
  end

  test "the sample invite shares its face with the gathering photograph" do
    Event.where("start_time > ?", Time.current).update_all(start_time: 1.day.ago)
    get root_path
    assert_gathering_photo
  end

  test "a real night's invite shares its face with the gathering photograph" do
    get root_path
    assert_select ".f3 a.sl", count: 1
    assert_gathering_photo
  end

  # --- Beat 3: the next tasting night ---------------------------------------

  test "an upcoming public night fills the invite with its date, place and guests" do
    event = events(:mystery_flight)
    get root_path
    assert_response :success

    assert_select ".f3 a.sl[href=?]", event_path(event), count: 1
    assert_select ".f3 .sl .ev", text: event.title
    assert_select ".f3 .sl .where", text: /#{Regexp.escape(event.society.name)}/
    # Seth said yes, so his initials sit in the guest row with the count.
    assert_select ".f3 .sl .guests [aria-label=?]", users(:seth).display_name, count: 1
    assert_select ".f3 .sl .guests", text: /1 going/
    assert_select ".f3", text: /Sample invite/, count: 0
  end

  test "without an upcoming public night the face draws a sample invite that links nowhere" do
    Event.where("start_time > ?", Time.current).update_all(start_time: 1.day.ago)
    get root_path
    assert_response :success

    assert_select ".f3 .sl", count: 1
    assert_select ".f3 a", count: 0
    assert_select ".f3 .sl", text: /Sample invite/
    assert_select ".f3 .sl .ev", text: "Bourbon night"
    assert_select ".f3 .sl .guests i", count: 5
    assert_select ".f3 .sl .guests", text: /5 going/
    assert_select ".f3 .bar b", text: "Gather your society"

    # An illustration: nobody real appears on it.
    text = face_text(".f3")
    User.find_each do |user|
      refute_includes text, user.full_name, "the sample invite must not name a real member"
      refute_includes text, user.email
    end
  end

  test "the invite tells the time in the event's own zone, not the visitor's" do
    # 00:30 UTC on Saturday is 7:30 pm on Friday in New York. A first-time
    # visitor has no browser_timezone cookie, so the request runs in UTC.
    event = events(:mystery_flight)
    start = Time.utc(2027, 1, 16, 0, 30)
    event.update_columns(time_zone: "Eastern Time (US & Canada)", start_time: start, end_time: start + 2.hours)
    get root_path
    assert_response :success
    assert_select ".f3 .sl .top", text: "Fri · 7:30 pm EST"
    assert_select ".f3 .sl .date", text: "Jan 15"
  end

  test "an upcoming night at a private society never reaches the invite" do
    Event.where("start_time > ?", Time.current).update_all(start_time: 1.day.ago)
    secret = events(:allocated_night)
    secret.update_columns(start_time: 1.week.from_now, end_time: 1.week.from_now + 2.hours)
    get root_path
    assert_response :success
    assert_select ".f3 .sl", text: /Sample invite/
    assert_select ".f3 a", count: 0
    assert_no_match secret.title, response.body
  end

  test "the invite shows at most five guests and the full going count" do
    event = events(:mystery_flight)
    6.times do |i|
      user = User.create!(email: "guest#{i}@example.com", password: "password123", first_name: "Guest#{i}", last_name: "Taster")
      EventRsvp.new(user: user, event: event, status: "yes").save!(validate: false)
    end
    assert_equal 7, event.yes_count # seth's fixture RSVP plus six
    get root_path
    assert_select ".f3 .sl .guests .faces > *", count: 5
    assert_select ".f3 .sl .guests", text: /7 going/
  end

  test "a night nobody has said yes to shows no guest row" do
    EventRsvp.where(event: events(:mystery_flight)).delete_all
    get root_path
    assert_select ".f3 a.sl .ev", text: events(:mystery_flight).title
    assert_select ".f3 .sl .guests", count: 0
  end

  # --- Beat 4: the tasting record -------------------------------------------

  test "a revealed public night with reviews still shows the verdict" do
    get root_path
    assert_response :success
    assert_select ".f4 h4", text: "The verdict"
    assert_select ".f4 .review", count: 0
  end

  test "without a verdict the face shows the latest review with its palate wheel" do
    Review.where.not(event_id: nil).destroy_all
    review = Review.create!(user: users(:jane), bottle: bottles(:lagavulin), rating: 4.5,
                            notes: "Peat smoke and sea spray.", nose: "Smoke",
                            flavor_wheel: { "smoky" => "0.9", "coastal" => "0.6" })
    get root_path
    assert_response :success

    assert_select ".f4 h4", text: "The tasting record"
    assert_select ".f4 .review", count: 1
    assert_select ".f4 .review a[href=?]", bottle_path(review.bottle), text: review.bottle.name
    assert_select ".f4 .review a[href=?]", profile_path(review.user), text: "Jane Smith"
    assert_select ".f4 .review [data-score='4.5']", count: 1
    assert_select ".f4 .review svg[aria-label='Palate wheel for this tasting']", count: 1
    assert_select ".f4 .review a[href=?]", review_path(review), text: /Read the full tasting/
    refute_includes face_text(".f4"), users(:jane).email
  end

  test "a review with an empty flavor wheel and no flavor words shows its notes and score, no wheel" do
    Review.destroy_all
    review = Review.create!(user: users(:jane), bottle: bottles(:lagavulin), rating: 3.0,
                            notes: "Quiet. A good one for the end of the night.", flavor_wheel: {})
    assert_empty review.wheel_display_profile
    get root_path
    assert_response :success

    assert_select ".f4 .review", count: 1
    assert_select ".f4 .review [data-score='3']", count: 1
    assert_select ".f4 .review", text: /A good one for the end of the night/
    assert_select ".f4 svg[aria-label='Palate wheel for this tasting']", count: 0
  end

  test "a review with a wheel is preferred over a newer review without one" do
    Review.destroy_all
    with_wheel = Review.create!(user: users(:jane), bottle: bottles(:lagavulin), rating: 4.0,
                                flavor_wheel: { "sweet" => "0.8" }, created_at: 2.days.ago)
    Review.create!(user: users(:john), bottle: bottles(:lagavulin), rating: 2.0, notes: "Fine.")
    get root_path
    assert_select ".f4 .review a[href=?]", review_path(with_wheel), count: 1
  end

  test "a review from a private society's night is never featured" do
    private_review = reviews(:jane_allocated_four_roses)
    Review.where.not(id: private_review.id).destroy_all
    private_review.update_columns(flavor_wheel: { "sweet" => "0.9" }, created_at: 1.minute.from_now)
    get root_path
    assert_response :success
    assert_select ".f4 .review", count: 0
    assert_select ".f4 a[href=?]", review_path(private_review), count: 0
    assert_select ".f4 h4", text: "The tasting record"
  end

  test "a review from a public night whose pours are still secret is never featured" do
    Review.destroy_all
    night = events(:mystery_flight)
    night.update_columns(pours_hidden_until_complete: true)
    refute night.reload.pours_revealed?
    secret = Review.new(user: users(:seth), bottle: bottles(:lagavulin), event: night, rating: 4.0,
                        flavor_wheel: { "smoky" => "0.9" })
    secret.save!(validate: false)
    solo = Review.create!(user: users(:jane), bottle: bottles(:eagle_rare), rating: 3.5,
                          flavor_wheel: { "oaky" => "0.5" }, created_at: 1.day.ago)
    get root_path
    assert_response :success
    assert_select ".f4 a[href=?]", review_path(secret), count: 0
    assert_select ".f4 .review a[href=?]", review_path(solo), count: 1
  end

  test "with no reviews at all the face keeps its heading and renders nothing else" do
    Review.destroy_all
    get root_path
    assert_response :success
    assert_select ".f4 h4", text: "The tasting record"
    assert_select ".f4 .review", count: 0
    assert_select ".f4 svg[aria-label='Palate wheel for this tasting']", count: 0
  end

  # --- Pricing ----------------------------------------------------------------

  def plan_card(name)
    css_select("#pricing a.plan").find { |card| card.at_css("h3")&.text&.strip == name }
  end

  test "each plan card shows its name, per-month price, billing period and savings" do
    get root_path
    assert_response :success

    assert_select "#pricing a.plan[href=?]", membership_path, count: 3
    monthly, quarterly, yearly = plan_card("Monthly"), plan_card("Quarterly"), plan_card("Yearly")
    assert monthly && quarterly && yearly, "expected a card per plan"

    assert_match "$15.99", monthly.text
    assert_match "billed monthly", monthly.text
    assert_no_match(/Save/, monthly.text)

    assert_match "$12.99", quarterly.text
    assert_match "billed quarterly", quarterly.text
    assert_match "Save 19%", quarterly.text

    assert_match "$10.99", yearly.text
    assert_match "billed annually", yearly.text
    assert_match "Save 31%", yearly.text
    css_select("#pricing a.plan").each { |card| assert_match "/mo", card.text }
  end

  test "exactly one plan card is marked best value, the yearly plan, as on the membership page" do
    get root_path
    assert_select "#pricing a.plan", text: /Best value/, count: 1
    assert_match(/Best value/, plan_card("Yearly").text)
    assert_select "#pricing a.plan.plan--pick", count: 1
  end
end
