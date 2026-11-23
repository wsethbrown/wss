require "test_helper"

# Round 4 of the motion work, after the owner tried it in real Safari:
# - motion inside a pinned homepage face waits until the face has settled
# - phones start a reveal a little earlier
# - the RSVP table's glasses re-pour from their old level to the new one
# - sideways-scrolling chip rows fade at the edge with more to scroll
# The motion itself runs in the browser; these pin the wiring it relies on.
class MotionRound4Test < ActionDispatch::IntegrationTest
  CONTROLLER = Rails.root.join("app/javascript/controllers/appear_controller.js")
  CSS = Rails.root.join("app/assets/tailwind/application.css")

  # The faces are no longer pinned or crossfaded (the frame replaced them),
  # so the appear controller holds nothing for them.
  test "nothing waits for a homepage face: the faces are plain and the held machinery is gone" do
    get root_path
    assert_select "[data-appear-settle], [data-faces-hold], [data-face-shown]", 0
    js = File.read(CONTROLLER)
    %w[unsettled checkHeld appear:settled data-faces-hold HELD_IDLE holdLate pageIdle covered].each { |dead| refute_includes js, dead }
  end

  test "phones start a reveal earlier than wide screens" do
    js = File.read(CONTROLLER)
    assert_match(/PHONE_ITEM_MARGIN = "0px 0px -(8|9|10)% 0px"/, js)
    assert_match(/PHONE = "not all and \(min-width: 640px\)"/, js, "no gap at fractional widths")
    assert_match(/this\.phone\.matches \? PHONE_ITEM_MARGIN : ITEM_MARGIN/, js)
    assert_match(/this\.phone\.addEventListener\("change", this\.onPhoneChange\)/, js, "a rotation rebuilds the trigger")
    assert_match(/this\.phone\.removeEventListener\("change", this\.onPhoneChange\)/, js, "and the listener is removed on disconnect")
  end

  test "the RSVP table re-pours its glasses when a stream replaces it" do
    js = File.read(CONTROLLER)
    assert_includes js, "turbo:before-stream-render"
    assert_match(/REPOUR = 500/, js)
    assert_includes js, "cubic-bezier(0.2, 0.7, 0.2, 1)", "on the pour curve"
    assert_match(/rect\.bottom <= 0 \|\| rect\.top >= height\) return/, js, "nothing off screen")
    assert_match(/typeof paths\[0\]\.animate !== "function"\) return/, js, "no Web Animations, no motion")
    assert_match(/try \{ this\.repour\(id, before\) \} catch/, js, "the stream render never fails because of it")
    assert_match(/if \(drop < 0\) \{\s*under = paths\[0\]\.cloneNode\(\)/, js, "a falling level keeps the bowl full below the surface")

    sign_in users(:seth)
    event = events(:mystery_flight)
    get event_path(event)
    assert_response :success
    assert_select "#event-attendees [data-role=the-table][data-repour] svg[data-glass]", minimum: 1

    post event_event_rsvps_path(event), params: { status: "maybe" }, as: :turbo_stream
    assert_response :success
    assert_match(/<turbo-stream action="replace" target="event-attendees">/, response.body)
    fragment = Nokogiri::HTML5.fragment(response.body[/target="event-attendees"><template>(.*?)<\/template>/m, 1].to_s)
    assert fragment.at_css("[data-role=the-table][data-repour]"), "the replaced table is marked for the re-pour"
  end

  test "sideways chip rows fade at the edge with more to scroll" do
    get presentations_path
    assert_select "#deck-filters .scroll-row[data-controller~=scroll-fade]", 1
    rows = css_select(".scroll-row")
    rows.each do |row|
      classes = row["class"].split
      assert_includes classes, "-mx-4", "runs to the screen edge"
      assert_includes classes, "px-4", "the first item still lines up with the page"
      assert_includes classes, "overflow-x-auto"
    end
    css = File.read(CSS)
    assert_match(/\.scroll-row\s*\{\s*scrollbar-width:\s*none;\s*scroll-padding-inline:\s*48px;/, css, "focus stops clear of the fade")
    assert_match(/\.scroll-row\[data-more-end\]\s*\{[^}]*mask-image:\s*linear-gradient\(to right, #000 calc\(100% - 40px\), transparent\)/, css)
    assert_match(/\.scroll-row\[data-more-start\]\s*\{[^}]*mask-image:\s*linear-gradient\(to right, transparent, #000 40px\)/, css)
    assert_match(/-webkit-mask-image/, css, "Safari needs the prefix")
    controller = File.read(Rails.root.join("app/javascript/controllers/scroll_fade_controller.js"))
    assert_includes controller, 'toggleAttribute("data-more-end"'
    assert_includes controller, "ResizeObserver"
    assert_match(/this\.resize\.observe\(child\)/, controller, "items changing size re-measure the row")
    assert_includes controller, "document.fonts.ready"
    assert_includes controller, "this.mutations.disconnect()"
    assert_match(/addEventListener\("focusin", this\.onFocus\)/, controller, "a focused item is scrolled clear of the fade")
  end

  test "no horizontally scrolling row on a public page goes without the fade" do
    deck = Presentation.create!(author: users(:admin), title: "Row Deck", content: "Smoke.", price: 10)
    deck.update_column(:published, true)
    pages = [ root_path, presentations_path, presentation_path(deck), societies_path, reviews_path, membership_path, auth_path,
              review_path(reviews(:john_eagle_rare)), bottle_path(bottles(:eagle_rare)) ]
    pages.each do |path|
      get path
      assert_response :success, path
      Nokogiri::HTML(response.body).css("[class]").each do |el|
        classes = el["class"].split # however the attribute is wrapped across lines
        next unless classes.include?("overflow-x-auto") && (classes & %w[flex inline-flex]).any?
        assert_includes classes, "scroll-row", "#{path}: a sideways-scrolling row without the edge fade"
        assert_includes el["data-controller"].to_s.split, "scroll-fade", path
      end
    end
  end
end
