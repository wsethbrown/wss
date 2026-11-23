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

  # No viewport emulation anywhere in this file: Capybara reuses one browser
  # tab across tests, and a CDP device-metrics override (used here briefly)
  # leaked between tests. The window is resized before the visit and put
  # back in ensure.
  #
  # The rule under test (owner: motion "shouldn't load until it settles into
  # place"): a face's motion starts when the face has settled, meaning it sits
  # at its pinned top, or the page can scroll no further, or the reader has
  # stopped with the face (nearly) all in view; never while it is still
  # sliding up from the bottom edge. The scripted scroll reads the closing
  # beat's position live every frame (a figure taken once at the start went
  # stale on CI as the layout settled, ending the scroll with the last face
  # still half way up), and runs until that beat is mid-screen or the page
  # ends. Faces are sticky only from 900px up, so the layout is checked first,
  # and every failure prints what the page looked like.
  test "on a wide screen a face's motion waits until the face has settled" do
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit root_path
    assert_selector ".f3 .screen.perform-wait", visible: :all
    layout = page.evaluate_script(<<~JS)
      ({ width: window.innerWidth, height: window.innerHeight,
         sticky: [ "f2", "f3", "f4" ].map((f) => getComputedStyle(document.querySelector(`.${f}`)).position) })
    JS
    assert_operator layout["width"], :>=, 900, "the faces only pin from 900px up: #{layout}"
    assert_equal %w[sticky sticky sticky], layout["sticky"], "the faces must be sticky to test pinning: #{layout}"

    # Scroll at a reading pace and note where each face was when it started.
    page.execute_script(<<~JS)
      window.__starts = {};
      window.__done = false;
      window.__scrolls = 0;
      window.addEventListener("scroll", () => { window.__scrolls++ }, { passive: true });
      (() => {
        let y = scrollY, prev = performance.now(), lastMove = performance.now();
        const step = (now) => {
          // Cap the step so a slow frame on CI cannot jump a face past its pinned stretch.
          y += 400 * Math.min(now - prev, 40) / 1000; prev = now;
          const before = scrollY; scrollTo({ top: y, behavior: "instant" }); if (scrollY !== before) lastMove = now;
          const maxScroll = document.documentElement.scrollHeight - innerHeight;
          for (const f of [ "f2", "f3", "f4" ]) {
            const screen = document.querySelector(`.${f} .screen`);
            if (!(f in window.__starts) && screen.classList.contains("perform-run")) {
              const face = screen.closest(".face");
              const rect = face.getBoundingClientRect();
              window.__starts[f] = { offset: Math.round(rect.top - parseFloat(getComputedStyle(face).top)),
                                     top: Math.round(rect.top), bottom: Math.round(rect.bottom), pinned: getComputedStyle(face).top,
                                     inView: (Math.min(rect.bottom, innerHeight) - Math.max(rect.top, 0)) / rect.height,
                                     atEnd: scrollY >= maxScroll - 1, stillMs: Math.round(now - lastMove) };
            }
          }
          const close = document.querySelector(".beat--close").getBoundingClientRect();
          const finished = close.top + close.height / 2 <= innerHeight / 2 || scrollY >= maxScroll - 1;
          if (!finished) requestAnimationFrame(step); else window.__done = true;
        };
        requestAnimationFrame(step);
      })();
    JS
    Timeout.timeout(90) { sleep 0.1 until page.evaluate_script("window.__done") }
    report = page.evaluate_script(<<~JS)
      ({ starts: window.__starts, width: window.innerWidth, height: window.innerHeight, scrollEvents: window.__scrolls,
         scrollY: Math.round(window.scrollY),
         players: Object.fromEntries([ "f2", "f3", "f4" ].map((f) => [ f, document.querySelector(`.${f} .player`).className ])),
         screens: Object.fromEntries([ "f2", "f3", "f4" ].map((f) => [ f, document.querySelector(`.${f} .screen`).className ])),
         faceTops: Object.fromEntries([ "f2", "f3", "f4" ].map((f) => [ f, Math.round(document.querySelector(`.${f}`).getBoundingClientRect().top) ])) })
    JS
    %w[f2 f3 f4].each do |f|
      start = report["starts"][f]
      assert start, "#{f} never had perform-run while scrolling: #{report}"
      assert start["offset"].is_a?(Numeric), "#{f}'s start could not be measured: #{report}"
      pinned = start["offset"].abs <= 1
      settled_short = start["atEnd"] || (start["inView"] >= 0.9 && start["stillMs"] >= 100)
      assert pinned || settled_short, "#{f} started while still travelling (#{start['offset']}px from its pinned spot, " \
                                      "#{(start['inView'] * 100).round}% in view): #{report}"
    end
    assert_no_selector BUSY, visible: :all, wait: 5
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "an RSVP re-pours the table and ends at the true level" do
    user = User.create!(email: "repour-system@example.com", password: "password123", password_confirmation: "password123", first_name: "Re", last_name: "Pour")
    event = events(:mystery_flight)
    SocietyMembership.create!(user: user, society: event.society, role: "member", status: "active")
    visit_sign_in_page
    fill_in "magic-link-email", with: user.email
    find("#password-toggle").click
    fill_in "signin-password", with: "password123"
    within("#password-signin") { click_button "Sign in" }
    assert_link "Sign out"
    assert_no_selector "html[aria-busy='true']", visible: :all

    visit event_path(event)
    assert_selector "[data-role=the-table][data-repour] svg[data-glass]", visible: :all
    page.execute_script("document.querySelector('[data-repour]').scrollIntoView({ block: 'center', behavior: 'instant' })")
    before = page.evaluate_script("[...document.querySelectorAll('[data-repour] svg[data-glass]')].map((g) => g.dataset.glass)")
    find("button.rsvp-option[data-answer=yes]").click
    assert_selector "[data-repour] svg[data-glass]", visible: :all, wait: 5
    Timeout.timeout(5) { sleep 0.05 until page.evaluate_script("[...document.querySelectorAll('[data-repour] svg[data-glass]')].map((g) => g.dataset.glass)") != before }
    sleep 0.8 # the 500ms re-pour has run
    state = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("[data-repour] svg[data-glass]")].map((g) => ({
        animating: [...g.querySelectorAll("g > path")].some((p) => p.getAnimations().length),
        paths: g.querySelectorAll("g > path").length,
        moved: [...g.querySelectorAll("g > path")].some((p) => getComputedStyle(p).transform !== "none")
      }))
    JS
    state.each do |glass|
      refute glass["animating"], "the re-pour has finished"
      refute glass["moved"], "every liquid sits at its drawn level"
      assert_includes [ 0, 2 ], glass["paths"], "no helper copy of the body is left behind"
    end
  end

  # The fade logic, without touching the viewport. On a wide screen the deck
  # filter rows wrap or fit (md: classes), so the test narrows one row in
  # place: inline styles make it a 300px sideways-scrolling row, exactly what
  # a phone gets, and the controller's ResizeObserver picks the change up.
  # (Neither the controller nor the mask CSS is tied to a media query; only
  # the row's own overflow classes are.) The row gets real content from a few
  # long-named decks, because CI's fixtures give the filters almost nothing.
  test "a sideways row fades at the edge with more to scroll" do
    3.times do |i|
      deck = Presentation.create!(author: users(:admin), title: "Scroll Row Deck #{i}", content: "Smoke.", price: 10,
                                  category: "A long category name for scrolling #{i}", difficulty: %w[Beginner Intermediate Advanced][i])
      deck.update_column(:published, true)
    end
    visit presentations_path
    row = "#deck-filters .scroll-row"
    assert_selector "#{row}[data-controller~=scroll-fade]", visible: :all
    assert_no_selector "#{row}[data-more-start], #{row}[data-more-end]", visible: :all, wait: 2 # it fits: no fade
    page.execute_script(<<~JS)
      const r = document.querySelector("#{row}");
      Object.assign(r.style, { width: "300px", flex: "none", overflowX: "auto", flexWrap: "nowrap", marginLeft: "0", marginRight: "0" });
    JS
    sizes = page.evaluate_script("(() => { const r = document.querySelector('#{row}'); return [r.scrollWidth, r.clientWidth]; })()")
    assert_operator sizes[0], :>, sizes[1], "the narrowed row must overflow for this test to mean anything (scrollWidth #{sizes[0]}, clientWidth #{sizes[1]})"
    assert_selector "#{row}[data-more-end]", visible: :all, wait: 3
    assert_no_selector "#{row}[data-more-start]", visible: :all
    page.execute_script("document.querySelector('#{row}').scrollTo({ left: 60, behavior: 'instant' })")
    assert_selector "#{row}[data-more-start][data-more-end]", visible: :all, wait: 2
    page.execute_script("const r = document.querySelector('#{row}'); r.scrollTo({ left: r.scrollWidth, behavior: 'instant' })")
    assert_selector "#{row}[data-more-start]:not([data-more-end])", visible: :all, wait: 2
    mask = page.evaluate_script("(() => { const s = getComputedStyle(document.querySelector('#{row}')); return s.maskImage || s.webkitMaskImage; })()")
    assert_match(/linear-gradient/, mask.to_s, "the fade is drawn")
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
