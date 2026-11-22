# Failure diagnostics for system tests.
#
# A system test that fails only on CI leaves a screenshot and an assertion
# message, which cannot tell "the click never reached the page" from "the click
# worked and something undid it". This records a timeline in the browser and
# prints it (and writes it next to the failure screenshot, which CI uploads)
# when a test fails:
#
# - in the page: document start, DOMContentLoaded, load, first paint, Turbo
#   visits and renders, view transitions, pagereveal/pageswap, pointerdown and
#   click (with target and whether the default was prevented), hash changes,
#   Stimulus readiness markers (data-*-ready) and aria-selected changes, page
#   errors and console.error;
# - from Ruby: each element click Capybara sends, with its wall-clock time, so
#   it can be lined up with the page's own events.
#
# Times are wall-clock milliseconds (Date.now in the page, realtime in Ruby).
# The timeline lives in sessionStorage, so it survives full page loads within
# the test. Nothing here changes what a test does or waits for.
module SystemTestTimeline
  STORAGE_KEY = "__system_test_timeline"
  MAX_ENTRIES = 400

  PROBE = <<~JS.freeze
    (function () {
      if (window.__systemTestTimeline) return;
      window.__systemTestTimeline = true;
      const key = #{STORAGE_KEY.to_json};
      const log = (message) => {
        try {
          const entries = JSON.parse(sessionStorage.getItem(key) || "[]");
          entries.push(Date.now() + " " + location.pathname + location.hash + " " + message);
          sessionStorage.setItem(key, JSON.stringify(entries.slice(-#{MAX_ENTRIES})));
        } catch (e) {}
      };
      const describe = (node) => {
        if (!node || !node.closest) return String(node && node.nodeName);
        const tab = node.closest("[data-tab]");
        if (tab) return "[data-tab=" + tab.dataset.tab + "]";
        return node.nodeName.toLowerCase() + (node.id ? "#" + node.id : "");
      };

      log("document start (" + document.readyState + ")");
      document.addEventListener("DOMContentLoaded", () => log("DOMContentLoaded"));
      window.addEventListener("load", () => log("load"));
      window.addEventListener("pagereveal", (e) => log("pagereveal viewTransition=" + !!e.viewTransition));
      window.addEventListener("pageswap", (e) => log("pageswap viewTransition=" + !!e.viewTransition));
      window.addEventListener("pagehide", () => log("pagehide"));
      window.addEventListener("hashchange", () => log("hashchange"));
      window.addEventListener("popstate", () => log("popstate"));
      window.addEventListener("error", (e) => log("error " + e.message));
      window.addEventListener("unhandledrejection", (e) => log("unhandledrejection " + (e.reason && e.reason.message || e.reason)));
      document.addEventListener("visibilitychange", () => log("visibility " + document.visibilityState));
      try {
        new PerformanceObserver((list) => list.getEntries().forEach((e) => log("paint " + e.name)))
          .observe({ type: "paint", buffered: true });
      } catch (e) {}

      ["turbo:visit", "turbo:before-render", "turbo:render", "turbo:load", "turbo:reload",
       "turbo:submit-start", "turbo:submit-end", "turbo:before-cache", "turbo:morph"].forEach((name) =>
        document.addEventListener(name, (e) => log(name + (e.detail && e.detail.url ? " " + e.detail.url : "") + (e.detail && e.detail.reason ? " " + e.detail.reason : ""))));

      ["pointerdown", "click"].forEach((type) => {
        document.addEventListener(type, (e) => log(type + " " + describe(e.target) + " at " + e.clientX + "," + e.clientY), true);
      });
      window.addEventListener("click", (e) => log("click reached window, defaultPrevented=" + e.defaultPrevented));

      if (document.startViewTransition) {
        const start = document.startViewTransition.bind(document);
        document.startViewTransition = function (...args) {
          log("view transition start");
          const transition = start(...args);
          transition.finished.then(() => log("view transition finished"), () => log("view transition skipped"));
          return transition;
        };
      }

      const consoleError = console.error;
      console.error = function (...args) {
        log("console.error " + args.map(String).join(" "));
        return consoleError.apply(this, args);
      };

      new MutationObserver((mutations) => {
        mutations.forEach((m) => {
          if (m.type !== "attributes") return;
          if (/^data-.*-ready$/.test(m.attributeName)) {
            log(m.attributeName + "=" + m.target.getAttribute(m.attributeName) + " on " + describe(m.target));
          } else if (m.attributeName === "aria-selected" && m.target.getAttribute("aria-selected") === "true") {
            log("aria-selected " + describe(m.target));
          }
        });
      }).observe(document, { attributes: true, subtree: true });
    })();
  JS

  STATE = <<~JS.freeze
    (function () {
      const tabs = Array.from(document.querySelectorAll("[data-tab]"))
        .map((t) => t.dataset.tab + ":" + t.getAttribute("aria-selected")).join(" ");
      return {
        url: location.href,
        readyState: document.readyState,
        visibility: document.visibilityState,
        hasFocus: document.hasFocus(),
        paints: performance.getEntriesByType("paint").map((e) => e.name + "@" + Math.round(performance.timeOrigin + e.startTime)),
        tabs: tabs,
        timeline: JSON.parse(sessionStorage.getItem(#{STORAGE_KEY.to_json}) || "[]")
      };
    })()
  JS

  # Records the Ruby side of each click, timed just before it is sent.
  module ClickLog
    def click(*args, **options)
      sent_at = SystemTestTimeline.now_ms
      super.tap do
        SystemTestTimeline.ruby_events << "#{sent_at} ruby click sent (returned at #{SystemTestTimeline.now_ms})"
      end
    end
  end

  def self.now_ms = Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
  def self.ruby_events = (@ruby_events ||= [])

  def before_setup
    super
    SystemTestTimeline.ruby_events.clear
    install_timeline_probe
  end

  def before_teardown
    dump_timeline unless passed? || skipped?
    clear_timeline
    super
  end

  private

  def chrome_browser
    browser = page.driver.browser
    browser if browser.respond_to?(:execute_cdp)
  rescue StandardError
    nil
  end

  # Registered once per browser: Capybara reuses the browser across tests and
  # the CDP registration persists for every later document.
  def install_timeline_probe
    browser = chrome_browser or return
    return if browser.instance_variable_get(:@system_test_timeline)

    browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: PROBE)
    browser.instance_variable_set(:@system_test_timeline, true)
  rescue StandardError => e
    warn "System test timeline not installed: #{e.class}: #{e.message}"
  end

  def clear_timeline
    page.execute_script("try { sessionStorage.removeItem(#{STORAGE_KEY.to_json}) } catch (e) {}") if chrome_browser
  rescue StandardError
    nil
  end

  def dump_timeline
    return unless chrome_browser

    state = page.evaluate_script(STATE)
    lines = [ "--- System test timeline: #{self.class.name}##{name} ---" ]
    lines << "url=#{state["url"]} readyState=#{state["readyState"]} visibility=#{state["visibility"]} hasFocus=#{state["hasFocus"]}"
    lines << "paints: #{Array(state["paints"]).join(", ")}"
    lines << "tabs: #{state["tabs"]}" if state["tabs"].present?
    lines.concat((Array(state["timeline"]) + SystemTestTimeline.ruby_events).sort_by(&:to_i))
    lines << "--- end timeline ---"
    report = lines.join("\n")

    puts "\n#{report}"
    dir = Rails.root.join("tmp/screenshots")
    FileUtils.mkdir_p(dir)
    File.write(dir.join("failures_#{name}.timeline.txt"), report)
  rescue StandardError => e
    warn "System test timeline not captured: #{e.class}: #{e.message}"
  end
end

Capybara::Selenium::Node.prepend(SystemTestTimeline::ClickLog)
