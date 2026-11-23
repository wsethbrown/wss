require "application_system_test_case"

# Issue #46 in a real browser. The CSP in force is the one from the
# document's first response; a Turbo Drive visit parses the next page and
# copies its head under that policy, so an inline <style> on the next page
# (with its own request's nonce, or none) is reported now and would be
# blocked once the policy is enforced. The homepage and the layout now send
# their CSS as stylesheets from this site, so reaching the homepage by a
# Turbo link must report no style element at all. (Inline style="" attributes
# are a separate, known item: CSP_REPORT_ONLY.md row 9.)
class CspTurboStylesSystemTest < ApplicationSystemTestCase
  test "reaching the homepage by a Turbo link reports no style-src-elem violation" do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    visit membership_path
    assert_selector "a[href='/']", minimum: 1

    # A Turbo visit keeps this document, so the marker and the listener
    # survive it; a full page load would drop both.
    page.execute_script(<<~JS)
      window.__turboVisit = true;
      window.__cspViolations = [];
      document.addEventListener("securitypolicyviolation", (e) => {
        window.__cspViolations.push(`${e.effectiveDirective} ${e.sourceFile || ""}:${e.lineNumber}`);
      });
    JS

    first("a[href='/']").click
    assert_current_path root_path
    assert_selector ".hx .story[data-controller~=story-frame]"
    assert_selector "link[rel=stylesheet][href*='/home/index-']", visible: :all

    assert_equal true, page.evaluate_script("window.__turboVisit"), "the homepage was reached by Turbo, not a full page load"
    violations = page.evaluate_script("window.__cspViolations")
    styles = violations.select { |v| v.start_with?("style-src-elem") }
    assert_empty styles, "style elements reported on a Turbo visit to the homepage: #{styles}"
    # Turbo's own progress-bar <style> (nonced from the first page's meta) is
    # the only style element the document may hold.
    others = page.evaluate_script("[...document.querySelectorAll('style')].filter((s) => !s.textContent.includes('.turbo-progress-bar')).length")
    assert_equal 0, others, "no page <style> element reached the document"
  end
end
