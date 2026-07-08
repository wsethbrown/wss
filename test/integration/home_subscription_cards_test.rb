require "test_helper"

class HomeSubscriptionCardsTest < ActionDispatch::IntegrationTest
  test "home page displays all three subscription cards" do
    get root_path
    assert_response :success
    
    # Check that all three subscription plans are displayed
    assert_select "h3", text: "Monthly"
    assert_select "h3", text: "Quarterly"  
    assert_select "h3", text: "Yearly"
  end

  test "home page displays correct pricing for each plan" do
    get root_path
    assert_response :success
    
    # Check pricing display (fallback prices)
    assert_select "span", text: "$15.99"  # Monthly
    assert_select "span", text: "$12.99"  # Quarterly
    assert_select "span", text: "$10.99"  # Yearly
  end

  test "home page shows quarterly as most popular" do
    get root_path
    assert_response :success
    
    # Check for "Most Popular" or "Best Value" badge
    assert_select "span", text: /Best Value|Most Popular/
  end

  test "home page shows one shared benefits list, not per-plan feature ladders" do
    get root_path
    assert_response :success

    # All tiers are identical, so benefits appear ONCE in a shared panel —
    # never repeated per card, and never as invented tier-specific perks.
    assert_select "h3", text: "Every membership includes"
    assert_select "#plan-cards ul", count: 0
    assert_select "li", text: /One deck credit every month/, count: 1
    assert_select "li", text: /The complete tasting record/, count: 1
  end

  test "home page shows savings indicators for quarterly and yearly" do
    get root_path
    assert_response :success
    
    # Check for savings badges
    assert_select "div", text: /Save 19%/
    assert_select "div", text: /Save 31%/
  end

  test "subscription cards have brand card styling" do
    get root_path
    assert_response :success

    # Plan cards are white label-style cards; the popular plan is set off with a
    # whiskey border (see app/views/home/index.html.erb pricing section).
    assert_select "div.rounded-3xl", minimum: 3
    assert_select "div.shadow-xl", minimum: 3
    assert_select "#plan-cards div.border-whiskey-400", count: 1
  end

  test "subscription cards have Get Started buttons" do
    get root_path
    assert_response :success
    
    # Check for CTA buttons (scoped to the pricing grid; "Get Started" also
    # appears in hero/CTA copy elsewhere on the marketing page).
    assert_select "#plan-cards a", text: /Get Started/, count: 3

    # Check that buttons link to auth page
    assert_select "#plan-cards a[href='#{auth_path}']", count: 3
  end

  test "subscription cards display correct intervals" do
    get root_path
    assert_response :success
    
    # Check interval display (scoped to the pricing grid). All plans normalise
    # to a per-month figure, shown as "/mo".
    assert_select "#plan-cards span", text: "/mo", count: 3
  end

  test "subscription cards are responsive with 3-column grid" do
    get root_path
    assert_response :success
    
    # Check for responsive grid classes
    assert_select "div.grid.grid-cols-1.md\\:grid-cols-3", count: 1
  end

  test "subscription cards show proper plan descriptions" do
    get root_path
    assert_response :success
    
    # Descriptions speak to commitment/cadence — the only real difference
    # between tiers — not fabricated tiers of features.
    assert_select "p", text: "Pay as you go, cancel anytime"
    assert_select "p", text: "Billed every three months"
    assert_select "p", text: "Billed once a year"
  end
end