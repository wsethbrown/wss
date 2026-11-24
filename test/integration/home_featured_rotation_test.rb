require "test_helper"

# The homepage features one deck per page: an admin-featured deck, else the
# three best sellers in turn (HomepageFeature). The hero, the spotlight tile,
# the library row the frame picks and the tasting record must all be that
# deck's, from one choice.
class HomeFeaturedRotationTest < ActionDispatch::IntegrationTest
  def config
    JSON.parse(css_select(".story > .mm").first["data-config"])
  end

  def roll(name)
    host = css_select(".mm [data-mm=#{name}]").first
    el = host.matches?(".mm-roll") ? host : host.at_css(".mm-roll")
    JSON.parse(el["data-states"])
  end

  def deck(title, at:)
    deck = Presentation.create!(author: users(:admin), title: title, content: "A story.", price: 9.99, category: "Bourbon")
    deck.update_columns(published: true, created_at: at, updated_at: at)
    deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "s.jpg", content_type: "image/jpeg")
    deck
  end

  def reviewed_bottle(name, at:)
    bottle = Bottle.create!(name: name, distillery: "Test Distillery")
    Review.new(user: users(:john), bottle: bottle, rating: 4.5, notes: "Real notes.", flavor_wheel: { "sweet" => 0.6 })
          .tap { |r| r.save!(validate: false) }.update_columns(created_at: at)
    bottle
  end

  setup do
    Review.destroy_all # no verdict night, no other reviews
    @decks = [ deck("Alpha Deck", at: 1.day.ago), deck("Bravo Deck", at: 2.days.ago), deck("Charlie Deck", at: 3.days.ago) ]
    @bottles = [ reviewed_bottle("Alpha Bottle", at: 3.days.ago), reviewed_bottle("Bravo Bottle", at: 2.days.ago), reviewed_bottle("Charlie Bottle", at: 1.day.ago) ]
    @decks.zip(@bottles) { |d, b| d.presentation_bottles.create!(bottle: b) }
    sign_in users(:admin) # ?rotation= is an admin preview
  end

  test "each place in the rotation shows its own deck everywhere, with its own bottle on the record" do
    @decks.each_with_index do |deck, i|
      get root_path(rotation: i + 1)
      assert_response :success
      assert_equal deck, controller.instance_variable_get(:@showcase_deck)
      # The hero (static face and frame), the spotlight tile and the frame's library row.
      assert_select ".face.f1 .player b", text: deck.title
      assert_equal deck.title, roll("title").first
      assert_select ".tile.spot h2", text: deck.title
      assert_equal i, config["picked"], "the frame picks this deck's row among the latest decks (newest first)"
      assert_equal (@decks - [ deck ]).map(&:title), css_select(".mm .mm-row .mm-rt").map(&:text), "the other rows are the other decks"
      # The record: this deck's bottle leads, in the face and in the frame.
      review = controller.instance_variable_get(:@featured_review)
      assert_equal @bottles[i], review.bottle
      assert_select ".face.f4 a[href=?]", bottle_path(@bottles[i]), minimum: 1
      assert_select ".face.f4 a[href=?]", review_path(review)
      (@bottles - [ @bottles[i] ]).each { |other| assert_select ".face.f4 a[href=?]", bottle_path(other), 0 }
      assert_equal "review", config["record"], "the other two reviews belong to the other decks, so this one stands alone"
    end
  end

  test "the day decides the deck: the same all day, the next deck the next day" do
    get root_path
    today = controller.instance_variable_get(:@showcase_deck)
    get root_path
    assert_equal today, controller.instance_variable_get(:@showcase_deck)
    travel 1.day do
      get root_path
      tomorrow = controller.instance_variable_get(:@showcase_deck)
      assert_equal @decks[(@decks.index(today) + 1) % 3], tomorrow
    end
  end

  test "an admin-featured deck wins over the rotation and takes the spotlight" do
    @decks[2].update_column(:featured, true)
    [ nil, 1, 2 ].each do |slot|
      get root_path(rotation: slot)
      assert_equal @decks[2], controller.instance_variable_get(:@showcase_deck)
      assert_select ".tile.spot h2", text: "Charlie Deck"
      assert_equal @bottles[2], controller.instance_variable_get(:@featured_review).bottle
    end
  end

  test "visitors cannot pick the place with ?rotation" do
    sign_out users(:admin)
    get root_path
    usual = controller.instance_variable_get(:@showcase_deck)
    other = @decks.index(usual) == 0 ? 2 : 1
    get root_path(rotation: other)
    assert_equal usual, controller.instance_variable_get(:@showcase_deck)
  end

  test "a deck's own reviewed bottle shows even when a finished public night could" do
    # A revealed public night with event reviews: the verdict, were it not for the bottle.
    Review.new(user: users(:seth), bottle: bottles(:eagle_rare), event: events(:spring_blind), rating: 4.0).save!(validate: false)
    EventBottle.find_or_create_by!(event: events(:spring_blind), bottle: bottles(:eagle_rare)) { |p| p.position = 9 }
    get root_path(rotation: 1)
    assert_equal [], controller.instance_variable_get(:@verdict_rows)
    assert_equal @bottles[0], controller.instance_variable_get(:@featured_review).bottle
    assert_select ".face.f4 h4", text: "The tasting record"

    @decks[0].presentation_bottles.destroy_all
    get root_path(rotation: 1)
    assert controller.instance_variable_get(:@verdict_rows).present?, "with no reviewed bottle of its own the finished night shows, as before"
    assert_select ".face.f4 h4", text: "The verdict"
  end

  test "a deck with no reviewed bottle of its own shows the sample review, labelled, with no reviewer or link" do
    @decks[1].presentation_bottles.destroy_all
    get root_path(rotation: 2)
    assert_nil controller.instance_variable_get(:@featured_review)
    assert_equal HomepageFeature::SAMPLE, controller.instance_variable_get(:@sample_review)
    # The face: the bottle named, said to be a sample, its score and wheel; no real bottle, reviewer or tasting linked.
    assert_select ".face.f4 h4", text: "The tasting record"
    assert_select ".face.f4 .rv-bottle", text: "Weller Antique 107"
    assert_select ".face.f4 .where", text: "Sample review"
    assert_select ".face.f4 .rv-card .rv-wheel svg", 1
    assert_select ".face.f4 .rv-card [data-score='4.0'], .face.f4 .rv-card [data-score='4']", 1
    assert_select ".face.f4 a.rv-more, .face.f4 .rv-by, .face.f4 .rv-rows, .face.f4 a.rv-bottle", 0
    @bottles.each { |b| assert_select ".face.f4 a[href=?]", bottle_path(b), 0 }
    # The frame: one review's layout, the label where the distillery goes.
    assert_equal "review", config["record"]
    assert_equal 1, config["record_glasses"]
    assert_equal [ 0.8 ], config["levels"]
    assert_equal true, config["wheel"]
    assert_equal "Weller Antique 107", roll("title")[2]
    assert_equal "Sample review", roll("meta")[2]
    assert_select ".mm .mm-card .wheel-wedge", HomepageFeature::SAMPLE.wheel.size
    assert_select ".mm [data-mm=review]", 0
    # The other two days keep their own bottles.
    get root_path(rotation: 1)
    assert_equal @bottles[0], controller.instance_variable_get(:@featured_review).bottle
    assert_nil controller.instance_variable_get(:@sample_review)
  end

  test "a finished public night still shows before the sample" do
    @decks[0].presentation_bottles.destroy_all
    Review.new(user: users(:seth), bottle: bottles(:eagle_rare), event: events(:spring_blind), rating: 4.0).save!(validate: false)
    EventBottle.find_or_create_by!(event: events(:spring_blind), bottle: bottles(:eagle_rare)) { |p| p.position = 9 }
    get root_path(rotation: 1)
    assert controller.instance_variable_get(:@verdict_rows).present?
    assert_nil controller.instance_variable_get(:@sample_review)
    assert_select ".face.f4 .where", text: "Sample review", count: 0
  end
end
