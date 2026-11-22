require "application_system_test_case"

# The appear controller in a real browser (headless Chrome). Whatever the
# reader does, every reveal item ends fully visible: arriving by an anchor,
# jumping to the bottom, going back, focusing with the keyboard, with reduced
# motion, and even when IntersectionObserver never fires at all.
class AppearRevealTest < ApplicationSystemTestCase
  ITEMS = "[data-appear-target~='item']".freeze
  BUSY = ".appear-pending, .glass-wait, .glass-pouring, .draw-wait, .draw-run, .perform-wait, .perform-run, .photo-wait, .photo-run, .img-wait".freeze

  # Items that are hidden or not fully opaque, as "tag.class" strings.
  def faded_items
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("#{ITEMS}")]
        .filter((el) => el.classList.contains("appear-pending") || parseFloat(getComputedStyle(el).opacity) < 0.999)
        .map((el) => el.tagName.toLowerCase() + "." + [...el.classList].slice(0, 3).join("."))
    JS
  end

  # Waits (Capybara's retry) for every reveal to settle, then checks opacity.
  def assert_everything_visible(context)
    assert_no_selector BUSY, visible: :all, wait: 5
    assert page.evaluate_script("document.querySelectorAll(\"#{ITEMS}\").length").positive?, "#{context}: expected reveal items"
    assert_empty faded_items, "#{context}: left faded"
  end

  def jump_to_bottom
    page.execute_script("window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'instant' })")
  end

  def scroll_through_page
    page.execute_script(<<~JS)
      window.__scrollDone = false;
      (async () => {
        const h = document.documentElement.scrollHeight;
        for (let y = 0; y <= h; y += 400) {
          window.scrollTo({ top: y, behavior: "instant" });
          await new Promise((r) => setTimeout(r, 30));
        }
        window.__scrollDone = true;
      })();
    JS
    assert wait_until { page.evaluate_script("window.__scrollDone") }, "the scroll did not finish"
  end

  def wait_until(seconds = 10)
    deadline = Time.now + seconds
    until yield
      return false if Time.now > deadline
      sleep 0.05
    end
    true
  end

  def cdp(command, **params)
    page.driver.browser.execute_cdp(command, **params)
  end

  test "arriving by an anchor shows the pricing rows and the FAQ at once" do
    visit root_path(anchor: "pricing")
    assert_selector "#pricing a.plan", count: 3
    assert_no_selector "#pricing .appear-pending", visible: :all, wait: 5
    jump_to_bottom
    assert_everything_visible "/#pricing"

    visit root_path(anchor: "faq")
    assert_selector "#faq details"
    assert_no_selector "#faq .appear-pending", visible: :all, wait: 5
    jump_to_bottom
    assert_everything_visible "/#faq"
  end

  test "a jump to the bottom, then a visit and back, leaves nothing faded" do
    visit root_path
    assert_selector "main[data-controller~=appear]"
    # Below the fold waits hidden until seen.
    assert_selector "#pricing .appear-pending", visible: :all
    jump_to_bottom
    assert_everything_visible "home after jump"

    # Back at the top, so the fixed nav does not cover the hero's link.
    page.execute_script("window.scrollTo({ top: 0, behavior: 'instant' })")
    click_link "Browse the decks", match: :first
    assert_current_path presentations_path
    wait_for_turbo_visit
    page.go_back
    assert_current_path root_path
    wait_for_turbo_visit
    assert_no_selector "main .appear-pending:not(.is-in)", visible: :all, wait: 1
    # A back visit replays nothing: no face performs, nothing draws again.
    assert_no_selector ".perform-wait, .perform-run, .draw-wait, .draw-run, .glass-wait, .glass-pouring", visible: :all, wait: 0
    scroll_through_page
    assert_no_selector ".perform-wait, .perform-run, .draw-wait, .draw-run", visible: :all, wait: 0
    assert_everything_visible "home after back"
  end

  test "focusing something inside a waiting item shows it at once" do
    visit root_path
    assert_selector "#faq .faq.appear-pending", visible: :all
    page.execute_script("document.querySelector('#faq summary').focus({ preventScroll: true })")
    assert_no_selector "#faq .faq.appear-pending", visible: :all, wait: 0.5
    assert_equal 1.0, page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('#faq .faq')).opacity)")
  end

  test "with IntersectionObserver never firing, nothing stays hidden" do
    stub = cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
      window.IntersectionObserver = class { observe() {} unobserve() {} disconnect() {} takeRecords() { return [] } };
    JS
    visit root_path
    assert_selector "#pricing .appear-pending", visible: :all
    scroll_through_page
    assert_everything_visible "home, observer stubbed"
  ensure
    # The stub lives in the browser session; later tests must not inherit it.
    cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: stub["identifier"]) if stub
  end

  test "with reduced motion nothing is ever hidden" do
    cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    visit root_path
    assert_selector "main[data-controller~=appear]"
    assert_no_selector BUSY, visible: :all
    scroll_through_page
    assert_no_selector BUSY, visible: :all
    assert_empty faded_items, "reduced motion: left faded"
  ensure
    cdp("Emulation.setEmulatedMedia", features: [])
  end
end
