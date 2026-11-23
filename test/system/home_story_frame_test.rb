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
#
# Window sizes: headless Chrome's page is about 87px shorter than its window
# (a 820x1000 window gives 820x913) and no narrower than 500px, so every test
# reads the real size back and picks sizes with room to spare either way.
class HomeStoryFrameSystemTest < ApplicationSystemTestCase
  # Shared by the scripts below: window.__sf.
  HELPERS = <<~JS.freeze
    window.__sf = {
      sleep: (ms) => new Promise((r) => setTimeout(r, ms)),
      frames: (n) => new Promise((r) => { const f = () => (n-- <= 0 ? r() : requestAnimationFrame(f)); f(); }),
      async until(ok, limit = 10000) {
        const start = performance.now();
        while (!ok() && performance.now() - start < limit) await this.sleep(20);
        return ok();
      },
      // Put a step's words 30% down the reading area: the step being read.
      read(i) {
        const c = window.__storyFrame;
        const area = innerWidth >= 900 ? 0 : document.querySelector(".mm").getBoundingClientRect().bottom;
        scrollTo({ top: c.tops[i] - area - (innerHeight - area) * 0.3, behavior: "instant" });
      },
      // Where a step's words are on screen, against the nav and the band.
      words(i) {
        const el = document.querySelectorAll(".story [data-story-frame-target=beat]")[i].querySelector(".beat-body, h1, h2");
        const r = el.getBoundingClientRect(), nav = document.querySelector("body > nav, nav.fixed").getBoundingClientRect().bottom;
        const live = !!document.querySelector(".story.is-live");
        const band = live && innerWidth < 900 ? document.querySelector(".mm").getBoundingClientRect().bottom : nav;
        return { top: Math.round(r.top), bottom: Math.round(r.bottom), nav: Math.round(nav), band: Math.round(band) };
      },
      state() {
        const c = window.__storyFrame, mm = document.querySelector(".mm");
        return { width: innerWidth, height: innerHeight, stable: c ? c.stableHeight() : null,
                 live: !!document.querySelector(".story.is-live"), P: c ? c.P : null, target: c ? c.target : null,
                 raf: c ? c.raf : null, scrollFrame: c ? c.scrollFrame : null, layoutFrame: c ? c.layoutFrame : null,
                 failed: c ? c.failed : null, pos: getComputedStyle(mm).position,
                 padding: document.documentElement.style.scrollPaddingTop, measures: c ? c.__measures : null,
                 log: (window.__frameLog || []).slice(-6) };
      },
      // Count the controller's measures and its console lines from here on.
      watch() {
        const c = window.__storyFrame;
        if (!c.__measures && c.__measures !== 0) { const m = c.measure; c.measure = function () { c.__measures++; return m.apply(this, arguments); }; }
        c.__measures = 0;
        window.__frameLog = [];
      }
    };
    if (!window.__consoleHooked) {
      window.__consoleHooked = true;
      for (const k of [ "info", "warn", "error" ]) {
        const real = console[k].bind(console);
        console[k] = (...a) => { (window.__frameLog ||= []).push(`${k}: ${a.map(String).join(" ")}`); real(...a); };
      }
    }
  JS

  PROBE = <<~JS.freeze
    window.__frameProbe = (async (plan) => {
      const sf = window.__sf, c = () => window.__storyFrame;
      const t0 = performance.now(), record = [];
      const snap = (at) => ({ at, t: Math.round(performance.now() - t0), P: +c().P.toFixed(3), target: c().target,
                              playing: !!c().raf, live: !!document.querySelector(".story.is-live") });
      // Wait on state, never on time: until the step read is the current one,
      // the frame has arrived at it and nothing is pending (up to 10s).
      let want = 0;
      const settled = () => c().target === want && c().P === want && !c().raf;
      for (const step of plan) {
        if (step.read !== undefined) { want = step.read; sf.read(step.read); record.push(snap(`read ${step.read}`)); }
        if (step.event) { document.dispatchEvent(new Event(step.event)); record.push(snap(step.event)); }
        // Mid-move: wait until the frame is under way past a point, not for a time.
        if (step.past !== undefined) { const ok = await sf.until(() => c().P >= step.past); record.push({ ...snap("past"), reached: ok }); }
        if (step.settle) { const ok = await sf.until(settled); record.push({ ...snap(step.settle), settled: ok }); }
        if (step.sample) { for (let n = 0; n < step.sample; n++) { record.push(snap("sample")); await sf.sleep(80); } }
      }
      return { width: innerWidth, height: innerHeight, record,
               bandTop: Math.round(document.querySelector(".mm").getBoundingClientRect().top) };
    })(arguments[0]).then((r) => { window.__frameResult = r; });
  JS

  def visit_at(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    visit root_path
    wait_for_frame_connected
  end

  # The controller has connected and made its first decision (live or not).
  def wait_for_frame_connected
    wait_for("the frame's controller to connect") { page.evaluate_script("!!(window.__storyFrame && window.__storyFrame.inputs)") }
    page.execute_script(HELPERS)
  end

  def frame_state
    page.execute_script(HELPERS) if page.evaluate_script("!window.__sf")
    page.evaluate_script("window.__sf.state()")
  end

  # Waits on state, never on time; the failure names what it waited for and
  # the frame's whole state.
  def wait_for(what, timeout: 10)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      value = yield
      return value if value
      flunk "Timed out waiting for #{what}: #{frame_state rescue 'no state'}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.05
    end
  end

  # Runs an async script body in the page (with window.__sf) and returns its result.
  def run_async(body, arg = nil)
    page.execute_script(HELPERS)
    page.execute_script("window.__asyncResult = undefined; (async (arg) => { #{body} })(arguments[0]).then((r) => { window.__asyncResult = r ?? null; }, (e) => { window.__asyncResult = { error: String(e) }; });", arg)
    wait_for("the page script to finish", timeout: 60) { page.evaluate_script("window.__asyncResult !== undefined") }
    result = page.evaluate_script("window.__asyncResult")
    flunk "page script threw: #{result['error']}" if result.is_a?(Hash) && result["error"]
    result
  end

  def run_probe(plan)
    assert_selector ".story.is-live", visible: :all
    page.execute_script(HELPERS)
    page.execute_script("window.__frameResult = undefined; #{PROBE}", plan)
    wait_for("the probe to finish", timeout: 60) { page.evaluate_script("window.__frameResult !== undefined") }
    page.evaluate_script("window.__frameResult")
  end

  def probe(plan, width: 1440, height: 900)
    visit_at(width, height)
    run_probe(plan)
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  # Stimulus disconnects and connects a controller when its attribute goes and
  # comes back. Waits until it really has: the old one disconnected and it connected again, or (when
  # the new one declines to run) the line it logs instead.
  def reconnect_frame(before = "", expect_log: nil)
    page.execute_script(HELPERS)
    page.execute_script(<<~JS)
      window.__frameLog = [];
      #{before}
      document.querySelector(".story").removeAttribute("data-controller");
    JS
    # Stimulus reuses the controller object for the same element, so identity
    # proves nothing: disconnect clears window.__storyFrame, and connect sets
    # it again with a fresh decision. Wait for each in turn.
    wait_for("the old controller to disconnect") { page.evaluate_script("window.__storyFrame === null && !document.querySelector('.story.is-live')") }
    page.execute_script("document.querySelector('.story').setAttribute('data-controller', 'story-frame')")
    if expect_log
      wait_for("the new controller to log #{expect_log.inspect}") { page.evaluate_script("(window.__frameLog || []).some((l) => l.includes(#{expect_log.to_json}))") }
    else
      wait_for("the controller to connect again") { page.evaluate_script("!!(window.__storyFrame && window.__storyFrame.inputs)") }
    end
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
    assert(settled.all? { |s| s["settled"] }, "each move reached its step and stopped: #{r}")
    assert_equal [ 1, 2, 3, 4, 1 ], settled.map { |s| s["P"] }, "each step's arrangement, at rest: #{r}"
    assert(settled.none? { |s| s["playing"] }, "nothing left playing once settled: #{r}")
  end

  test "a move keeps playing with the page still, and turning back mid-move reverses from where it was" do
    # The page is still while the move plays (no scroll between "read 2" and
    # "past"); the turn back comes once it is a third of the way, whatever
    # the machine's speed.
    r = probe([ { read: 1, settle: "at 1" }, { read: 2, past: 1.33 }, { read: 1, sample: 8 }, { settle: "end" } ])
    mid = r["record"].find { |s| s["at"] == "past" }
    assert mid["reached"], "the move to step 2 played on its own with the page still: #{r}"
    assert_operator mid["P"], :<, 2.0, "and was caught under way: #{r}"
    after = r["record"].select { |s| s["at"] == "sample" }.map { |s| s["P"] }
    # The scroll back is read on the next frame, so on a slow machine the move
    # may go on a frame or two before it turns: allow that, then it only falls.
    assert_operator after.max - mid["P"], :<, 0.15, "no jump when it turns back: #{r}"
    falling = after.drop_while.with_index { |p, i| i + 1 < after.size && after[i + 1] >= p }
    falling.each_cons(2) { |a, b| assert_operator b, :<=, a + 0.001, "once turned, it reverses steadily: #{r}" }
    assert r["record"].last["settled"], "it comes to rest at step 1: #{r}"
    assert_equal 1, r["record"].last["P"], r
  end

  test "before Turbo caches the page the frame is at rest, and a hidden or shown tab changes nothing" do
    # Mid-move, Turbo's before-cache lands the frame at once at the current step.
    r = probe([ { read: 1, settle: "at 1" }, { read: 2, past: 1.2 }, { event: "turbo:before-cache" }, { sample: 1 },
                { event: "visibilitychange" }, { sample: 2 } ])
    samples = r["record"].select { |s| s["at"] == "sample" }
    assert_equal 2, samples.first["P"], "landed at the current step: #{r}"
    refute samples.first["playing"], "no frame pending after turbo:before-cache: #{r}"
    assert(samples.all? { |s| s["P"] == 2 && !s["playing"] }, "visibilitychange moves nothing: #{r}")
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
    assert page.evaluate_script("window.__storyFrame.reduce.matches"), "the new controller sees reduced motion"
    # The step changes on the frame after the scroll (the scroll handler runs
    # once per frame), so wait for it, then check it never travels.
    r = run_probe([ { read: 2, settle: "at 2", sample: 3 }, { read: 3, settle: "at 3", sample: 3 } ])
    assert(r["record"].select { |s| s["at"].start_with?("at ") }.all? { |s| s["settled"] }, "each step reached: #{r}")
    samples = r["record"].select { |s| s["at"] == "sample" }
    assert(samples.all? { |s| s["P"] == s["P"].round && !s["playing"] }, "never in between, never playing: #{r}")
    assert_equal [ 2, 2, 2, 3, 3, 3 ], samples.map { |s| s["P"] }, r
    passing = r["record"].each_cons(2).select { |a, _| a["at"].start_with?("read") }.map { |_, b| b["P"] }
    assert(passing.all? { |p| p == p.round }, "even on its way it is only ever at a step: #{r}")
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  # The record's wheel draws on its own clock once the record has arrived:
  # not complete when the move lands, complete later with the page still.
  WHEEL = <<~JS.freeze
    window.__wheel = () => {
      const c = window.__storyFrame;
      return { P: c.P, target: c.target, w: c.w, end: c.wheelEnd, wedges: c.wedges.length, playing: !!c.raf,
               grown: c.wedges.every((w) => w.s === 1), tinted: c.wedges.every((w) => w.c === 1),
               labels: c.wheelLabels.length > 0 && c.wheelLabels.every((l) => getComputedStyle(l).opacity === "1") };
    };
  JS

  def reviews_with_wheels
    Review.destroy_all
    %w[Smoke Honey Orchard].each_with_index do |name, i|
      bottle = Bottle.create!(name: "#{name} Pour", distillery: "Frame Distillery")
      review = Review.new(user: users(:john), bottle: bottle, rating: 4 - i * 0.5, notes: "A note.",
                          flavor_wheel: { "smoky" => 0.7, "sweet" => 0.5, "fruity" => 0.4, "spicy" => 0.3 })
      review.save!(validate: false)
      review.update_columns(created_at: i.hours.ago)
    end
    # The record leads with a bottle the featured deck pours (HomepageFeature);
    # without one it would draw the sample review in place of these.
    deck = Presentation.create!(author: users(:admin), title: "Wheel Deck", content: "A story.", price: 9.99)
    deck.update_column(:published, true)
    deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "s.jpg", content_type: "image/jpeg")
    deck.presentation_bottles.create!(bottle: Bottle.find_by!(name: "Smoke Pour"))
  end

  test "the record's wheel draws on its own after the move lands, and draws again on the next visit" do
    reviews_with_wheels
    visit_at(1440, 900)
    assert_selector ".story.is-live", visible: :all
    page.execute_script(WHEEL)
    r = run_async(<<~JS)
      const sf = window.__sf, c = window.__storyFrame;
      sf.read(4);
      await sf.until(() => c.P === 4 && !c.anim);
      const landed = window.__wheel(), y = scrollY;
      await sf.until(() => c.w >= c.wheelEnd && !c.raf);
      const done = { ...window.__wheel(), still: scrollY === y };
      sf.read(3);
      await sf.until(() => c.P === 3 && c.target === 3 && !c.anim);
      const away = window.__wheel();
      return { landed, done, away };
    JS
    landed, done, away = r.values_at("landed", "done", "away")
    assert_operator landed["wedges"], :>, 0, "the card has a wheel: #{r}"
    assert_operator landed["end"], :>=, 1.8, "four wedges a quarter second apart, each about a second: #{r}"
    refute landed["tinted"], "not complete when the move lands: #{r}"
    assert_operator landed["w"], :<, landed["end"], "under way (it starts as the card lands) but not done: #{r}"
    assert landed["playing"], "it goes on playing: #{r}"
    assert done["still"], "the page stayed still: #{r}"
    assert done["grown"] && done["tinted"] && done["labels"], "complete on its own: #{r}"
    refute done["playing"], "and then nothing runs: #{r}"
    assert_equal 0, away["w"], "leaving the record, it is ready to draw again: #{r}"
  end

  test "under reduced motion, and before Turbo caches the page, the record's wheel is simply drawn" do
    reviews_with_wheels
    visit_at(1440, 900)
    assert_selector ".story.is-live", visible: :all
    page.execute_script(WHEEL)
    # Mid-draw, turbo:before-cache puts it at rest: drawn.
    cached = run_async(<<~JS)
      const sf = window.__sf, c = window.__storyFrame;
      sf.read(4);
      await sf.until(() => c.P === 4 && !c.anim);
      document.dispatchEvent(new Event("turbo:before-cache"));
      return window.__wheel();
    JS
    assert cached["grown"] && cached["tinted"] && cached["labels"], "at rest, drawn: #{cached}"
    refute cached["playing"], cached
    reconnect_frame(<<~JS)
      const real = window.matchMedia.bind(window);
      window.matchMedia = (q) => q.includes("prefers-reduced-motion: reduce")
        ? { matches: true, media: q, addEventListener() {}, removeEventListener() {}, addListener() {}, removeListener() {} }
        : real(q);
    JS
    page.execute_script(WHEEL)
    r = run_async(<<~JS)
      const sf = window.__sf, c = window.__storyFrame;
      sf.read(2);
      await sf.until(() => c.P === 2);
      sf.read(4);
      await sf.until(() => c.P === 4);
      return window.__wheel();
    JS
    assert r["grown"] && r["tinted"] && r["labels"], "complete the moment it shows: #{r}"
    refute r["playing"], r
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "without what the frame needs, the controller declines and the static faces show" do
    visit_at(1440, 900)
    assert_selector ".story.is-live", visible: :all
    reconnect_frame("window.ResizeObserver = undefined;", expect_log: "Story frame: this browser lacks")
    assert_nil page.evaluate_script("window.__storyFrame"), "the old controller is gone and the new one never ran"
    assert static_face_shown?(".face.f1"), "the hero's face shows"
    assert static_face_shown?(".face.f3"), "and every other face"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "a failure mid-move stops the frame for good: nothing pending, nothing re-armed, the faces and the page as they were" do
    # A phone-width window, where the live band sets scroll-padding-top.
    visit_at(500, 1000)
    assert_selector ".story.is-live", visible: :all
    live = frame_state
    refute_equal "", live["padding"], "live on a phone, the frame sets scroll-padding-top (the nav's): #{live}"
    r = run_async(<<~JS)
      const sf = window.__sf, c = window.__storyFrame;
      sf.read(1);
      await sf.until(() => c.P === 1 && !c.raf);
      sf.read(2);
      const moving = await sf.until(() => c.P >= 1.2 && c.P < 2 && !!c.raf);
      c.render = () => { throw new Error("test: render fails"); };
      const stopped = await sf.until(() => c.failed, 5000);
      sf.watch();
      scrollBy({ top: 300, behavior: "instant" });
      dispatchEvent(new Event("resize"));
      await sf.frames(5);
      return { moving, stopped, after: sf.state() };
    JS
    assert r["moving"], "caught mid-move: #{r}"
    assert r["stopped"], "the throw stopped it: #{r}"
    # A real resize too: nothing listens any more.
    page.driver.browser.manage.window.resize_to(500, 900)
    after = run_async("await window.__sf.frames(10); return window.__sf.state();")
    [ r["after"], after ].each do |s|
      refute s["live"], "the static faces show: #{s}"
      assert s["failed"], s
      assert_nil s["raf"], "no move pending: #{s}"
      assert_nil s["scrollFrame"], "no scroll frame pending: #{s}"
      assert_nil s["layoutFrame"], "no layout frame pending: #{s}"
      assert_equal "", s["padding"], "scroll-padding-top is as the page had it: #{s}"
      assert_equal 0, s["measures"], "nothing measured after the failure: #{s}"
    end
    assert static_face_shown?(".face.f3"), "every face shows"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  # Both layouts live: the step being shown stays current across the switch,
  # either way (a tablet turned, a window resized across 900px).
  test "crossing 900px keeps the current step" do
    visit_at(1440, 900)
    r = run_probe([ { read: 2, settle: "wide" } ])
    assert r["record"].last["settled"], r
    assert_equal 2, r["record"].last["P"], r
    # An iPad in portrait. The band (with the nav) takes about 490px at 820
    # wide, well inside the 56% a phone-width window may give it at this height.
    page.driver.browser.manage.window.resize_to(820, 1180)
    state = wait_for("the band below 900px") do
      s = frame_state
      s if s["width"] < 900 && s["stable"] == s["height"] && (s["pos"] == "sticky" || !s["live"]) && !s["raf"] && !s["layoutFrame"]
    end
    assert state["live"], "an 820px-wide window #{state['height']}px tall holds the band: #{state}"
    assert_equal "sticky", state["pos"], "the band below 900px: #{state}"
    assert_equal 2, state["P"], state
    assert_equal 2, state["target"], state
    # And back to wide.
    page.driver.browser.manage.window.resize_to(1440, 900)
    back = wait_for("the pinned frame again") do
      s = frame_state
      s if s["width"] >= 900 && s["pos"] != "sticky" && s["live"] && !s["raf"] && !s["layoutFrame"] && !s["scrollFrame"]
    end
    still = run_async("await window.__sf.frames(6); return window.__sf.state();")
    [ back, still ].each do |s|
      assert_equal 2, s["P"], "back on a wide window, still step 2: #{s}"
      assert_equal 2, s["target"], s
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "on a phone the frame is a band pinned under the nav and follows the same steps" do
    r = probe((1..4).map { |i| { read: i, settle: "step #{i}" } }, width: 500, height: 1000)
    assert_operator r["width"], :<, 900, "a phone-width window: #{r}"
    settled = r["record"].select { |s| s["at"].start_with?("step") }
    assert(settled.all? { |s| s["settled"] }, "each move reached its step: #{r}")
    assert_equal [ 1, 2, 3, 4 ], settled.map { |s| s["P"] }, r
    assert_operator r["bandTop"], :<, 140, "pinned near the top, under the nav: #{r}"
  end

  # A phone's toolbar collapsing and coming back changes innerHeight and fires
  # resize; the frame decides by the small viewport, which stays put. No
  # emulation: innerHeight is overridden in the page and resize dispatched.
  test "a phone's toolbar coming and going changes nothing: no switch, no measure, no log" do
    visit_at(500, 1000)
    assert_selector ".story.is-live", visible: :all
    r = run_async(<<~JS)
      const sf = window.__sf, c = window.__storyFrame, real = innerHeight;
      const own = Object.getOwnPropertyDescriptor(window, "innerHeight");
      sf.read(2);
      await sf.until(() => c.P === 2 && !c.raf);
      sf.watch();
      const before = sf.words(2);
      const states = [];
      for (const h of [ real + 84, real - 84, real + 84, real ]) {
        Object.defineProperty(window, "innerHeight", { configurable: true, get: () => h });
        dispatchEvent(new Event("resize"));
        await sf.frames(4);
        states.push({ h, ...sf.state() });
      }
      if (own) Object.defineProperty(window, "innerHeight", own); else delete window.innerHeight;
      return { real, before, after: sf.words(2), states };
    JS
    r["states"].each do |s|
      assert s["live"], "still live with innerHeight #{s['h']}: #{r}"
      assert_equal 0, s["measures"], "nothing measured: #{r}"
      assert_empty s["log"], "nothing logged: #{r}"
      assert_equal 2, s["P"], r
    end
    assert_equal r["before"], r["after"], "the words have not moved: #{r}"
  end

  # The decision by the stable height, overridden in the page: between the
  # two thresholds it stays as it is; past them it switches, and the step
  # being read stays in view either way.
  test "live and static switch with room to spare either way, keeping the step being read in view" do
    visit_at(500, 1000)
    assert_selector ".story.is-live", visible: :all
    r = run_async(<<~JS)
      const sf = window.__sf, c = window.__storyFrame;
      sf.read(2);
      await sf.until(() => c.P === 2 && !c.raf);
      const band = c.bandBottom(), out = [];
      // band / share: the height at which the band takes that share
      for (const [ share, label ] of [ [ 0.58, "between, live" ], [ 0.62, "too short" ], [ 0.58, "between, static" ], [ 0.54, "tall enough" ] ]) {
        const h = Math.round(band / share);
        c.stableHeight = () => h;
        dispatchEvent(new Event("resize"));
        await sf.frames(4);
        await sf.until(() => !c.layoutFrame && !c.raf);
        out.push({ label, h, live: sf.state().live, P: c.P, words: sf.words(2) });
      }
      return { band, out };
    JS
    assert_equal [ true, false, false, true ], r["out"].map { |s| s["live"] }, r
    r["out"].each do |s|
      w = s["words"]
      assert_operator w["top"], :>=, w["band"] - 1, "#{s['label']}: the step's words start below the nav and band: #{r}"
      assert_operator w["top"], :<, page.evaluate_script("innerHeight"), "#{s['label']}: and on screen: #{r}"
    end
    assert_equal 2, r["out"].last["P"], "the frame shows the step being read: #{r}"
  end

  test "a short wide window shows the static faces, and the frame comes back when it grows" do
    visit_at(1440, 480)
    short = frame_state
    refute short["live"], "a window #{short['width']}x#{short['height']} cannot hold the 400px frame below the nav: #{short}"
    assert static_face_shown?(".face.f1"), "the hero's face shows: #{short}"
    page.driver.browser.manage.window.resize_to(1440, 900)
    grown = wait_for("the frame to go live") { s = frame_state; s if s["live"] && !s["layoutFrame"] }
    assert_operator grown["height"], :>, short["height"], grown
    r = run_probe([ { read: 2, settle: "at 2" } ])
    assert r["record"].last["settled"], r
    pin = page.evaluate_script(<<~JS)
      ({ pin: Math.round(document.querySelector(".mm-pin").getBoundingClientRect().top),
         nav: Math.round(document.querySelector("body > nav, nav.fixed").getBoundingClientRect().bottom) })
    JS
    assert_operator pin["pin"], :>=, pin["nav"] + 8, "the pinned frame sits below the nav, never under it: #{pin}"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "a phone in landscape is too short for the band: the words and faces show" do
    visit_at(844, 390)
    state = frame_state
    refute state["live"], "the controller decided, and not to run: #{state}"
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

  # The longest hero title the frame takes (StoryFrameHelper: 44 characters)
  # beside the slide count, in a phone's band. Headless Chrome will not go
  # below 500px, so the band is narrowed in the page to the 351px it has in a
  # 375px window (measured); the bar's own CSS does the rest.
  test "a long deck title in the band's caption gives way to the slide count: no overlap, nothing outside the bar" do
    title = "The Long Road From Kentucky To The Highlands"
    assert_equal 44, title.length
    deck = Presentation.create!(author: users(:admin), title: title, content: "A story.", price: 9.99, category: "Bourbon", duration: "90 min")
    deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "s0.png", content_type: "image/png")
    deck.update_columns(published: true, featured: true)
    visit_at(375, 900)
    assert_selector ".story.is-live", visible: :all
    width = page.evaluate_script("innerWidth")
    page.execute_script("document.querySelector('.mm-pin').style.maxWidth = '351px'") if width > 400
    r = run_async(<<~JS)
      const sf = window.__sf, c = window.__storyFrame;
      await sf.until(() => document.querySelector(".mm-pin").offsetWidth <= 351 || innerWidth <= 400);
      await sf.frames(3);
      await sf.until(() => !c.layoutFrame);
      const rect = (el) => { const r = el.getBoundingClientRect(); return { left: Math.round(r.left), right: Math.round(r.right) }; };
      const l = document.querySelector("[data-mm=cap-l]"), rr = document.querySelector("[data-mm=cap-r]");
      const shown = (el) => [ ...el.querySelectorAll(".mm-rl") ].find((x) => getComputedStyle(x).visibility === "visible");
      const line = shown(l);
      return { width: innerWidth, P: c.P, bar: rect(document.querySelector(".mm-bar")), left: rect(l), line: rect(line), right: rect(rr),
               rightLine: rect(shown(rr)), text: line.textContent, cut: line.scrollWidth > line.clientWidth };
    JS
    assert_equal 0, r["P"], r
    assert_equal title, r["text"], "the hero's title, whole in the text: #{r}"
    assert r["cut"], "too long for the bar, so it is cut (with an ellipsis): #{r}"
    assert_operator r["line"]["right"], :<=, r["right"]["left"], "the title stops before the slide count: #{r}"
    assert_operator r["left"]["right"], :<=, r["right"]["left"], r
    [ r["left"], r["line"], r["right"], r["rightLine"] ].each do |box|
      assert_operator box["left"], :>=, r["bar"]["left"], "inside the bar: #{r}"
      assert_operator box["right"], :<=, r["bar"]["right"], "inside the bar: #{r}"
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  # Issue #51: a reader who gets well away from what the frame shows (here,
  # from the record straight to the top) is not shown every move backwards at
  # speed. The frame goes straight to their step and a still copy of the old
  # picture fades off it (JUMP_FADE, 0.3s); the record's wheel is reset, not
  # un-drawn. One step back at reading pace still plays its move in reverse.
  test "a fast scroll back from the record goes straight to the top with one short cross-fade" do
    visit_at(1440, 900)
    assert_selector ".story.is-live", visible: :all
    r = run_async(<<~JS)
      const sf = window.__sf, c = window.__storyFrame;
      for (const i of [ 1, 2, 3, 4 ]) { sf.read(i); await sf.until(() => c.P === i && !c.anim); }
      await sf.until(() => !c.raf);
      const atRecord = { P: c.P, w: c.w, end: c.wheelEnd };
      const t0 = performance.now(), seen = [];
      let ghosted = false;
      scrollTo({ top: 0, behavior: "instant" });
      while (performance.now() - t0 < 5000) {
        await sf.frames(1);
        const g = !!document.querySelector(".mm-ghost");
        ghosted = ghosted || g;
        seen.push({ t: Math.round(performance.now() - t0), P: +c.P.toFixed(3), w: c.w, ghost: g });
        if (c.P === 0 && !c.raf && !g) break;
      }
      const done = seen[seen.length - 1];
      sf.read(2);
      await sf.until(() => c.P === 2 && !c.raf);
      sf.read(1);
      const back = [];
      await sf.until(() => { back.push(+c.P.toFixed(3)); return c.P === 1 && !c.raf; });
      return { atRecord, ghosted, done, values: [ ...new Set(seen.map((s) => s.P)) ], back,
               ghostLeft: document.querySelectorAll(".mm-ghost").length, bar: document.querySelector(".mm-bar").style.opacity };
    JS
    assert_equal 4, r["atRecord"]["P"], r
    assert_equal r["atRecord"]["end"], r["atRecord"]["w"], "the wheel was drawn at the record: #{r}"
    assert r["ghosted"], "the old picture was laid over the new to fade: #{r}"
    assert_equal [ 0, 4 ], r["values"].sort, "only ever the record or the top, never a step in between: #{r}"
    assert_equal 0, r["done"]["P"], r
    assert_operator r["done"]["t"], :<, 1500, "the fade is short (0.3s; generous for a slow machine): #{r}"
    assert_equal 0, r["done"]["w"], "the wheel is reset, ready to draw again: #{r}"
    assert_equal 0, r["ghostLeft"], "the copy is gone: #{r}"
    assert_equal "", r["bar"], "the live caption is back at full: #{r}"
    assert(r["back"].any? { |p| p > 1 && p < 2 }, "one step back at reading pace still plays its move: #{r}")
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  # Issue #52: at the end of the story the glass stands on the card below it.
  test "at the end of the story the glass's foot stands on the spotlight card's top edge" do
    deck = Presentation.create!(author: users(:admin), title: "Spotlight Deck", content: "A story.", price: 9.99)
    deck.update_columns(published: true, featured: true)
    [ 1440, 1000 ].each do |width|
      visit_at(width, 900)
      assert_selector ".tile.spot"
      r = run_async(<<~JS)
        const sf = window.__sf, card = document.querySelector(".tile.spot");
        scrollTo({ top: card.getBoundingClientRect().top + scrollY - innerHeight / 2, behavior: "instant" });
        // wait on the card's reveal to finish, not on time
        await sf.until(() => getComputedStyle(card).transform === "none" && getComputedStyle(card).opacity === "1");
        await sf.frames(3);
        const svg = document.querySelector(".story-glass svg");
        const foot = [ ...svg.querySelectorAll("path") ].find((p) => p.getAttribute("d").startsWith("M25.5 61.5"));
        const scale = svg.getBoundingClientRect().height / 80;
        return { width: innerWidth, foot: foot.getBoundingClientRect().bottom + (parseFloat(foot.getAttribute("stroke-width")) / 2) * scale,
                 card: card.getBoundingClientRect().top, position: getComputedStyle(document.querySelector(".story-glass")).position };
      JS
      assert_operator r["width"], :>=, 900, r
      assert_equal "sticky", r["position"], r
      assert_in_delta r["card"], r["foot"], 0.6, "flush on the card's top edge at #{r['width']}px: #{r}"
    end
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  # Issue #44: the band covers only the story, so only the story's own
  # elements keep clear of it; a link to the rest of the page lands its
  # heading just under the nav.
  test "on a phone a link to #pricing lands its heading just under the nav, and the story's own link still clears the band" do
    page.driver.browser.manage.window.resize_to(500, 1000)
    visit "#{root_path}#pricing"
    wait_for_frame_connected
    assert_selector ".story.is-live", visible: :all
    r = run_async(<<~JS)
      const sf = window.__sf, c = window.__storyFrame;
      const still = async () => { let last = -1, same = 0; await sf.until(() => { same = scrollY === last ? same + 1 : 0; last = scrollY; return same > 8; }); };
      const nav = () => Math.round(document.querySelector("body > nav, nav.fixed").getBoundingClientRect().bottom);
      const heading = () => Math.round(document.querySelector("#pricing h2").getBoundingClientRect().top);
      await sf.until(() => !c.layoutFrame && !c.scrollFrame);
      await still();
      const loaded = heading();
      scrollTo({ top: 0, behavior: "instant" });
      await sf.frames(2);
      const a = document.createElement("a");
      a.href = "#pricing"; a.textContent = "Pricing";
      document.querySelector(".hx").prepend(a);
      a.click();
      await still();
      const clicked = heading();
      a.remove();
      scrollTo({ top: 0, behavior: "instant" });
      await sf.frames(2);
      document.querySelector('a[href="#how-it-works"]').click();
      await still();
      const story = { words: Math.round(document.querySelector("#how-it-works .beat-body").getBoundingClientRect().top),
                      band: Math.round(document.querySelector(".mm").getBoundingClientRect().bottom) };
      return { width: innerWidth, nav: nav(), loaded, clicked, story, padding: document.documentElement.style.scrollPaddingTop };
    JS
    assert_operator r["width"], :<, 900, r
    [ r["loaded"], r["clicked"] ].each do |top|
      assert_operator top, :>=, r["nav"], "the heading is not under the nav: #{r}"
      assert_operator top, :<=, r["nav"] + 120, "it is just under it, not below a band that has scrolled away: #{r}"
    end
    assert_operator r["story"]["words"], :>=, r["story"]["band"], "the story's own link still clears the band: #{r}"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  # Issue #45: growing a short wide window re-lays the svh heights before the
  # controller runs; the words the reader was reading go back where they were.
  test "growing a short wide window keeps the words being read where they were, and their step" do
    visit_at(1440, 480)
    refute frame_state["live"], frame_state
    # Measured by layout (the offsetTop chain), as the controller does: the
    # words' reveal rises a few pixels by transform while it plays.
    top = "(() => { let y = 0; for (let e = document.querySelector('.b3 .beat-body'); e; e = e.offsetParent) y += e.offsetTop; return Math.round(y - scrollY); })()"
    before = run_async(<<~JS)
      const sf = window.__sf;
      scrollTo({ top: scrollY + #{top} - 120, behavior: "instant" });
      await sf.frames(4);
      return #{top};
    JS
    page.driver.browser.manage.window.resize_to(1440, 900)
    wait_for("the frame to go live") { s = frame_state; s if s["live"] && !s["layoutFrame"] && !s["scrollFrame"] }
    after = run_async(<<~JS)
      const sf = window.__sf, c = window.__storyFrame;
      await sf.until(() => c.P === c.target && !c.raf);
      return { top: #{top}, P: c.P, target: c.target };
    JS
    assert_in_delta before, after["top"], 2, "the words stay where the reader saw them: before #{before}, after #{after}"
    assert_equal 2, after["target"], "and the frame shows their step: #{after}"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
