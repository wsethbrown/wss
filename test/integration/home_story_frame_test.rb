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

  # The deck the homepage features, pouring these catalog bottles: the record
  # leads with a review of the deck's own bottle (HomepageFeature).
  def featured_deck_pouring(*bottles)
    deck = published_deck("Pouring Deck", slides: 1)
    bottles.each { |b| deck.presentation_bottles.create!(bottle: b) }
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

  test "without a verdict, the featured deck's lone review is the record, its glass landing on the review's score" do
    Review.destroy_all
    bottle = Bottle.create!(name: "Lone Record Pour", distillery: "Frame Distillery")
    review = Review.new(user: users(:john), bottle: bottle, rating: 4.5, notes: "Notes.", flavor_wheel: { "smoky" => 0.5 })
    review.save!(validate: false)
    featured_deck_pouring(bottle)
    get root_path
    assert_equal review, controller.instance_variable_get(:@featured_review)
    assert_equal "review", config["record"]
    assert_equal [ "", "The tasting record" ], roll("heading")
    assert_equal review.bottle.name.truncate(20, separator: " "), roll("title")[2]
    assert_equal 1, config["record_glasses"]
    assert_select ".mm .mm-card [data-mm=card-score] [data-score]", 1
    assert_select ".mm [data-mm=review]", 1
  end

  test "with no review of the featured deck's bottles the record is the sample review, said to be one" do
    Review.destroy_all
    get root_path
    assert_equal "review", config["record"]
    assert_equal 1, config["record_glasses"]
    assert_equal "Weller Antique 107", roll("title")[2]
    assert_equal "Sample review", roll("meta")[2]
    assert_select ".mm [data-mm=card]", 1
    assert_select ".mm [data-mm=review], .mm [data-mm=score], .mm [data-mm=by]", 0
  end

  # The record without a verdict night: each drink with its review. Reviews are
  # made here, so the fixtures' own never decide the rows.
  def tasting(user, bottle, rating, at:, wheel: {}, event: nil)
    review = Review.new(user: user, bottle: bottle, event: event, rating: rating, notes: "Notes for #{bottle.name}.", flavor_wheel: wheel)
    review.save!(validate: false)
    review.update_columns(created_at: at, updated_at: at)
    review
  end

  def fresh_bottle(name)
    Bottle.create!(name: name, distillery: "Frame Distillery")
  end

  def by_states
    css_select(".mm [data-mm=by] .mm-roll").map { |r| JSON.parse(r["data-states"])[1] }
  end

  test "without a verdict, the record lists the three newest public reviews, one row per bottle" do
    Review.destroy_all
    one, two, three, four = %w[Row One Row Two Row Three Row Four].each_slice(2).map { |w| fresh_bottle(w.join(" ")) }
    newest = tasting(users(:john), one, 4.5, at: 1.hour.ago, wheel: { "smoky" => 0.6, "sweet" => 0.3 })
    tasting(users(:jane), one, 3.0, at: 2.hours.ago) # the same bottle again: not a row of its own
    second = tasting(users(:jane), two, 3.5, at: 3.hours.ago)
    third = tasting(users(:seth), three, 4.0, at: 4.hours.ago)
    tasting(users(:admin), four, 2.0, at: 5.hours.ago) # a fourth: past the three
    featured_deck_pouring(one)
    get root_path
    assert_equal [ newest, second, third ], controller.instance_variable_get(:@record_reviews)
    assert_equal "reviews", config["record"]
    assert_equal [ "", "The tasting record" ], roll("heading")
    assert_equal 3, config["record_glasses"]
    assert_equal [ 0.9, 0.7, 0.8 ], config["levels"], "each row's glass is its review's score out of 5"
    assert_equal true, config["wheel"]
    names = css_select(".mm [data-mm=label] .mm-roll").map { |r| JSON.parse(r["data-states"])[2] }.compact_blank
    assert_equal [ "Row One", "Row Two", "Row Three" ], names
    assert_equal [ "4.5", "3.5", "4" ], css_select(".mm [data-mm=score] .mm-roll").map { |r| JSON.parse(r["data-states"])[1] }
    assert_equal [ "John Doe", "Jane Smith", "Seth Brown" ], by_states
    assert_select ".mm [data-mm=vline]", 3
    assert_equal "", roll("title")[2], "no night, so no night's title"
    # The card is the first row's review: its score and its wheel.
    assert_select ".mm .mm-card [data-mm=card-score] [data-score='4.5']", 1
    assert_select ".mm .mm-card .wheel-wedge", 2
    assert_select ".mm [data-mm=review] .mm-rv-quote", 0
    assert_select ".mm [data-mm=review] .mm-rv-more", text: /Read the full tasting/
    # The face carries the same rows, linked, and the link to the first row's tasting.
    assert_select ".face.f4 .rv-rows li.pour", 3
    assert_equal [ bottle_path(one), bottle_path(two), bottle_path(three) ], css_select(".face.f4 .rv-rows li.pour > .rv-who > a:first-child").map { |a| a["href"] }
    assert_equal [ "John Doe", "Jane Smith", "Seth Brown" ], css_select(".face.f4 .rv-rows .rv-name").map { |a| a.text.strip }
    assert_equal [ "4.5", "3.5", "4" ], css_select(".face.f4 .rv-rows li.pour > span[data-score-text]").map { |s| s.text.sub("out of 5", "").strip }
    assert_select ".face.f4 a.rv-more[href=?]", review_path(newest)
    assert_select ".face.f4 .rv-card .rv-wheel svg", 1
  end

  test "the rows take only reviews the single review could take: none from a private or still-secret night" do
    Review.destroy_all
    private_night = events(:mystery_flight)
    private_night.society.update_column(:is_private, true)
    tasting(users(:john), fresh_bottle("Private Pour"), 5, at: 1.minute.ago, event: private_night)
    a = tasting(users(:jane), fresh_bottle("Open Pour A"), 4, at: 1.hour.ago)
    b = tasting(users(:seth), fresh_bottle("Open Pour B"), 3, at: 2.hours.ago)
    featured_deck_pouring(a.bottle)
    get root_path
    assert_equal [ a, b ], controller.instance_variable_get(:@record_reviews)
    assert_equal "reviews", config["record"]
    assert_no_match "Private Pour", frame.to_s
    assert_no_match "Private Pour", css_select(".face.f4").to_s
  end

  test "with one review the record keeps the single review" do
    Review.destroy_all
    only = tasting(users(:john), fresh_bottle("Lone Pour"), 4, at: 1.hour.ago, wheel: { "smoky" => 0.5 })
    featured_deck_pouring(only.bottle)
    get root_path
    assert_empty controller.instance_variable_get(:@record_reviews)
    assert_equal only, controller.instance_variable_get(:@featured_review)
    assert_equal "review", config["record"]
    assert_select ".mm [data-mm=by]", 0
    assert_select ".face.f4 .rv-rows", 0
    assert_select ".face.f4 .rv-bottle", text: "Lone Pour"
  end

  test "the sample review has no rows either" do
    Review.destroy_all
    get root_path
    assert_equal "review", config["record"]
    assert_select ".mm [data-mm=by], .mm [data-mm=vline], .face.f4 .rv-rows", 0
  end

  test "a verdict night still wins over the reviews' rows" do
    3.times { |i| tasting(users(:john), fresh_bottle("Solo #{i}"), 4, at: i.minutes.ago) }
    get root_path
    assert_equal "verdict", config["record"]
    assert_empty controller.instance_variable_get(:@record_reviews).to_a
    assert_select ".mm [data-mm=by], .face.f4 .rv-rows", 0
  end

  test "the rows' names reach the page escaped exactly once" do
    Review.destroy_all
    tricky = %(Maker's <b>Mark</b> & Co)
    user = users(:jane)
    user.update_columns(first_name: %(O'Brien <i>&</i>), last_name: "Smith")
    lead = tasting(user, fresh_bottle(tricky), 4, at: 1.hour.ago)
    tasting(users(:john), fresh_bottle("Plain Pour"), 3, at: 2.hours.ago)
    featured_deck_pouring(lead.bottle)
    get root_path
    assert_equal "reviews", config["record"]
    labels = css_select(".mm [data-mm=label] .mm-roll").map { |r| JSON.parse(r["data-states"])[2] }
    assert_includes labels, tricky.truncate(22, separator: " ")
    assert_includes by_states, %(O'Brien <i>&</i> Smith)
    assert_select ".face.f4 .rv-rows a", text: tricky
    assert_select ".face.f4 .rv-rows .rv-name", text: %(O'Brien <i>&</i> Smith)
    refute_match(/&amp;amp;|&amp;#39;|&amp;lt;/, response.body)
    assert_no_match(/<b>Mark<\/b>/, response.body)
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

  # The longest hero title the frame takes beside the slide count in a phone's
  # bar: the title gives way and ends in an ellipsis (the browser check is in
  # test/system/home_story_frame_test.rb).
  test "the band's caption: a long title gives way to the slide count and is cut with an ellipsis" do
    long = "The Long Road From Kentucky To The Highlands and Beyond"
    published_deck(long, slides: 1)
    get root_path
    caps = JSON.parse(css_select(".mm [data-mm=cap-l]").first["data-states"])
    assert caps[0].start_with?("The Long Road"), "the showcase deck's title: #{caps[0]}"
    assert_operator caps[0].length, :<=, 44, "the hero title is cut for the frame: #{caps[0]}"
    css = css_select("style").map(&:text).join("\n")
    assert_match(/\.hx \.mm-bar > :first-child \{ flex: 0 1 auto; min-width: 0; overflow-x: clip; \}/, css, "the title's box may shrink")
    assert_match(/\.hx \.mm-bar > :first-child \.mm-rl \{ max-width: 100%; overflow-x: clip; text-overflow: ellipsis; \}/, css, "and its line ends in an ellipsis")
    assert_match(/\.hx \.mm-bar > :last-child \{[^}]*flex: none;/, css, "the slide count keeps its width")
  end
end
