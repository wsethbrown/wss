require "test_helper"

# The story glass (owner's choice of placement, November 2026): a glass that
# fills with the scroll through the homepage story, empty at the first step
# and full at the closing beat. On the homepage by default, nowhere else.
# Desktop: a 96px gauge in the gutter between the step words and the face,
# held mid-screen. Phones: 40px in the bottom-right corner.
class HomeStoryGlassTest < ActionDispatch::IntegrationTest
  test "the homepage shows one hidden, aria-hidden glass in the story, drawn by shared/_glass" do
    get root_path
    assert_response :success
    assert_select ".story > .story-glass[data-controller=story-glass]", 1 do |els|
      el = els.first
      assert el.key?("hidden"), "absent until its controller shows it: no JS, no glass"
      assert_equal "true", el["aria-hidden"]
    end
    assert_select ".story-glass svg[data-glass][aria-hidden=true]", 1
    assert_equal "96", css_select(".story-glass svg").first["height"], "drawn at the desktop gauge's size"
    # A gauge, not a reveal: the appear controller must not pour it.
    assert_select ".story-glass [data-appear-target]", 0
    assert_equal "", css_select(".story-glass").text.strip, "no words of its own"
  end

  test "it needs no parameter, and no parameter changes it" do
    [ {}, { glass: "1" }, { glass: "3" }, { glass: "0" } ].each do |params|
      get root_path, params: params
      assert_select ".story-glass", 1, params.inspect
      refute_match(/story-glass--|variant|trial/i, css_select(".story-glass").to_s, params.inspect)
    end
    refute_match(/params\[:glass\]/, File.read(Rails.root.join("app/views/home/index.html.erb")))
  end

  test "it is on no other page" do
    [ presentations_path, societies_path, reviews_path, membership_path, auth_path ].each do |path|
      get path
      assert_response :success
      assert_select "[data-controller~=story-glass], .story-glass", 0, path
      refute_match(/\.story-glass/, page_css, "#{path}: no story-glass styles")
    end
  end

  test "it is out of the flow, so showing it shifts nothing, and taps pass through" do
    get root_path
    css = page_css
    base = css[/\.hx \.story-glass\s*\{([^}]*)\}/, 1]
    assert base, "expected the glass's base rule"
    assert_match(/position:\s*fixed/, base, "on phones it is fixed in the corner")
    assert_match(/right:\s*-5px/, base)
    assert_match(/bottom:\s*calc\(16px/, base)
    assert_match(/pointer-events:\s*none/, base)
    assert_match(/\.hx \.story-glass svg\s*\{[^}]*width:\s*30px;\s*height:\s*40px/, css, "40px on phones")
    desktop = css[/@media \(min-width: 900px\)\s*\{[^@]*\.story-glass[^@]*/m].to_s
    assert_match(/position:\s*sticky/, desktop)
    assert_match(/height:\s*0/, desktop, "on desktop it takes no height")
    # Held at the middle of the screen: the sticky box sits as far below
    # 50svh - 48px as the drawing hangs above it (placed by its foot, #52).
    assert_match(/top:\s*calc\(50svh - 48px - var\(--section-pad\) \+ var\(--glass-foot\)\)/, desktop, "held at the middle of the screen")
    assert_match(/\.story-glass svg\s*\{[^}]*top:\s*calc\(var\(--section-pad\) - var\(--glass-foot\)\)/, desktop, "the drawing hung by the same amount")
    assert_match(/left:\s*-72px;\s*width:\s*72px;\s*height:\s*96px/, desktop, "a 96px gauge filling the 72px gutter")
    assert_match(/@media print\s*\{\s*\.hx \.story-glass\s*\{\s*display:\s*none/, css)
    # The step words keep clear of it.
    assert_match(/\.hx \.beat\s*\{[^}]*padding:\s*40px 28px 40px 0/, css)
  end

  test "the shared glass can be drawn without joining the reveal" do
    html = Nokogiri::HTML5.fragment(ApplicationController.render(partial: "shared/glass", locals: { level: 1, appear: false }))
    assert_nil html.at_css("svg")["data-appear-target"]
    default = Nokogiri::HTML5.fragment(ApplicationController.render(partial: "shared/glass", locals: { level: 1 }))
    assert_equal "glass", default.at_css("svg")["data-appear-target"]
  end
end
