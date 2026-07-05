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

  test "home page displays feature lists for each plan" do
    get root_path
    assert_response :success
    
    # Check that feature lists are present (scoped to the pricing grid; the
    # marketing page uses space-y-3 in several unrelated sections).
    assert_select "#plan-cards ul.space-y-3", count: 3
    assert_select "#plan-cards li.flex.items-center", minimum: 9  # At least 3 features per plan
    
    # Check specific features
    assert_select "li", text: /1 credit per month/
    assert_select "li", text: /Everything in Monthly/
    assert_select "li", text: /Everything in Quarterly/
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
    
    # Check plan descriptions
    assert_select "p", text: "Perfect for trying it out"
    assert_select "p", text: "Great value"
    assert_select "p", text: "Save 31%"
  end
end