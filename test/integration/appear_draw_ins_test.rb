require "test_helper"

# Motion batch 2: secondary motion run by the same appear controller as the
# reveal (docs/redesign/DESIGN_SYSTEM.md, "Motion").
#
#   draw     the palate wheel's wedges grow from the hub, the flavor wave's
#            stems grow to their value and its line draws left to right,
#            labels last
#   photo    a duotone photograph settles from a slight scale inside its frame
#   image    images that are still loading fade in when they arrive
#
# The motion runs in the browser, so what these pin is the contract: the
# server's markup is always the final picture (every start state is a class
# the controller adds), the start states live only under
# prefers-reduced-motion: no-preference, print shows the final state, the
# wheel's links are untouched, and the targets are where they belong.
class AppearDrawInsTest < ActionDispatch::IntegrationTest
  CSS = Rails.root.join("app/assets/tailwind/application.css")
  CONTROLLER = Rails.root.join("app/javascript/controllers/appear_controller.js")
  START_STATES = /\b(draw-wait|draw-run|perform-wait|perform-run|photo-wait|photo-run|img-wait|img-in)\b/

  def css_source = File.read(CSS)

  def render_partial(partial, **locals)
    Nokogiri::HTML5.fragment(ApplicationController.render(partial: partial, locals: locals))
  end

  def no_preference_css
    css_source.scan(/@media \(prefers-reduced-motion: no-preference\)\s*\{(.*?)\n\}/m).flatten.join("\n")
  end

  test "the controller knows the new targets and stays the one reveal system" do
    js = File.read(CONTROLLER)
    assert_match(/static targets = \[\s*"item",\s*"glass",\s*"draw",\s*"photo",\s*"image"\s*\]/, js)
    %w[drawTargetConnected photoTargetConnected imageTargetConnected].each do |cb|
      assert_includes js, cb
    end
    # An image that errors, or never fires load, is shown anyway.
    assert_includes js, '"error"'
    assert_match(/IMAGE_LIMIT = \d+/, js)
    assert_includes js, "complete", "an image already loaded is left alone"
  end

  test "every start state is hidden only under no-preference, and print shows the final picture" do
    no_pref = no_preference_css
    %w[.draw-wait .photo-wait img.img-wait].each do |sel|
      assert_includes no_pref, sel, "#{sel} belongs under prefers-reduced-motion: no-preference"
    end
    outside = css_source.gsub(/@media \(prefers-reduced-motion: no-preference\)\s*\{(.*?)\n\}/m, "").gsub(/@media print\s*\{(.*?)\n\}/m, "")
    refute_match(/(draw-wait|photo-wait|img-wait)[^{]*\{[^}]*(opacity:\s*0|stroke-dashoffset|scale)/, outside,
                 "no start state may apply under reduced motion")

    print = css_source[/@media print\s*\{(.*?)\n\}/m, 1]
    %w[draw-wait photo-wait img-wait].each { |c| assert_includes print, c, "print undoes #{c}" }
  end

  test "the wheel's wedges grow from the hub, never from nothing, and stay links" do
    html = render_partial("reviews/palate_wheel", profile: { "fruity" => 1.0, "smoky" => 0.4, "spicy" => 0.05 })
    svg = html.at_css("svg")
    assert_equal "draw", svg["data-appear-target"]
    wedges = html.css("a > path.wheel-wedge")
    assert_equal 3, wedges.size, "each lit wedge is its own growing path inside its link"
    wedges.each do |w|
      from = w["style"][/--from:\s*([\d.]+)/, 1].to_f
      assert from.positive?, "a wedge never starts from scale 0"
      assert from < 1
    end
    delays = wedges.map { |w| w["style"][/--d:\s*(\d+)ms/, 1].to_i }
    assert_equal delays.sort, delays, "wedges grow one after another"
    gaps = delays.each_cons(2).map { |a, b| b - a }
    assert gaps.each_cons(2).all? { |a, b| b <= a }, "the gaps shrink: #{gaps}"
    html.css("a").each { |a| assert_match %r{/reviews\?tags=}, a["href"] }
    assert html.css("text.wheel-label").size >= 9, "every family label fades in last"

    css = css_source
    assert_match(/\.draw-wait \.wheel-wedge\s*\{[^}]*transform:\s*scale\(var\(--from/, css)
    assert_match(/\.wheel-wedge\s*\{[^}]*transform-origin:\s*0(px)? 0(px)?/, css)
    assert_match(/\.wheel-wedge\s*\{[^}]*transform-box:\s*view-box/, css)
  end

  test "the flavor wave's line draws left to right, its stems grow from the base" do
    get bottle_path(bottles(:eagle_rare))
    assert_response :success
    svg = css_select("svg[data-appear-target=draw]").find { |s| s.at_css("path.wave-line") }
    assert svg, "the wave is a draw target"
    line = svg.at_css("path.wave-line")
    assert_equal "1", line["pathlength"] || line["pathLength"]
    stems = svg.css("line.wave-stem")
    assert_equal Review::DESCRIPTOR_LEXICON.size, stems.size
    stems.each do |s|
      assert_operator s["y1"].to_f, :>=, s["y2"].to_f, "a stem starts at the base and draws up"
      assert_match(/--len:\s*[\d.]+/, s["style"])
    end
    assert_equal Review::DESCRIPTOR_LEXICON.size, svg.css("a text.wave-label").size

    css = css_source
    assert_match(/\.draw-wait \.wave-line\s*\{[^}]*stroke-dashoffset:\s*1/, css)
    assert_match(/\.draw-wait \.wave-stem\s*\{[^}]*stroke-dashoffset:\s*var\(--len\)/, css)
  end

  test "the server never sends a start state" do
    [ root_path, bottle_path(bottles(:eagle_rare)), review_path(reviews(:john_eagle_rare)), presentations_path, membership_path, societies_path ].each do |path|
      get path
      assert_response :success
      classes = Nokogiri::HTML(response.body).css("[class]").map { |el| el["class"] }.join(" ")
      refute_match START_STATES, classes, "#{path}: start states are added by JS only"
    end
  end

  # The step faces no longer perform: the homepage frame moves its own
  # objects (story_frame_controller.js), and the faces are what the page is
  # without JS, in print and for screen readers.
  test "the step faces hold no motion of their own and the frame holds no reveal targets" do
    get root_path
    assert_select ".face [data-appear-target=perform], [data-appear-target~=perform]", 0
    assert_select ".mm [data-appear-target]", 0
    css = page_css
    refute_match(/\.perform-(wait|run)/, css)
    refute_includes File.read(CONTROLLER), "perform-wait"
  end

  test "duotone photographs settle in their frame and fade in as they load" do
    html = render_partial("shared/duotone", src: "photos/rickhouse.jpg", alt: "A rickhouse")
    figure = html.at_css("figure.duotone")
    assert_equal "photo", figure["data-appear-target"]
    assert_equal "image", figure.at_css("img")["data-appear-target"]
    css = css_source
    assert_match(/\.duotone\.photo-wait img\s*\{[^}]*scale:\s*1\.04/, css)
    assert_match(/\.duotone\s*\{[^}]*overflow:\s*hidden/, css, "the frame clips the scale, so nothing shifts")
  end

  test "deck covers, the deck's slides and bottle photos fade in as they load" do
    deck = Presentation.create!(author: users(:admin), title: "Fade Deck", content: "Smoke.", price: 10, preview_slide_count: 2)
    3.times { |n| deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "s#{n}.png", content_type: "image/png") }
    deck.update_column(:published, true)

    get presentations_path
    assert_select ".deck-cover img[data-appear-target=image]", minimum: 1

    get presentation_path(deck)
    assert_select "section img[data-appear-target=image][alt^='Slide ']", minimum: 1

    css = css_source
    assert_match(/img\.img-wait\s*\{[^}]*opacity:\s*0/, css)
    assert_match(/img\.img-in\s*\{[^}]*opacity 200ms var\(--motion-ease-out\)/, css)
  end

  test "motion lasts long enough to be seen, where the eye is" do
    css = css_source
    js = File.read(CONTROLLER)
    assert_match(/\.appear-pending\s*\{\s*opacity:\s*0;\s*translate:\s*0 24px;/, css, "reveal travels 24px")
    assert_match(/\.appear-pending\s*\{\s*translate:\s*0 16px;\s*\}/, css, "16px on phones")
    assert_match(/opacity 700ms var\(--motion-ease-out\)/, css, "reveal lasts 700ms")
    assert_match(/DURATION = 700/, js)
    assert_match(/POUR = 1200/, js)
    assert_match(/draw: \{[^}]*ms: 1250/, js, "a draw-in is watched for about 1.2s")
    assert_match(/ON_LOAD = 300/, js, "a draw-in on screen at load plays shortly after load")
    assert_match(/kind === "draw" \|\| kind === "glass" \? ON_LOAD : 0/, js, "draw-ins and pours on screen at load wait ON_LOAD")
    assert_match(/kind === "draw" \? turbo : fresh/, js, "a draw-in replays on load only on a Turbo visit, so a finished drawing never flashes")

    wedges = render_partial("reviews/palate_wheel", profile: Review::DESCRIPTOR_LEXICON.keys.index_with { 1.0 }).css("path.wheel-wedge")
    last = wedges.map { |w| w["style"][/--d:\s*(\d+)ms/, 1].to_i }.max
    wedge_ms = css[/wheel-grow (\d+)ms/, 1].to_i
    label = css[/\.draw-run \.wheel-label\s*\{[^}]*?(\d+)ms\)/, 1].to_i + css[/\.draw-run \.wheel-label\s*\{[^}]*draw-label (\d+)ms/, 1].to_i
    total = [ last + wedge_ms, label ].max
    assert_includes 1000..1300, total, "the wheel draws in about 1.1-1.3s (#{total}ms)"
  end

  test "the admin area has no controller, so its wheels and photos are simply drawn" do
    sign_in users(:admin)
    get admin_presentations_path
    assert_select "[data-controller~=appear]", 0
  end
end
