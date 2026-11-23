require "application_system_test_case"

# The homepage story's frame in a real browser (story_frame_controller.js).
# The scroll picks the current step; the move to it plays on a clock to the
# end. Everything is driven and measured inside the page: scrolls are instant
# (the site sets scroll-behavior: smooth), step positions come from live
# geometry, and a probe samples the controller's state against
# performance.now(), so Ruby-side sleeps play no part. Margins are generous:
# a move takes about 1.2s, the probes wait up to 6s. No viewport or media
# emulation: the window is resized before the visit and put back in ensure,
# and reduced motion is stubbed in the page (matchMedia) before the
# controller is connected again. Every failure prints the whole record.
class HomeStoryFrameSystemTest < ApplicationSystemTestCase
  PROBE = <<~JS.freeze
    window.__frameProbe = (async (plan) => {
      const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
      const c = () => window.__storyFrame;
      const t0 = performance.now(), record = [];
      const snap = (at) => ({ at, t: Math.round(performance.now() - t0), P: +c().P.toFixed(3), target: c().target,
                              playing: !!c().raf, live: !!document.querySelector(".story.is-live") });
      // Put a step's words 30% down the reading area: the step being read.
      const read = (i) => {
        const area = innerWidth >= 900 ? 0 : document.querySelector(".mm").getBoundingClientRect().bottom;
        scrollTo({ top: c().tops[i] - area - (innerHeight - area) * 0.3, behavior: "instant" });
      };
      const settle = async (at) => {
        for (let n = 0; n < 120 && (c().raf || c().P !== c().target); n++) await sleep(50);
        await sleep(100);
        record.push(snap(at));
      };
      for (const step of plan) {
        if (step.read !== undefined) { read(step.read); record.push(snap(`read ${step.read}`)); }
        if (step.event) { document.dispatchEvent(new Event(step.event)); record.push(snap(step.event)); }
        if (step.wait) await sleep(step.wait);
        if (step.sample) { for (let n = 0; n < step.sample; n++) { record.push(snap("sample")); await sleep(80); } }
        if (step.settle) await settle(step.settle);
      }
      return { width: innerWidth, height: innerHeight, record,
               bandTop: Math.round(document.querySelector(".mm").getBoundingClientRect().top) };
    })(arguments[0]).then((r) => { window.__frameResult = r; });
  JS

  def visit_at(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    visit root_path
  end

  def run_probe(plan)
    assert_selector ".story.is-live", visible: :all
    page.execute_script("window.__frameResult = undefined; #{PROBE}", plan)
    Timeout.timeout(60) { sleep 0.1 until page.evaluate_script("window.__frameResult !== undefined") }
    page.evaluate_script("window.__frameResult")
  end

  def probe(plan, width: 1440, height: 900)
    visit_at(width, height)
    run_probe(plan)
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  # Stimulus disconnects and connects a controller when its attribute goes and comes back.
  def reconnect_frame(before = "")
    page.execute_script(<<~JS)
      #{before}
      const story = document.querySelector(".story");
      story.removeAttribute("data-controller");
      setTimeout(() => story.setAttribute("data-controller", "story-frame"), 50);
    JS
    sleep 0.4
  end

  def static_face_shown?(selector)
    page.evaluate_script(<<~JS)
      (() => { const f = document.querySelector("#{selector}"); const r = f.getBoundingClientRect();
               return !document.querySelector(".story.is-live") && r.width > 100 && r.height > 100 &&
                      getComputedStyle(document.querySelector(".mm")).display === "none"; })()
    JS
  end

  test "the current step follows the scroll, and each move plays to its end after the scroll stops" do
    r = probe((1..4).map { |i| { read: i, settle: "step #{i}" } } + [ { read: 1, settle: "back to 1" } ])
    settled = r["record"].select { |s| s["at"].start_with?("step", "back") }
    assert_equal [ 1, 2, 3, 4, 1 ], settled.map { |s| s["P"] }, "each step's arrangement, at rest: #{r}"
    assert(settled.none? { |s| s["playing"] }, "nothing left playing once settled: #{r}")
  end

  test "a move keeps playing with the page still, and turning back mid-move reverses from where it was" do
    r = probe([ { read: 1, settle: "at 1" }, { read: 2, wait: 300, sample: 1 }, { read: 1, sample: 8 }, { settle: "end" } ])
    mid = r["record"].find { |s| s["at"] == "sample" }
    assert_operator mid["P"], :>, 1.0, "the move to step 2 had started: #{r}"
    assert_operator mid["P"], :<, 2.0, "and was still under way after 300ms of stillness: #{r}"
    after = r["record"].select { |s| s["at"] == "sample" }.drop(1).map { |s| s["P"] }
    assert_operator (after.first - mid["P"]).abs, :<, 0.3, "no jump when it turns back: #{r}"
    after.each_cons(2) { |a, b| assert_operator b, :<=, a + 0.001, "it reverses steadily: #{r}" }
    assert_equal 1, r["record"].last["P"], r
  end

  test "before Turbo caches the page the frame is at rest, and a hidden or shown tab changes nothing" do
    r = probe([ { read: 1, settle: "at 1" }, { read: 2, wait: 300 }, { event: "turbo:before-cache" }, { wait: 200, sample: 1 },
                { event: "visibilitychange" }, { wait: 200, sample: 1 } ])
    samples = r["record"].select { |s| s["at"] == "sample" }
    assert_equal 2, samples.first["P"], "landed at the current step: #{r}"
    refute samples.first["playing"], "no frame pending after turbo:before-cache: #{r}"
    assert_equal samples.first["P"], samples.last["P"], "visibilitychange moves nothing: #{r}"
  end

  test "under reduced motion each step simply shows its arrangement" do
    visit_at(1440, 900)
    assert_selector ".story.is-live", visible: :all
    reconnect_frame(<<~JS)
      const real = window.matchMedia.bind(window);
      window.matchMedia = (q) => q.includes("prefers-reduced-motion: reduce")
        ? { matches: true, media: q, addEventListener() {}, removeEventListener() {}, addListener() {}, removeListener() {} }
        : real(q);
    JS
    r = run_probe([ { read: 2, sample: 3 }, { read: 3, sample: 3 } ])
    samples = r["record"].select { |s| s["at"] == "sample" }
    assert(samples.all? { |s| s["P"] == s["P"].round && !s["playing"] }, "never in between, never playing: #{r}")
    assert_equal [ 2, 2, 2, 3, 3, 3 ], samples.map { |s| s["P"] }, r
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "if the frame cannot run, or fails, the static faces show" do
    visit_at(1440, 900)
    assert_selector ".story.is-live", visible: :all
    # No ResizeObserver: the controller declines and the faces stay.
    reconnect_frame("window.__RO = window.ResizeObserver; window.ResizeObserver = undefined;")
    assert static_face_shown?(".face.f1"), "no observer: the hero's face shows"
    # A failure inside the controller (an unreadable config): it stops and the faces show.
    reconnect_frame(<<~JS)
      window.ResizeObserver = window.__RO;
      document.querySelector(".mm").dataset.config = "{";
    JS
    assert static_face_shown?(".face.f1"), "after a failure the hero's face shows"
    assert static_face_shown?(".face.f3"), "and every other face"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "crossing 900px keeps the current step" do
    visit_at(1440, 900)
    r = run_probe([ { read: 2, settle: "wide" } ])
    assert_equal 2, r["record"].last["P"], r
    page.driver.browser.manage.window.resize_to(820, 1000)
    sleep 0.6
    state = page.evaluate_script("({ P: window.__storyFrame.P, live: !!document.querySelector('.story.is-live'), pos: getComputedStyle(document.querySelector('.mm')).position })")
    assert_equal 2, state["P"], state
    assert state["live"], state
    assert_equal "sticky", state["pos"], "the band below 900px: #{state}"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "on a phone the frame is a band pinned under the nav and follows the same steps" do
    r = probe((1..4).map { |i| { read: i, settle: "step #{i}" } }, width: 400, height: 860)
    assert_operator r["width"], :<, 900, "a phone-width window: #{r}"
    settled = r["record"].select { |s| s["at"].start_with?("step") }
    assert_equal [ 1, 2, 3, 4 ], settled.map { |s| s["P"] }, r
    assert_operator r["bandTop"], :<, 140, "pinned near the top, under the nav: #{r}"
  end

  test "a phone in landscape is too short for the band: the words and faces show" do
    visit_at(844, 390)
    assert_no_selector ".story.is-live", visible: :all, wait: 2
    visible = page.evaluate_script(<<~JS)
      (() => {
        const h = document.querySelector(".b2 h2");
        h.scrollIntoView({ block: "center", behavior: "instant" });
        const r = h.getBoundingClientRect();
        const hit = document.elementFromPoint(r.left + Math.min(20, r.width / 2), r.top + r.height / 2);
        return { inView: r.top >= 0 && r.bottom <= innerHeight, onTop: !!hit && h.contains(hit), height: innerHeight };
      })()
    JS
    assert visible["inView"], visible
    assert visible["onTop"], "nothing covers the step's heading: #{visible}"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
