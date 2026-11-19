require "test_helper"

# G1a: the glass glyph (shared/_glass) on the event page (the table, the
# verdict), the society page (the next tasting's table, the review board) and
# the homepage's fourth slide (the verdict of a public night).
class GlassPartialTest < ActiveSupport::TestCase
  # Each call is its own render, as each request is.
  def glass(**locals)
    Nokogiri::HTML5.fragment(ApplicationController.render(partial: "shared/glass", locals: locals))
  end

  test "draws the approved glass: aria-hidden, 3:4, liquid clipped to the bowl" do
    html = glass(level: 0.5, size: 40)
    svg = html.at_css("svg")
    assert_equal "true", svg["aria-hidden"]
    assert_equal "0 0 60 80", svg["viewBox"]
    assert_equal "40", svg["height"]
    assert_equal "30.0", svg["width"]
    clip = svg.at_css("clipPath")
    assert clip, "the liquid needs its clipPath"
    assert_equal "url(##{clip['id']})", svg.at_css("g")["clip-path"]
    # y = 58.5 - 0.5 * 34 = 41.5; the body starts at y + 1.2.
    assert_match(/\AM8 42.7 /, svg.css("g path").first["d"])
    assert_equal %w[#e65c00 #f47a26], svg.css("g path").map { |p| p["fill"] }
  end

  test "an empty glass has no liquid, and a glass is never below 28px" do
    svg = glass(level: 0.01, size: 12).at_css("svg")
    assert_nil svg.at_css("clipPath")
    assert_equal "28", svg["height"]
  end

  test "cream tone on green, numeral in white over a full glass, label as sr-only text" do
    html = glass(level: 0.9, tone: :cream, numeral: 2, label: "Pour 2,")
    svg = html.at_css("svg")
    assert_equal %w[#ff6d00 #ff8a33], svg.css("g path").map { |p| p["fill"] }
    assert_equal "#f6f4ee", svg.at_css("> path")["stroke"]
    assert_equal "#fff", svg.at_css("text")["fill"]
    assert_equal "Pour 2,", html.at_css(".sr-only").text

    low = glass(level: 0.3, numeral: 1).at_css("text")
    assert_equal "#16332a", low["fill"]
  end

  test "every glass on a page gets its own clipPath id, and pages do not share them" do
    html = Nokogiri::HTML5.fragment(ApplicationController.render(inline: '<% 3.times do %><%= render "shared/glass", level: 1 %><% end %>'))
    ids = html.css("clipPath").map { |c| c["id"] }
    assert_equal 3, ids.uniq.size
    refute_includes ids, glass(level: 1).at_css("clipPath")["id"]
  end
end

class GlassPagesTest < ActionDispatch::IntegrationTest
  def table_levels
    css_select("[data-role=the-table] svg").map { |svg| svg["data-glass"] }
  end

  # --- The table ------------------------------------------------------------

  test "the event page's table: a full glass per yes, and empty seats only for members" do
    event = events(:spring_blind) # john + seth said yes; admin, the third member, did not
    get society_event_path(event.society, event)
    assert_response :success
    assert_select "#event-attendees h2", text: "The table"
    assert_equal %w[1.0 1.0], table_levels, "signed out: going only, no unanswered seats"
    assert_select "[data-role=the-table]", text: /2 going/
    assert_no_match(/unanswered/, css_select("#event-attendees").text)

    sign_in users(:john)
    get society_event_path(event.society, event)
    assert_equal %w[1.0 1.0 0.0], table_levels
    assert_select "[data-role=the-table]", text: /2 going · 1 unanswered/
  end

  test "a maybe is half a glass and a no is not a seat" do
    event = events(:mystery_flight)
    EventRsvp.create!(event: event, user: users(:john), status: "maybe")
    EventRsvp.create!(event: event, user: users(:jane), status: "no")
    get society_event_path(event.society, event)
    assert_equal %w[1.0 0.5], table_levels
  end

  test "the RSVP stream redraws the table" do
    event = events(:mystery_flight)
    sign_in users(:john)
    post society_event_event_rsvps_path(event.society, event), params: { status: "yes" }, as: :turbo_stream
    assert_response :success
    assert_match 'data-role="the-table"', response.body
    assert_equal 2, Nokogiri::HTML(response.body).css("[data-role=the-table] svg[data-glass='1.0']").size
  end

  test "a private society's night shows outsiders nothing, glasses included" do
    event = events(:allocated_night)
    get society_event_path(event.society, event)
    assert_no_match "data-glass", response.body.to_s

    sign_in users(:john)
    get society_event_path(event.society, event)
    assert_no_match "data-glass", response.body.to_s
    assert_no_match "Allocated Bottles Night", response.body.to_s
  end

  # --- The verdict ----------------------------------------------------------

  test "a revealed night ranks its pours by the room, glass level = mean / 5, numeral = serve order" do
    event = events(:spring_blind)
    get society_event_path(event.society, event)
    assert_select "[data-role=verdict] h2", text: "The verdict"
    rows = css_select("[data-role=verdict-row]")
    assert_equal 3, rows.size
    # Ardbeg 4.25 (served 1st) > Four Roses 4.0 (3rd) > GlenDronach 3.25 (2nd)
    assert_match "Ardbeg 10", rows[0].text
    assert_match "Four Roses", rows[1].text
    assert_match "GlenDronach 12", rows[2].text
    assert_equal %w[0.85 0.8 0.65], rows.map { |r| r.at_css("svg")["data-glass"] }
    assert_equal %w[1 3 2], rows.map { |r| r.at_css("svg text").text }
    assert_match "4.25", rows[0].text
    assert_match "2 reviewers", rows[0].text
    assert_match "1 reviewer", rows[1].text
  end

  test "nothing of the verdict renders before the reveal, not even for the organiser, host or an admin" do
    event = events(:mystery_flight) # secret, upcoming
    pour = EventBottle.create!(event: event, bottle: bottles(:ardbeg_10), position: 1)
    Review.new(user: users(:seth), bottle: pour.bottle, event: event, rating: 5.0).save!(validate: false)
    event.update_column(:host_id, users(:seth).id)
    refute event.reload.pours_revealed?

    get society_event_path(event.society, event)
    assert_select "[data-role=verdict]", 0

    [ users(:admin), users(:seth) ].each do |viewer| # organiser + full admin, then the host
      sign_in viewer
      get society_event_path(event.society, event)
      assert_response :success
      assert_select "[data-role=verdict]", 0
      assert_no_match "The verdict", response.body
    end
  end

  # --- The society page -----------------------------------------------------

  test "the next tasting panel shows the next night's table in cream" do
    society = societies(:single_malt) # next night: mystery_flight, seth said yes
    get society_path(society)
    assert_select ".panel-ink [data-role=the-table]"
    assert_equal %w[1.0], css_select(".panel-ink [data-role=the-table] svg").map { |s| s["data-glass"] }
    assert_equal "#f6f4ee", css_select(".panel-ink [data-role=the-table] svg > path").first["stroke"]
    assert_no_match(/unanswered/, css_select(".panel-ink").text)

    sign_in users(:john)
    get society_path(society)
    assert_equal %w[1.0 0.0 0.0], css_select(".panel-ink [data-role=the-table] svg").map { |s| s["data-glass"] }
    assert_select ".panel-ink", text: /1 going · 2 unanswered/
  end

  test "review board rows show one glass and the number instead of stars" do
    get society_path(societies(:single_malt))
    row = css_select("[data-role=board-row]").first
    assert_match "Ardbeg 10", row.text
    head = row.at_css("div") # the row's summary line, not the member reviews inside <details>
    assert_equal 1, head.css("svg[data-glass]").size
    assert_equal "0.85", head.at_css("svg[data-glass]")["data-glass"]
    assert_empty head.css("svg[data-star]")
    assert_match "4.25", head.text
  end

  # --- The homepage ---------------------------------------------------------

  test "slide four shows a public revealed night's verdict, top three, cream" do
    get root_path
    slide = css_select(".f4 .sl").first
    assert_match "The verdict", slide.text
    assert_match "The Spring Blind Flight", slide.text
    assert_no_match "Allocated Bottles Night", response.body # the private club's newer night
    glasses = slide.css("svg[data-glass]")
    assert_equal %w[0.85 0.8 0.65], glasses.map { |g| g["data-glass"] }
    assert_equal "#f6f4ee", glasses.first.at_css("> path")["stroke"]
    assert_operator slide.text.index("Ardbeg 10"), :<, slide.text.index("Four Roses")
    assert_empty slide.css(".track"), "the score bars give way to the verdict"
  end

  test "without a public revealed night with scores, slide four keeps the tasting record" do
    societies(:single_malt).update_column(:is_private, true)
    get root_path
    slide = css_select(".f4 .sl").first
    assert_match "The tasting record", slide.text
    assert_empty slide.css("svg[data-glass]")
    assert_no_match "The verdict", slide.text
    assert_no_match "Allocated Bottles Night", response.body
  end

  test "a secret public night that has not ended never reaches the homepage" do
    Review.where(event: events(:spring_blind)).delete_all # the only other public night with scores
    event = events(:mystery_flight)
    event.update_columns(start_time: 1.hour.ago, end_time: 1.hour.from_now) # under way, still secret
    pour = EventBottle.create!(event: event, bottle: bottles(:ardbeg_10), position: 1)
    Review.new(user: users(:seth), bottle: pour.bottle, event: event, rating: 5.0).save!(validate: false)

    get root_path
    assert_no_match "The verdict", css_select(".f4 .sl").first.text
  end

  test "the next4 study draws the shared glass too" do
    sign_in users(:admin)
    get root_path(design: "next4")
    assert_response :success
    assert_select ".n4 svg.n4-glass[data-glass]"
  end

  test "no other hand-drawn glass is left in the app" do
    drawings = Dir[Rails.root.join("app/views/**/*.erb")].reject { |f| f.end_with?("shared/_glass.html.erb") }.select do |file|
      File.read(file).match?(/glencairn|clipPath/i)
    end
    assert_empty drawings
    refute File.exist?(Rails.root.join("app/views/home/next4/_glass.html.erb"))
  end
end
