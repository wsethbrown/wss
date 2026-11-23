require "test_helper"

# The homepage pricing cards (#pricing .plan) are links to /membership. They
# must be fully opaque at any scroll position and never depend on a
# scroll-driven animation to become visible. Under the old hx-rise rule
# (animation-timeline: view()) a card whose scroll stopped mid-entry stayed
# part-faded (reported as greyed out in Safari), and the animation's fill
# overrode the .plan:hover lift.
#
# They now reveal through the site's appear controller: a time-based fade
# that runs once, to the end, and then removes its classes. The page's own
# CSS never lowers a card's opacity; the only start state is a class the
# controller adds in the browser (see AppearMotionTest).
class HomePricingCardsMotionTest < ActionDispatch::IntegrationTest
  def page_rules(body)
    css = page_css(body)
    css.scan(/([^{}]+)\{([^{}]*)\}/)
  end

  test "homepage pricing cards render as links to the membership page" do
    get root_path
    assert_response :success
    assert_select "#pricing .plans a.plan[href='#{membership_path}']", count: 3
  end

  test "nothing on the homepage is scroll-driven, the pricing cards least of all" do
    get root_path
    assert_response :success

    animated = page_rules(response.body).filter_map { |sel, block| sel.strip if block.match?(/animation-timeline|hx-rise/) }
    assert_empty animated, "scroll-scrubbed motion can stop half-way: #{animated.inspect}"
  end

  test "the pricing cards reveal through the time-based appear controller" do
    get root_path
    assert_select "main[data-controller~=appear] #pricing a.plan[data-appear-target=item]", count: 3
    refute_match(/appear-pending/, response.body, "the server never sends a card hidden")
  end

  test "the pricing cards are not given a starting opacity below one" do
    get root_path
    assert_response :success

    plan_blocks = page_rules(response.body).select { |sel, _| sel.split(",").any? { |s| s.match?(/\.plan\b/) } }
    plan_blocks.each do |sel, block|
      refute_match(/opacity:\s*0?\.\d|opacity:\s*0\s*[;}]/, block, "#{sel.strip} lowers the card's opacity")
      refute_match(/animation/, block, "#{sel.strip} animates the card")
    end
  end
end
