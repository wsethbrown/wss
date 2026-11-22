require "test_helper"

# "That's the whole ritual." closes the three steps of the homepage story. It
# is the story's last beat, in the step column, not a card in a section of its
# own, and it must never depend on a scroll-driven animation to be visible.
class HomeRitualCloseTest < ActionDispatch::IntegrationTest
  CLOSE = ".story > .beat--close".freeze

  test "the closing line is the last beat of the steps story" do
    get root_path
    assert_response :success

    story = css_select(".story").first
    assert story, "expected the steps story"
    last = story.element_children.last
    assert_includes last["class"].split, "beat--close", "the closing beat must end the story"

    assert_select CLOSE, count: 1 do
      assert_select "h2", text: "That's the whole ritual.", count: 1
      assert_select "p", text: "Pick your first deck and set a date. The deck recommends some bottles to buy.", count: 1
      assert_select "a.btn2[href='#{presentations_path}']", text: "Browse the decks", count: 1
    end
  end

  test "the closing line no longer sits in a separate card or section" do
    get root_path
    assert_response :success

    assert_select ".tile--ink", count: 0
    assert_select "section h2, section h3", text: "That's the whole ritual.", count: 0
  end

  test "the closing line comes before the spotlight deck when one renders" do
    deck = Presentation.create!(author: users(:admin), title: "Spotlit Deck", content: "A story.", price: 9.99, featured: true)
    deck.update_column(:published, true)

    get root_path
    assert_response :success
    body = response.body
    spotlight = body.index("In the spotlight")
    assert spotlight, "expected the spotlight block to render"
    assert_operator body.index("whole ritual"), :<, spotlight
  end

  test "no scroll-driven or rise animation targets the closing beat or the story beats" do
    get root_path
    assert_response :success

    css = Nokogiri::HTML(response.body).css("style").map(&:text).join("\n")
    animated = css.scan(/([^{}]+)\{([^{}]*)\}/).filter_map do |selectors, block|
      selectors.strip if block.match?(/animation-timeline|hx-rise/)
    end
    offenders = animated.select { |list| list.split(",").any? { |sel| sel.match?(/\.beat|\.story/) } }
    assert_empty offenders, "the closing line must not rely on a scroll animation: #{offenders.inspect}"
  end

  # The beats' words reveal through the time-based appear controller, which
  # always runs to the end. The closing beat stays out of it entirely: it is
  # the page's last word and is never faded, not even for half a second.
  test "the closing beat never reveals; the beats before it do" do
    get root_path
    assert_select "#{CLOSE}[data-appear-target], #{CLOSE} [data-appear-target]", 0
    assert_select ".story .b2 [data-appear-target=item]", minimum: 1
    assert_select ".story .beat[data-appear-target]", 0, "a tall beat would reveal before its words are on screen"
  end
end
