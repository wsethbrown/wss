require "test_helper"

# The plan cards moved off the homepage in the 2026 redesign (it shows live
# prices as a short list and links here); /membership is their home now.
class HomeSubscriptionCardsTest < ActionDispatch::IntegrationTest
  test "home page displays all three subscription cards" do
    get membership_path
    assert_response :success

    # Check that all three subscription plans are displayed
    assert_select "h3", text: "Monthly"
    assert_select "h3", text: "Quarterly"
    assert_select "h3", text: "Yearly"
  end

  test "home page displays correct pricing for each plan" do
    get membership_path
    assert_response :success

    # Check pricing display (fallback prices)
    assert_select "span", text: "$15.99"  # Monthly
    assert_select "span", text: "$12.99"  # Quarterly
    assert_select "span", text: "$10.99"  # Yearly
  end

  test "exactly one plan is marked best value, and it is the yearly plan" do
    get membership_path
    assert_response :success

    # The marker is content, not a CSS class: one chip, inside the yearly card.
    assert_select "#plan-cards span", text: /Best value/, count: 1
    yearly = css_select("#plan-cards > div").find { |card| card.at_css("h3")&.text&.strip == "Yearly" }
    assert yearly, "expected a yearly plan card"
    assert_match(/Best value/, yearly.text)
  end

  test "home page shows the free-vs-membership split, not per-plan feature ladders" do
    get membership_path
    assert_response :success

    # Cards carry no feature lists; benefits live in a free-vs-paid comparison.
    assert_select "#plan-cards ul", count: 0
    assert_select "p", text: "Free with any account"
    assert_select "p", text: "Membership adds"
    assert_select "li", text: /Join any public society/, count: 1
    assert_select "li", text: /Join any public society/
    assert_select "li", text: /One deck credit every month/
  end

  test "home page shows savings indicators for quarterly and yearly" do
    get membership_path
    assert_response :success

    # Check for savings badges
    assert_select "#plan-cards", text: /Save 19%/
    assert_select "#plan-cards", text: /Save 31%/
  end

  test "there are three plan cards, one per plan, in a single plan grid" do
    get membership_path
    assert_response :success

    assert_select "#plan-cards", count: 1
    assert_select "#plan-cards > div", count: 3
    assert_select "#plan-cards > div h3", count: 3
  end

  test "subscription cards have Get started buttons" do
    get membership_path
    assert_response :success

    # Check for CTA buttons (scoped to the pricing grid; "Get started" also
    # appears in hero/CTA copy elsewhere on the marketing page).
    assert_select "#plan-cards a", text: /Get started/, count: 3

    # Check that buttons link to auth page
    assert_select "#plan-cards a[href='#{auth_path}']", count: 3
  end

  test "subscription cards display correct intervals" do
    get membership_path
    assert_response :success

    # Check interval display (scoped to the pricing grid). All plans normalise
    # to a per-month figure, shown as "/mo".
    assert_select "#plan-cards span", text: "/mo", count: 3
  end

  test "signed-in non-members get a checkout form per plan, not a sign-in link" do
    sign_in users(:john)
    get membership_path
    assert_response :success

    assert_select "#plan-cards form[action='#{subscriptions_checkout_path}']", count: 3
    assert_select "#plan-cards input[name='price_id']", count: 3
    assert_select "#plan-cards a[href='#{auth_path}']", count: 0
  end

  test "subscription cards show proper plan descriptions" do
    get membership_path
    assert_response :success

    # Descriptions speak to commitment/cadence — the only real difference
    # between tiers — not fabricated tiers of features.
    assert_select "p", text: "Pay as you go, cancel anytime"
    assert_select "p", text: "Billed every three months"
    assert_select "p", text: "Billed once a year"
  end
end
