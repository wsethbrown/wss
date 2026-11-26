require "test_helper"

# Concept 4, "The Theatre of the Pour" (/concepts/4): the live homepage's data
# (the same selection, StoryFrameHelper), each beat real HTML that stands on
# its own without JS. Nothing on the page is invented: a name or a number is
# in the database, or it is one of the live homepage's two labelled samples.
class ConceptFourTest < ActionDispatch::IntegrationTest
  # The pours the concept used to type into its view and its controller.
  OLD_POURS = [ "Buffalo Trace", "Maker's Mark 46", "Heaven Hill 7yr BiB", "Wild Turkey Rare Breed", "4.65", "116.8" ].freeze

  def config
    JSON.parse(css_select(".c4[data-controller=concept-four]").first["data-concept-four-config-value"])
  end

  def texts(selector)
    css_select(selector).map { |el| el.text.squish }
  end

  def published_deck(title, slides: 0, at: Time.current)
    deck = Presentation.create!(author: users(:admin), title: title, content: "A story.", price: 9.99, category: "Scotch")
    deck.update_columns(published: true, created_at: at, updated_at: at)
    slides.times { |n| deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "s#{n}.png", content_type: "image/png") }
    deck
  end

  def assert_no_old_pours
    OLD_POURS.each { |old| assert_no_match(/#{Regexp.escape(old)}/, response.body, "the old hardcoded pour data (#{old}) is gone") }
    script = Rails.root.join("app/javascript/controllers/concept_four_controller.js").read
    OLD_POURS.each { |old| assert_no_match(/#{Regexp.escape(old)}/, script) }
    assert_no_match(/proof|score:|wheel: \[/, script, "the controller carries no pour data")
  end

  test "five beats of real content, stacked: the server never sends the live state" do
    get home_concept_path(4)
    assert_response :success
    assert_select ".c4.is-live", 0
    assert_select ".c4-stage > section.c4-beat[data-concept-four-target=beat]", 5
    assert_equal [ "Every pourhas a story.", "Pick a deck", "Gather your society", "Pour and present" ], texts(".c4-beat h1, .c4-beat h2").first(4)
    # The travelling objects are presentational; the beats carry the content.
    assert_select ".c4-screen[aria-hidden=true]", 1
    assert_select ".c4-glass:not([aria-hidden=true])", 0
    # No letterspaced labels above headings, no on-screen instructions.
    assert_no_match(/Act I|Est\. 2019 ·|In the spotlight|Click |Hover or tap|to swap/i, css_select(".c4").first.text)
    assert_no_match(/—/, css_select(".c4").first.text, "no em dashes")
    assert_no_old_pours
  end

  test "no events and no reviews: the labelled samples, nothing invented" do
    Review.destroy_all
    Event.destroy_all
    deck = published_deck("Sample Night Deck", slides: 2)
    deck.presentation_bottles.create!(name: "Free Text Pour", label: "Pour 1")
    get home_concept_path(4)
    assert_response :success
    assert_equal deck, controller.instance_variable_get(:@showcase_deck)
    # The sample invite, said to be one, linking nowhere, the picked deck riding on it.
    assert_select "a.c4-invite", 0
    assert_select "div.c4-invite .c4-tag", text: "Sample invite"
    assert_select ".c4-invite .c4-what b", text: "Bourbon night"
    assert_select ".c4-invite .c4-guests > b", text: "5 going"
    assert_select ".c4-invite [data-slot=glass]", 4
    assert_select ".c4-invite .c4-invite-deck [data-slot=deck]", 1
    assert_equal true, config["invite"]["sample"]
    # The sample review, said to be one, with no link to a tasting.
    assert_select ".c4-beat--verdict h2", text: "The tasting record"
    assert_select ".c4-beat--verdict .c4-rank--plain b", text: "Weller Antique 107"
    assert_select ".c4-beat--verdict .c4-rank--plain small", text: "Sample review"
    assert_select ".c4-beat--verdict a.c4-rank", 0
    assert_equal [ (HomepageFeature::SAMPLE.rating / 5.0).round(3) ], config["record"]["levels"]
    assert_no_old_pours
  end

  test "with no record at all the last beat is its heading alone" do
    shape = ApplicationController.helpers.story_frame(showcase: nil, showcase_slides: [], decks: [], slide_count: 0, event: nil, guests: [], going: 0,
                                                      verdict_night: nil, verdict_rows: [], verdict_reviews: [], review: nil)
    c4 = ApplicationController.helpers.concept_four(shape, showcase_slides: [])
    assert_equal :empty, shape[:record][:kind]
    assert_equal [], c4[:config][:record][:levels]
    assert_equal [], c4[:decks]
  end

  test "the pour beat lists each deck's own pour list, the featured deck's shown" do
    Presentation.update_all(published: false)
    bottle = bottles(:lagavulin)
    deck = published_deck("Pouring Deck", slides: 2)
    deck.presentation_bottles.create!(bottle: bottle, label: "Pour 1 · 86 proof")
    deck.presentation_bottles.create!(name: "A Cocktail", style: "Stirred")
    other = published_deck("Other Deck", at: 1.day.ago)
    5.times { |n| other.presentation_bottles.create!(name: "Other pour #{n + 1}") }
    get home_concept_path(4)
    assert_equal deck, controller.instance_variable_get(:@showcase_deck)
    assert_select ".c4-pours:not([hidden])", 1
    assert_equal [ bottle.name, "A Cocktail" ], texts(".c4-pours[data-for-deck='#{deck.id}']:not([hidden]) .c4-pour-text b")
    assert_equal [ "Pour 1 · 86 proof", "Stirred" ], texts(".c4-pours[data-for-deck='#{deck.id}'] .c4-pour-text small")
    # Another deck's list waits hidden for a pick, four glasses at most.
    assert_equal (1..4).map { |n| "Other pour #{n}" }, texts(".c4-pours[data-for-deck='#{other.id}'][hidden] .c4-pour-text b")
    assert_equal deck.id, config["deck"]
    assert_equal 2, config["decks"][deck.id.to_s]["pours"]
    # The reel is the deck's free-preview slides only, as the live hero's is.
    assert_equal ApplicationController.helpers.hero_reel_slides(deck).size, config["decks"][deck.id.to_s]["slides"]
    assert_select ".c4-screen .c4-reel[data-for-deck='#{deck.id}'] img", config["decks"][deck.id.to_s]["slides"]
    assert_equal 4, config["decks"][other.id.to_s]["pours"]
    # One glass for every slot any beat can ask for.
    assert_select ".c4-glass", [ 4, config["invite"]["glasses"] ].max
    # The decks are a real choice: radios, the featured deck checked.
    assert_select "fieldset.c4-decks input[type=radio][name=c4-deck]", 2
    assert_select "fieldset.c4-decks input[type=radio][checked][value='#{deck.id}']", 1
  end

  test "a real upcoming night: its title, date, place and guests, and no deck that is not its own" do
    event = events(:mystery_flight)
    6.times do |i|
      user = User.create!(email: "c4-guest#{i}@example.com", password: "password123", first_name: "Cee#{i}", last_name: "Guest")
      EventRsvp.new(user: user, event: event, status: "yes").save!(validate: false)
    end
    get home_concept_path(4)
    assert_equal event, controller.instance_variable_get(:@next_event)
    local = event.start_time.in_time_zone(event.effective_time_zone)
    assert_select "a.c4-invite[href='#{event_path(event)}']", 1
    assert_select ".c4-invite .c4-tag", 0
    assert_select ".c4-invite .c4-date", text: local.strftime("%b %-d")
    assert_select ".c4-invite .c4-what b", text: event.title
    assert_match event.society.name, texts(".c4-invite .c4-what span").first
    assert_select ".c4-invite .c4-guests > b", text: "#{event.yes_count} going"
    assert_select ".c4-invite [data-slot=glass]", 4, "more than four guests cap at four glasses"
    assert_equal false, config["invite"]["sample"]
    assert_select ".c4-invite .c4-invite-deck", 0, "the night has no deck, so none rides on its invite"
    assert_no_match(/Bourbon night|Sample invite/, response.body)
  end

  test "the night's own deck rides on its invite" do
    deck = published_deck("The Night's Deck", slides: 1)
    events(:mystery_flight).update_columns(presentation_id: deck.id)
    get home_concept_path(4)
    assert_equal deck, controller.instance_variable_get(:@showcase_deck)
    assert_select ".c4-invite .c4-invite-deck [data-slot=deck][data-only-deck='#{deck.id}']", 1
    assert_select ".c4-invite .c4-invite-deck small", text: "The Night's Deck"
  end

  test "a revealed verdict: that night's pours, ranked, with the room's scores and its wheel" do
    get home_concept_path(4)
    night = controller.instance_variable_get(:@verdict_night)
    rows = controller.instance_variable_get(:@verdict_rows)
    assert rows.present?, "fixtures carry a revealed public night"
    shown = rows.first(3)
    assert_select ".c4-beat--verdict[data-kind=verdict] h2", text: "The verdict"
    assert_select ".c4-beat--verdict .c4-where a[href='#{society_event_path(night.society, night)}']", text: night.title
    assert_equal shown.map { |r| r[:pour].bottle.name }, texts(".c4-ranks .c4-rank b")
    scores = shown.map { |r| ActiveSupport::NumberHelper.number_to_rounded(r[:mean], precision: 2, strip_insignificant_zeros: true) }
    assert_equal scores.map { |s| "#{s} out of 5" }, texts(".c4-ranks .c4-rank-s")
    assert_equal shown.map { |r| (r[:mean] / 5.0).round(3) }, config["record"]["levels"]
    assert_equal shown.map { |r| bottle_path(r[:pour].bottle) }, css_select(".c4-ranks a.c4-rank").map { |a| a["href"] }
    assert_equal scores, scores.sort_by { |s| -s.to_f }, "best first"
    # Only those pours: no other bottle is named on the record.
    others = Bottle.where.not(id: shown.map { |r| r[:pour].bottle_id }).pluck(:name)
    record = css_select(".c4-beat--verdict").first.text
    others.each { |name| assert_no_match(/#{Regexp.escape(name)}/, record) }
    if Review.blended_wheel(controller.instance_variable_get(:@verdict_reviews)).any?
      assert_select ".c4-beat--verdict .c4-wheel svg .wheel-wedge[data-pour]", minimum: 1
    end
    assert_no_match(/Sample review|Weller Antique 107/, response.body)
    assert_no_old_pours
  end

  test "the other concepts and the live homepage still render" do
    (1..3).each do |n|
      get home_concept_path(n)
      assert_response :success
    end
    get root_path
    assert_response :success
  end
end
