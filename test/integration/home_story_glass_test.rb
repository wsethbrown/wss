require "test_helper"

# TRIAL (owner to decide from a recording): a glass that fills with the
# scroll through the homepage story, from empty at the first step to full at
# the closing beat. Off by default: only /?glass=1, 2 or 3 renders it, each a
# different placement for the owner to compare. All of it lives in
# home/_story_glass.html.erb and story_glass_controller.js, so a "no" is two
# deleted files, two lines in home/index and this test.
class HomeStoryGlassTest < ActionDispatch::IntegrationTest
  test "the default homepage renders no trial glass: no markup, no styles" do
    get root_path
    assert_response :success
    assert_select "[data-controller~=story-glass], .story-glass", 0
    refute_match(/\.story-glass|story-glass--/, css_select("style").map(&:text).join, "no trial styles")
    # The one trace is the module itself: importmap's pin_all_from and eager
    # loading put every controller in the import map and preload it on every
    # page. Inert without its element. Deleting the controller file removes it.
    mentions = response.body.scan(/[^\s"']*story[-_]glass[^\s"']*/).uniq
    assert mentions.all? { |m| m.include?("controllers/story_glass_controller") }, "only the module pin: #{mentions}"
  end

  test "?glass=1 adds one hidden, aria-hidden glass to the story, drawn by shared/_glass" do
    get root_path(glass: 1)
    assert_response :success
    assert_select ".story [data-controller=story-glass]", 1 do |els|
      el = els.first
      assert el.key?("hidden"), "absent until its controller shows it: no JS, no glass"
      assert_equal "true", el["aria-hidden"]
    end
    assert_select "[data-controller=story-glass] svg[data-glass][aria-hidden=true]", 1
    # It is a gauge, not a reveal: the appear controller must not pour it.
    assert_select "[data-controller=story-glass] [data-appear-target]", 0
    # No words of its own.
    assert_equal "", css_select("[data-controller=story-glass]").text.strip
  end

  test "each of 1, 2 and 3 selects its own placement" do
    { "1" => "story-glass--1", "2" => "story-glass--2", "3" => "story-glass--3" }.each do |param, klass|
      get root_path(glass: param)
      assert_select ".story-glass", 1
      assert_select ".story-glass.#{klass}", 1, "?glass=#{param}"
    end
  end

  test "anything else means no glass, and the param is never written into the page" do
    [ "0", "4", "12", "1x", " 1", "true", "<b>1</b>", "%22onload%3Dalert(1)" ].each do |value|
      get root_path, params: { glass: value }
      assert_response :success
      assert_select "[data-controller~=story-glass]", 0, "?glass=#{value.inspect} must not select a variant"
      refute_includes response.body, "story-glass", value
    end
    get "/?glass[]=1"
    assert_response :success
    assert_select "[data-controller~=story-glass]", 0, "an array param selects nothing"

    get root_path(glass: "2")
    refute_match(/glass=2/, css_select(".story-glass").to_s, "the request's value is not echoed")
  end

  test "the trial glass is out of the flow, so showing it shifts nothing" do
    get root_path(glass: 1)
    css = css_select("style").map(&:text).join("\n")
    block = css[/\.hx \.story-glass\s*\{([^}]*)\}/, 1]
    assert block, "expected the trial's base rule"
    assert_match(/position:\s*fixed/, block, "on phones it is fixed beside the text")
    assert_match(/position:\s*sticky/, css, "on desktop it rides with the pinned faces")
    assert_match(/height:\s*0/, css[/@media \(min-width: 900px\)\s*\{[^@]*\.story-glass[^@]*/m].to_s, "on desktop it takes no height")
  end

  test "the shared glass can be drawn without joining the reveal" do
    html = Nokogiri::HTML5.fragment(ApplicationController.render(partial: "shared/glass", locals: { level: 1, appear: false }))
    assert_nil html.at_css("svg")["data-appear-target"]
    default = Nokogiri::HTML5.fragment(ApplicationController.render(partial: "shared/glass", locals: { level: 1 }))
    assert_equal "glass", default.at_css("svg")["data-appear-target"]
  end
end
