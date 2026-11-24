require "test_helper"

# The homepage players. Only the hero has ticks: with real slides it has one
# tick per slide, each lit in step with its slide in the reel (same duration,
# same delay), and hovering or focusing the player pauses both; without slides
# it lights the first of four. The three step faces below it show only their
# bar's title: their old ticks and "n / 4" counter read as a sideways image
# carousel, when the faces actually change with the vertical scroll. (Before
# that the ticks were all driven by a leftover hx-tick animation, so all four
# lit together on every face and then went dark.)
class HomePlayerTicksTest < ActionDispatch::IntegrationTest
  # [selector list, declaration block] for every rule in the page's <style>.
  def rules
    page_css.scan(/([^{}]+)\{([^{}]*)\}/).map { |sel, block| [ sel.strip, block ] }
  end

  def lit_index(face)
    ticks = css_select("#{face} .ticks i").to_a
    assert_equal 4, ticks.size, "#{face} should draw four ticks"
    lit = ticks.each_index.select { |i| ticks[i]["class"].to_s.split.include?("on") }
    assert_equal 1, lit.size, "#{face} should light exactly one tick"
    lit.first
  end

  test "the step faces keep their bar's title but draw no ticks and no counter" do
    get root_path
    assert_response :success

    { ".f2" => "The library", ".f3" => "The next tasting night", ".f4" => "The tasting record" }.each do |face, title|
      assert_select "#{face} .bar", 1
      assert_select "#{face} .bar b", text: title
      assert_select "#{face} .ticks, #{face} .ticks i", 0, "#{face} must not suggest a sideways carousel"
      assert_select "#{face} .bar span", 0, "#{face} has no n / 4 counter"
      refute_match %r{\d / 4}, css_select("#{face} .bar").text
    end
  end

  test "the hero without slides lights the first of four" do
    get root_path
    assert_select ".f1 .bar span", text: "1 / 4"
    assert_equal 0, lit_index(".f1")
  end

  test "the hero with slides has one tick per slide, each in step with its slide" do
    deck = Presentation.create!(author: users(:admin), title: "Reel Deck", content: "Smoke.", price: 10, featured: true, preview_slide_count: 3)
    5.times do |n|
      deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "slide#{n}.png", content_type: "image/png")
    end
    deck.update_column(:published, true)

    get root_path
    assert_response :success

    slides = css_select(".f1 .reel img")
    ticks = css_select(".f1 .ticks i")
    assert_equal 3, slides.size
    assert_equal slides.size, ticks.size, "one tick per slide in the reel"
    slides.zip(ticks).each do |img, tick|
      delay = img["style"][/animation-delay:\s*[\d.]+s/]
      assert delay, "each slide carries its delay"
      assert_includes tick["style"].to_s, delay, "a tick starts with its slide"
    end
    assert css_select(".f1 .ticks.ticks--reel").any?
    # The reel and its ticks name their length; the stylesheet animates each
    # length with its own keyframes (offsets cannot come from a variable, and
    # the page carries no inline <style>: issue #46).
    assert css_select(".f1 .reel.reel--3").any?, "the reel names its length"
    assert css_select(".f1 .ticks.ticks--reel.ticks--reel-3").any?, "the ticks name the reel's length"

    reel = rules.find { |sel, block| sel.include?(".hx .reel--3 img") && block.include?("hx-reel-3 ") }
    tick = rules.find { |sel, block| sel.include?(".hx .ticks--reel-3 i") && block.include?("hx-tick-3 ") }
    assert reel && tick, "reel slides and reel ticks are both animated"
    assert_equal "12s", reel[1][/hx-reel-3 ([\d.]+s)/, 1], "four seconds a slide"
    assert_equal reel[1][/hx-reel-3 ([\d.]+s)/, 1], tick[1][/hx-tick-3 ([\d.]+s)/, 1], "ticks cycle with the reel"
  end

  # Every length the hero can show has its keyframes, exactly as the page
  # used to write them inline: each slide holds for its share of the cycle,
  # fading in over the first 3% and out over the 3% after its share.
  test "the stylesheet animates every reel length the hero can show" do
    get root_path
    css = page_css
    (2..HomeHelper::HERO_REEL_MAX).each do |n|
      step = (100.0 / n).round(2)
      assert_includes css, "@keyframes hx-reel-#{n} { 0% { opacity: 0; } 3% { opacity: 1; } #{step}% { opacity: 1; } #{step + 3}% { opacity: 0; } 100% { opacity: 0; } }", "reel of #{n}"
      assert_includes css, "@keyframes hx-tick-#{n} { 0% { opacity: .22; } 3% { opacity: 1; } #{step}% { opacity: 1; } #{step + 3}% { opacity: .22; } 100% { opacity: .22; } }", "ticks of #{n}"
      assert_match(/\.hx \.ticks--reel-#{n} i \{ animation: hx-tick-#{n} #{n * 4}s infinite; \}/, css, "ticks of #{n}")
      assert_match(/\.hx \.reel--#{n} img \{ animation: hx-reel-#{n} #{n * 4}s infinite; \}/, css, "reel of #{n}")
    end
    refute_match(/hx-(reel|tick)-#{HomeHelper::HERO_REEL_MAX + 1}\b/, css, "no length the hero cannot show")
  end

  test "a deck that previews more slides than the reel holds shows the first of them" do
    max = HomeHelper::HERO_REEL_MAX
    deck = Presentation.create!(author: users(:admin), title: "Long Preview", content: "Smoke.", price: 10, featured: true, preview_slide_count: max + 1)
    (max + 2).times { |n| deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "l#{n}.png", content_type: "image/png") }
    deck.update_column(:published, true)
    get root_path
    assert_equal max, css_select(".f1 .reel img").size
    assert_equal max, css_select(".f1 .ticks--reel i").size
    assert css_select(".f1 .reel.reel--#{max}").any?
  end

  test "only the reel's ticks animate; a face's lit tick is never overridden" do
    deck = Presentation.create!(author: users(:admin), title: "Tick Deck", content: "Smoke.", price: 10, featured: true, preview_slide_count: 3)
    5.times { |n| deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "t#{n}.png", content_type: "image/png") }
    deck.update_column(:published, true)
    get root_path
    animated = rules.select { |_, block| block.include?("hx-tick") && block.include?("animation") }
    assert animated.any?, "a reel of three slides animates its ticks"
    animated.each do |sel, _block|
      sel.split(",").each do |s|
        assert_includes s, ".ticks--reel", "#{s.strip} would animate every face's ticks"
      end
    end
  end

  test "hovering or focusing the hero player pauses the reel, on an element that exists" do
    get root_path
    paused = rules.select { |_, block| block.include?("animation-play-state: paused") }.map(&:first)
    assert paused.any?, "expected a pause rule"
    paused.each { |sel| refute_includes sel, ".stage", "the .stage element is gone from the markup" }
    assert paused.any? { |sel| sel.match?(/\.player:hover/) }, "hover pauses"
    assert paused.any? { |sel| sel.match?(/\.player:focus-visible/) }, "keyboard focus pauses"
    assert_includes page_css, "@media (hover: hover) and (pointer: fine) { .hx .player:hover", "a tap must not leave it paused"
    assert css_select(".f1 .player").any?
    refute_includes page_css, ".stage", "no rule targets the removed .stage"
  end

  test "a one-slide reel does not cycle and never writes a keyframe past 100%" do
    deck = Presentation.create!(author: users(:admin), title: "One Slide", content: "Smoke.", price: 10, featured: true)
    deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "slide0.png", content_type: "image/png")
    deck.update_column(:published, true)

    get root_path
    assert_equal 1, css_select(".f1 .reel img").size
    assert_equal 1, css_select(".f1 .ticks--reel i").size
    percents = page_css.scan(/([\d.]+)%\s*\{/).flatten.map(&:to_f)
    assert percents.all? { |pc| pc <= 100 }, "keyframe offsets over 100%: #{percents.select { |pc| pc > 100 }}"
    assert css_select(".f1 .reel.reel--1").any?
    assert css_select(".f1 .ticks--reel.ticks--reel-1").any?
    assert_includes page_css, ".hx .reel--1 img, .hx .ticks--reel-1 i { opacity: 1 !important; animation: none !important; }", "the one slide shows and its tick stays lit"
    refute_match(/@keyframes hx-(reel|tick)-1\b/, page_css)
  end

  test "homepage hover motion is gated on a pointer, so it never sticks after a tap" do
    get root_path
    css = page_css
    # The reduced-motion block's ":hover { transform: none }" lines switch
    # motion off, so they need no gate.
    ungated = css.lines.select { |l| l.include?(":hover") && !l.include?("@media (hover: hover) and (pointer: fine)") && !l.match?(/\{\s*(transform|translate):\s*none;\s*\}/) }
    assert_empty ungated, "ungated hover rules: #{ungated.map(&:strip)}"
  end
end
