require "test_helper"

# One reveal system for the site (the `appear` Stimulus controller). Cards,
# list rows, panels and section headings marked data-appear-target="item"
# ease up and fade in the first time they scroll into view; a glass
# (data-appear-target="glass") pours when it is seen.
#
# What these tests pin is the safety contract, because the motion itself runs
# in the browser:
# - the hidden start state is a class only the controller adds, so the
#   server's HTML (no JS, JS failure, a Turbo snapshot) is always fully visible;
# - the start state lives only under prefers-reduced-motion: no-preference;
# - the controller is in the public layout's <main>, never the header, the
#   footer, a form or the admin area;
# - nothing is scroll-scrubbed (animation-timeline), which is what once left
#   cards part-faded wherever the scroll stopped.
class AppearMotionTest < ActionDispatch::IntegrationTest
  CSS = Rails.root.join("app/assets/tailwind/application.css")
  CONTROLLER = Rails.root.join("app/javascript/controllers/appear_controller.js")

  def css_source
    File.read(CSS)
  end

  def deck_with_reviews
    deck = Presentation.create!(author: users(:admin), title: "Appear Deck", content: "A story.", price: 9.99)
    deck.update_column(:published, true)
    deck
  end

  def pages
    {
      "home" => root_path,
      "library" => presentations_path,
      "deck" => presentation_path(deck_with_reviews),
      "societies" => societies_path,
      "reviews" => reviews_path,
      "review" => review_path(reviews(:john_eagle_rare)),
      "membership" => membership_path
    }
  end

  test "every listed page puts its content under the appear controller" do
    pages.each do |name, path|
      get path
      assert_response :success, name
      assert_select "main[data-controller~=appear]", 1, "#{name}: main carries the appear controller"
      assert_select "main [data-appear-target~=item]", { minimum: 1 }, "#{name}: something reveals"
    end
  end

  test "the server never sends the hidden start state" do
    pages.each do |name, path|
      get path
      refute_match(/appear-pending|glass-wait|glass-pouring|\bis-in\b/, response.body, "#{name}: start state must be added by JS only")
    end
  end

  test "the header, the footer and forms are never reveal targets" do
    pages.each do |name, path|
      get path
      assert_select "nav [data-appear-target], footer [data-appear-target]", 0, "#{name}: chrome stays put"
      assert_select "form[data-appear-target], form [data-appear-target~=item], [data-appear-target~=item] form textarea, [data-appear-target~=item] form input[type=text], [data-appear-target~=item] form input[type=search]",
                    0, "#{name}: nothing anyone types in fades"
    end
  end

  test "reveal items never nest, so a container has one entrance" do
    pages.each do |name, path|
      get path
      assert_select "[data-appear-target~=item] [data-appear-target~=item]", 0, name
    end
  end

  test "the admin area has no appear controller" do
    sign_in users(:admin)
    get admin_presentations_path
    assert_response :success
    assert_select "[data-controller~=appear]", 0
  end

  test "the hidden start state is gated on reduced motion and on a JS-added class" do
    css = css_source
    hiding = css.scan(/([^{}]+)\{([^{}]*)\}/).select { |_, block| block.match?(/opacity:\s*0\s*;/) }.map { |sel, _| sel.strip }
    reveal = hiding.select { |sel| sel.include?("appear") }
    assert reveal.any?, "expected the appear start state"
    reveal.each { |sel| assert_match(/\A\.appear-pending\z/, sel.split("\n").last.strip) }

    no_pref = css[/@media \(prefers-reduced-motion: no-preference\)\s*\{(.*?)\n\}/m, 1]
    assert no_pref, "expected a no-preference block"
    assert_includes no_pref, ".appear-pending {"
    assert_includes no_pref, "svg[data-glass].glass-wait"
    outside = css.sub(no_pref, "")
    refute_match(/\.appear-pending\s*\{[^}]*opacity:\s*0/, outside, "the hidden state must not apply under reduced motion")
  end

  test "the glass pours only once the controller says it is in view" do
    css = css_source
    refute_match(/svg\[data-glass\] g > path\s*\{[^}]*animation/, css, "no glass pours on load regardless of position")
    assert_match(/svg\[data-glass\]\.glass-pouring g > path\s*\{[^}]*animation:\s*glass-pour 900ms/, css)

    html = Nokogiri::HTML5.fragment(ApplicationController.render(partial: "shared/glass", locals: { level: 0.5 }))
    assert_equal "glass", html.at_css("svg")["data-appear-target"]
  end

  test "nothing on the site is scroll-scrubbed" do
    refute_match(/animation-timeline/, css_source)
    get root_path
    refute_match(/animation-timeline|hx-rise/, response.body)
  end

  test "the controller observes, fires once, respects reduced motion and Turbo's cache" do
    js = File.read(CONTROLLER)
    assert_includes js, "IntersectionObserver"
    assert_includes js, "unobserve"
    assert_includes js, "prefers-reduced-motion: reduce"
    assert_includes js, "turbo:before-cache"
    assert_match(/static targets = \[\s*"item",\s*"glass"\s*\]/, js)
  end

  test "the Turbo progress bar is a thin orange line" do
    block = css_source[/\.turbo-progress-bar\s*\{([^}]*)\}/, 1]
    assert block, "expected a progress bar rule"
    assert_match(/background(-color)?:\s*var\(--color-mark-deep\)/, block)
    assert_match(/height:\s*2px/, block)
  end

  test "buttons, tappable cards and chips press in fast with a shade, focus rings kept" do
    css = css_source
    press = css.scan(/([^{}]+)\{([^{}]*)\}/).find { |sel, block| sel.include?(":active") && block.match?(/scale:\s*\.98/) }
    assert press, "expected a press rule"
    sel, block = press
    %w[.btn .btn-primary .btn-secondary .card-hover .chip].each { |c| assert_includes sel, c }
    assert_match(/transition-duration:\s*80ms/, block, "the press goes in fast enough to see on a tap")
    assert_match(/\.btn-primary:active[^{]*\{\s*background-color:\s*var\(--color-whiskey-700\)/, css)
    assert_match(/\.chip:active[^{]*\{\s*background-color:\s*var\(--color-whiskey-100\)/m, css)
    assert_includes css, "focus-visible:ring-2", "focus-visible styles stay"
  end

  test "under reduced motion nothing travels on hover, the press stays" do
    reduce = css_source.scan(/@media \(prefers-reduced-motion: reduce\)\s*\{(.*?)\n\}/m).flatten.join
    assert_match(/\.card-hover:hover\s*\{\s*translate:\s*none/, reduce)
    assert_match(/\.arrow[^{]*\{\s*translate:\s*none/, reduce)
    refute_match(/scale:\s*none[^}]*\}/, reduce.sub(/a:hover \.deck-cover img\s*\{\s*scale:\s*none;\s*\}/, ""), "the press scale is not removed")
  end

  test "nothing taller than a screen is a reveal item: headings reveal, reading text never fades" do
    js = File.read(CONTROLLER)
    assert_match(/TALL = 1\.2/, js)
    assert_match(/rect\.height > height \* TALL/, js)

    deck = deck_with_reviews
    deck.update!(content: "A story. " * 200)
    get presentation_path(deck)
    assert_select "section[data-appear-target]", 0, "a deck section is one screen or more on a phone; mark its heading"
    assert_select "[data-appear-target~=item] .prose-deck, .prose-deck[data-appear-target]", 0
    assert_select "#deck-story [data-appear-target=item] h2", 1

    get root_path
    assert_select ".story .beat-body[data-appear-target=item]", 3, "each beat's words reveal as one"
    assert_select ".story .beat-body [data-appear-target]", 0
    assert_select ".panel[data-appear-target]", 0
    get membership_path
    assert_select "#founding-offer[data-appear-target]", 0
  end

  test "a printed page shows every card and every glass at its level" do
    print = css_source[/@media print\s*\{(.*?)\n\}/m, 1]
    assert print, "expected a print block"
    assert_match(/\.appear-pending\s*\{[^}]*opacity:\s*1 !important/, print)
    assert_match(/svg\[data-glass\]\.glass-wait g > path[^{]*\{[^}]*transform:\s*none !important/, print)
  end

  test "nothing on screen can stay hidden: settle sweep, time limit and focus rescue" do
    js = File.read(CONTROLLER)
    assert_includes js, 'addEventListener("focusin"', "focusing inside a waiting item shows it"
    assert_match(/LIMIT = \d+/, js, "a one-off time limit")
    assert_match(/rect\.top < height/, js, "the settle sweep reveals anything above the bottom of the screen")
    refute_match(/rootMargin:\s*"[^"]*-\d/, js, "no inset band where an on-screen item can wait")
    assert_includes js, "itemTargetDisconnected"
  end

  test "every arrow after a link's words is its own nudging span" do
    offenders = Dir[Rails.root.join("app/views/**/*.erb")].reject { |f| f.include?("/admin/") || f.include?("index_next") }.flat_map do |file|
      # ERB comments out, keeping line numbers.
      source = File.read(file).gsub(/<%#.*?%>/m) { |c| "\n" * c.count("\n") }
      source.lines.each_with_index.filter_map do |line, i|
        "#{file.sub(Rails.root.to_s + '/', '')}:#{i + 1}" if line.match?(/→/) && !line.match?(/class="[^"]*\barrow\b|with_arrow|content: "→"/)
      end
    end
    assert_empty offenders, "arrows that will not nudge: #{offenders.join(', ')}"
  end
end
