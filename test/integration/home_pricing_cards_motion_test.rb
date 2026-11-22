require "test_helper"

# The homepage pricing cards (#pricing .plan) are links to /membership. They
# must be fully opaque at any scroll position and never depend on a
# scroll-driven animation to become visible. Under the hx-rise rule a card
# whose scroll stopped mid-entry stayed part-faded (reported as greyed out in
# Safari), and the animation's fill overrode the .plan:hover lift. Other
# surfaces may still rise in; the plan cards may not.
class HomePricingCardsMotionTest < ActionDispatch::IntegrationTest
  # Every selector list in the page's inline <style> whose block declares a
  # scroll-driven timeline or the hx-rise animation.
  def animated_selectors(body)
    css = Nokogiri::HTML(body).css("style").map(&:text).join("\n")
    css.scan(/([^{}]+)\{([^{}]*)\}/).filter_map do |selectors, block|
      selectors.strip if block.match?(/animation-timeline|hx-rise/)
    end
  end

  test "homepage pricing cards render as links to the membership page" do
    get root_path
    assert_response :success
    assert_select "#pricing .plans a.plan[href='#{membership_path}']", count: 3
  end

  test "no scroll-driven or rise animation targets the pricing cards" do
    get root_path
    assert_response :success

    selectors = animated_selectors(response.body)
    assert selectors.any?, "expected the homepage to keep its rise-in motion for other surfaces"
    offenders = selectors.select { |list| list.split(",").any? { |sel| sel.match?(/\.plan\b/) } }
    assert_empty offenders, "pricing cards must not depend on a scroll animation to be opaque: #{offenders.inspect}"
  end

  test "the pricing cards are not given a starting opacity below one" do
    get root_path
    assert_response :success

    css = Nokogiri::HTML(response.body).css("style").map(&:text).join("\n")
    plan_blocks = css.scan(/([^{}]+)\{([^{}]*)\}/).select { |sel, _| sel.split(",").any? { |s| s.match?(/\.plan\b/) } }
    plan_blocks.each do |sel, block|
      refute_match(/opacity:\s*0?\.\d|opacity:\s*0\s*[;}]/, block, "#{sel.strip} lowers the card's opacity")
    end
  end
end
