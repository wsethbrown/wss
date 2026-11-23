require "test_helper"

# The homepage story's frame (home/_story_frame, StoryFrameHelper,
# story_frame_controller.js): one pinned screen whose objects travel from step
# to step. The server sends it hidden and presentational; the static faces
# beside each step's words stay the page without JS, in print and for screen
# readers. Its content follows the faces' rules exactly.
class HomeStoryFrameTest < ActionDispatch::IntegrationTest
  def frame
    css_select(".story > .mm").first
  end

  def roll(name)
    host = css_select(".mm [data-mm=#{name}]").first
    el = host.matches?(".mm-roll") ? host : host.at_css(".mm-roll")
    JSON.parse(el["data-states"])
  end

  def config
    JSON.parse(frame["data-config"])
  end

  # The revealed public night the verdict comes from (the fixtures carry one).
  def controller_verdict_night
    get root_path
    controller.instance_variable_get(:@verdict_night)
  end

  def published_deck(title, slides: 0, at: Time.current)
    deck = Presentation.create!(author: users(:admin), title: title, content: "A story.", price: 9.99, category: "Scotch")
    deck.update_columns(published: true, created_at: at, updated_at: at)
    slides.times { |n| deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "s#{n}.png", content_type: "image/png") }
    deck
  end

  test "one frame, inside the story the controller runs, sent hidden and presentational" do
    get root_path
    assert_response :success
    assert_select ".story[data-controller=story-frame]", 1
    assert_select ".story > .mm[aria-hidden=true][data-story-frame-target=frame]", 1
    assert_select ".story [data-story-frame-target=beat]", 5
    # The server never sends the live state: without JS the faces show.
    assert_select ".story.is-live", 0
    css = css_select("style").map(&:text).join("\n")
    assert_match(/\.hx \.mm \{ display: none; \}/, css)
    assert_match(/\.hx \.story\.is-live \.mm \{ display: block; \}/, css)
    # It joins no reveal: it moves itself.
    assert_select ".mm [data-appear-target]", 0
    assert_select ".mm img[alt]:not([alt=''])", 0
  end

  test "the static faces stay, one per step, in reading order after each step's words" do
    get root_path
    story = css_select(".story").first
    order = story.children.select(&:element?).map { |el| (el["class"].to_s.split & %w[b1 f1 b2 f2 b3 f3 b4 f4 beat--close]).first }.compact
    assert_equal %w[b1 f1 b2 f2 b3 f3 b4 f4 beat--close], order
    %w[.f1 .f2 .f3 .f4].each { |f| assert_select ".story > .face#{f}", 1 }
    css = css_select("style").map(&:text).join("\n")
    assert_match(/\.story\.is-live \.face:not\(:focus-within\)/, css, "live: faces are kept for screen readers, and show if focus reaches into one")
    assert_match(/@media screen \{\s*\.hx \.story\.is-live \.face:not\(:focus-within\)/, css, "faces are hidden on screen only, so print shows every face")
    assert_match(/@media print \{ \.hx \.mm \{ display: none !important; \}/, css, "print never shows the frame")
  end

  test "the library rows are the latest decks, and the picked one is the hero's deck, its slide the hero's" do
    older = published_deck("Older Deck", at: 3.days.ago)
    showcase = published_deck("Showcase Deck", slides: 2, at: 2.days.ago)
    newest = published_deck("Newest Deck", at: 1.day.ago)
    get root_path
    assert_equal showcase, controller.instance_variable_get(:@showcase_deck)
    assert_equal 3, config["rows"]
    assert_equal 1, config["picked"], "the showcase deck's own row"
    assert_equal [ "Newest Deck", "Older Deck" ], css_select(".mm .mm-row .mm-rt").map(&:text)
    assert_equal [ "Scotch · $9.99" ] * 2, css_select(".mm .mm-row .mm-rm").map(&:text)
    assert_equal [ "Showcase Deck", "Bourbon night" ], roll("title").first(2) if config["sample"]
    assert_equal "Showcase Deck", roll("title").first
    assert_equal "Scotch · $9.99", roll("meta").first
    assert_select ".mm [data-mm=slide] img", 1
    assert_equal [ "Showcase Deck", "The library" ], JSON.parse(css_select(".mm [data-mm=cap-l]").first["data-states"]).first(2)
    assert_equal "2 slides", JSON.parse(css_select(".mm [data-mm=cap-r]").first["data-states"]).first
    assert newest && older
  end

  test "with no deck that has slides, the frame's slide is the faces' fallback" do
    published_deck("Plain Deck")
    get root_path
    assert_select ".mm [data-mm=slide] img", 0
    assert_select ".mm [data-mm=slide] .mm-slide-ink", text: "Every pour has a story."
    assert_equal "Whiskey Share Society", JSON.parse(css_select(".mm [data-mm=cap-l]").first["data-states"]).first
    assert_equal "Plain Deck", roll("title").first
  end

  test "a showcase deck that is not among the latest takes the last row" do
    decks = (1..4).map { |n| published_deck("Deck #{n}", at: n.days.ago) }
    showcase = decks.last
    shape = ApplicationController.helpers.story_frame(showcase: showcase, showcase_slides: [], decks: decks.first(3) - [ showcase ],
                                                      slide_count: 0, event: nil, guests: [], going: 0, verdict_night: nil, verdict_rows: [], verdict_reviews: [], review: nil)
    assert_equal showcase, shape[:rows].last[:deck]
    assert_equal shape[:rows].size - 1, shape[:picked]
    assert_operator shape[:rows].size, :<=, 3
    assert_equal :empty, shape[:record][:kind]
    assert_equal true, shape[:invite][:sample]
  end

  test "long titles are cut cleanly for the frame, never in the faces" do
    long = "An Extremely Long Deck Title That Keeps Going Well Past Any Row"
    deck = published_deck("Short")
    shape = ApplicationController.helpers.story_frame(showcase: nil, showcase_slides: [], decks: [ deck.tap { |d| d.title = long } ],
                                                      slide_count: 0, event: nil, guests: [], going: 0, verdict_night: nil, verdict_rows: [], verdict_reviews: [], review: nil)
    assert_operator shape[:rows].first[:title].length, :<=, 40
    assert shape[:rows].first[:title].end_with?("..."), shape[:rows].first[:title]
  end

  test "a real night: its time, date, title and place, one glass per guest up to four, the full count" do
    event = events(:mystery_flight)
    6.times do |i|
      user = User.create!(email: "frame-guest#{i}@example.com", password: "password123", first_name: "Frame#{i}", last_name: "Guest")
      EventRsvp.new(user: user, event: event, status: "yes").save!(validate: false)
    end
    get root_path
    assert_equal event.title.truncate(24, separator: " "), roll("title")[1]
    assert_match event.society.name, roll("meta")[1]
    assert_equal [ "", "7 going", "" ], roll("going")
    assert_equal 4, config["invite_glasses"], "more than four guests cap at four glasses"
    assert_equal false, config["sample"]
    initials = css_select(".mm [data-mm=label] .mm-roll").map { |r| JSON.parse(r["data-states"])[1] }
    assert_equal 4, initials.count(&:present?)
    assert_select ".mm [data-mm=tag]", 0, "only the sample invite carries its tag"
  end

  test "without an upcoming public night the frame draws the faces' sample invite" do
    Event.where("start_time > ?", Time.current).update_all(start_time: 1.day.ago)
    get root_path
    assert_equal true, config["sample"]
    assert_equal "Bourbon night", roll("title")[1]
    assert_equal "Your society · Your place", roll("meta")[1]
    assert_equal [ "", "5 going", "" ], roll("going")
    assert_equal [ "", "Sample invite", "" ], roll("tag")
    assert_equal 4, config["invite_glasses"]
    assert_equal true, config["slide_in_invite"], "the sample is an illustration, so the deck rides along"
  end

  test "a night nobody has said yes to has no guest glasses or count" do
    EventRsvp.where(event: events(:mystery_flight)).delete_all
    get root_path
    assert_equal 0, config["invite_glasses"]
    assert_equal [ "", "", "" ], roll("going")
  end

  test "the record is the verdict: top three pours with the room's scores and the night's wheel" do
    get root_path
    rows = controller.instance_variable_get(:@verdict_rows)
    assert rows.present?, "fixtures carry a revealed public night"
    assert_equal "verdict", config["record"]
    assert_equal [ "", "The verdict" ], roll("heading")
    shown = rows.first(3)
    assert_equal shown.size, config["record_glasses"]
    assert_equal shown.map { |r| (r[:mean] / 5.0).round(3) }, config["levels"]
    names = css_select(".mm [data-mm=label] .mm-roll").map { |r| JSON.parse(r["data-states"])[2] }.compact_blank
    assert_equal shown.map { |r| r[:pour].bottle.name.truncate(22, separator: " ") }, names
    assert_select ".mm [data-mm=score]", shown.size
    if config["wheel"]
      assert_select ".mm .mm-card svg .wheel-wedge[data-pour]", minimum: 1
      css_select(".mm .mm-card .wheel-wedge").each { |w| assert_includes 0...shown.size, w["data-pour"].to_i }
    end
  end

  test "without a verdict the record is the featured review, its glass landing on the review's score" do
    societies(:single_malt).update_column(:is_private, true)
    get root_path
    review = controller.instance_variable_get(:@featured_review)
    assert review
    assert_equal "review", config["record"]
    assert_equal [ "", "The tasting record" ], roll("heading")
    assert_equal review.bottle.name.truncate(20, separator: " "), roll("title")[2]
    assert_equal 1, config["record_glasses"]
    assert_select ".mm .mm-card [data-mm=card-score] [data-score]", 1
    assert_select ".mm [data-mm=review]", 1
  end

  test "with no reviews at all the record is its heading alone" do
    Review.destroy_all
    get root_path
    assert_equal "empty", config["record"]
    assert_equal 0, config["record_glasses"]
    assert_equal "", roll("title")[2]
    assert_select ".mm [data-mm=card], .mm [data-mm=review], .mm [data-mm=score]", 0
  end

  test "at the table, one glass per guest who said yes (at most four), captioned glass by glass" do
    get root_path
    assert_equal config["invite_glasses"], config["table"]
    assert_equal [ config["table"], config["record_glasses"] ].max, config["seats"]
    assert_select ".mm [data-mm=glass] svg[data-glass]", config["seats"]
    assert_select ".mm [data-mm=glass] svg[data-appear-target]", 0
    caps = JSON.parse(css_select(".mm [data-mm=cap-r]").first["data-states"])
    assert_equal (1..config["table"]).map { |k| "Glass #{k} of #{config['table']}" }, caps[2..-2]
  end

  test "a real night nobody has said yes to never shows people at the table" do
    EventRsvp.where(event: events(:mystery_flight)).delete_all
    get root_path
    assert_equal false, config["sample"]
    assert_equal 0, config["table"], "no seat glasses on a real night with no yeses"
    caps = JSON.parse(css_select(".mm [data-mm=cap-r]").first["data-states"])
    assert_empty caps.grep(/Glass/), "no glass count either"
    # The verdict's pours still reach the record (they rise straight into it).
    assert_equal config["record_glasses"], config["seats"]
  end

  test "every string in the frame reaches the page as plain text, escaped exactly once" do
    tricky = %(Maker's <b>Mark</b> & Co)
    deck = published_deck(tricky, slides: 1)
    event = events(:mystery_flight)
    event.update_columns(title: tricky)
    event.society.update_columns(name: tricky)
    night = controller_verdict_night
    night.event_bottles.first.bottle.update_columns(name: tricky)
    get root_path
    assert_equal deck, controller.instance_variable_get(:@showcase_deck)
    cut = ->(n) { tricky.truncate(n, separator: " ") }
    assert_equal cut.(40), roll("title")[0], "the picked row's title"
    assert_equal cut.(24), roll("title")[1], "the night's title"
    assert_equal [ tricky, event.reload.location.presence ].compact.join(" · ").truncate(34, separator: " "), roll("meta")[1], "the night's place"
    caps = JSON.parse(css_select(".mm [data-mm=cap-l]").first["data-states"])
    assert_equal tricky, caps[0], "the hero caption"
    labels = css_select(".mm [data-mm=label] .mm-roll").map { |r| JSON.parse(r["data-states"])[2] }
    assert_includes labels, cut.(22), "a pour's name"
    all = css_select(".mm .mm-roll").flat_map { |r| JSON.parse(r["data-states"]) }.join(" ")
    refute_match(/&amp;|&#39;|&lt;/, all, "nothing is escaped twice")
    refute_match(/&amp;amp;|&amp;#39;/, response.body)
  end

  test "the frame shows no private or still-secret night" do
    get root_path
    assert_no_match "Allocated Bottles Night", frame.to_s
  end
end
