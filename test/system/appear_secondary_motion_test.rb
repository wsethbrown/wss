require "application_system_test_case"

# The appear controller's secondary motion and image fade in a real browser
# (headless Chrome in CI; there is no chromedriver locally). Whatever happens,
# nothing is left in a start state: an image that fails or is removed while it
# waits, a Turbo stream that replaces a drawing mid-wait, the bottle page's
# wave, and keyboard focus inside a drawing.
class AppearSecondaryMotionTest < ApplicationSystemTestCase
  BUSY = ".draw-wait, .draw-run, .perform-wait, .perform-run, .photo-wait, .photo-run, .glass-wait, .glass-pouring, .img-wait".freeze

  def scroll_through_page
    page.execute_script(<<~JS)
      window.__scrollDone = false;
      (async () => {
        const h = document.documentElement.scrollHeight;
        for (let y = 0; y <= h; y += 300) {
          window.scrollTo({ top: y, behavior: "instant" });
          await new Promise((r) => setTimeout(r, 60));
        }
        window.__scrollDone = true;
      })();
    JS
    assert_selector "body", wait: 1
    Timeout.timeout(15) { sleep 0.05 until page.evaluate_script("window.__scrollDone") }
  end

  # Adds an element to <main> the way a Turbo stream or a lazy render would,
  # below the fold so it starts out waiting.
  def append_to_main(html)
    page.execute_script(<<~JS, html)
      const spacer = document.createElement("div");
      spacer.style.height = "200vh";
      spacer.id = "spacer";
      document.querySelector("main").append(spacer);
      const holder = document.createElement("div");
      holder.id = "late";
      holder.innerHTML = arguments[0];
      document.querySelector("main").append(holder);
    JS
  end

  test "an image that fails to load while waiting is shown, not left invisible" do
    visit reviews_path
    assert_selector "main[data-controller~=appear]"
    append_to_main(%(<img data-appear-target="image" id="broken" alt="x" width="40" height="40" src="/no-such-image-#{SecureRandom.hex(4)}.jpg">))
    assert_no_selector "#broken.img-wait", visible: :all, wait: 5
    assert_equal 1.0, page.evaluate_script("parseFloat(getComputedStyle(document.getElementById('broken')).opacity)")
  end

  test "an image removed while waiting takes its start state with it" do
    visit reviews_path
    append_to_main(%(<img data-appear-target="image" id="gone" alt="x" width="40" height="40" loading="lazy" src="/icon.png?#{SecureRandom.hex(4)}">))
    page.execute_script("window.__gone = document.getElementById('gone'); window.__gone.remove()")
    sleep 0.2
    refute page.evaluate_script("window.__gone.classList.contains('img-wait') || window.__gone.classList.contains('img-in')"),
           "a removed image keeps no start state"
  end

  test "a Turbo stream replacing a waiting wheel, glass and image leaves nothing in a start state" do
    visit review_path(reviews(:john_eagle_rare))
    wheel = page.evaluate_script("document.querySelector('svg[data-appear-target~=draw]') ? document.querySelector('svg[data-appear-target~=draw]').outerHTML : ''")
    assert wheel.present?, "the review page draws a wheel"
    glass = page.evaluate_script("document.querySelector('svg[data-glass]').outerHTML")
    append_to_main(%(<div id="region">#{wheel}#{glass}<img data-appear-target="image" alt="" width="40" height="40" src="/icon.png?#{SecureRandom.hex(4)}"></div>))
    # Replace the region while its contents wait below the fold.
    page.execute_script(<<~JS, wheel, glass)
      Turbo.renderStreamMessage(`<turbo-stream action="replace" target="region"><template><div id="region">${arguments[0]}${arguments[1]}</div></template></turbo-stream>`);
    JS
    scroll_through_page
    assert_no_selector BUSY, visible: :all, wait: 5
  end

  test "the bottle page's wave and identity photo end drawn" do
    visit bottle_path(bottles(:eagle_rare))
    assert_selector "svg[data-appear-target~=draw] .wave-line", visible: :all
    scroll_through_page
    assert_no_selector BUSY, visible: :all, wait: 5
    offset = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.wave-line')).strokeDashoffset) || 0")
    assert_equal 0.0, offset.to_f
  end

  test "focusing a link inside a waiting wheel shows the wheel at once" do
    visit review_path(reviews(:john_eagle_rare))
    page.execute_script("window.scrollTo({ top: 0, behavior: 'instant' })")
    waiting = page.evaluate_script("!!document.querySelector('svg.draw-wait')")
    skip "the wheel is on screen at load in this window, so it never waits" unless waiting
    page.execute_script("document.querySelector('svg.draw-wait a').focus({ preventScroll: true })")
    assert_no_selector "svg.draw-wait, svg.draw-run", visible: :all, wait: 0.5
  end
end
