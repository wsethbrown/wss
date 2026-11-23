require "test_helper"

# Issue #46 (docs/redesign/CSP_REPORT_ONLY.md, rows 2 and 6). An inline
# <style> block is allowed only with the request's nonce, and the policy in
# force is the one from the document's first response. A Turbo Drive visit
# parses the next page under that first policy, so the next page's
# <style nonce> (another request's nonce) is reported now and would be
# blocked once the policy is enforced; a <style> with no nonce is reported on
# every load. So these pages send no <style> element at all: their CSS is in
# stylesheets served from this site ('self'), which no nonce is needed for.
class CspInlineStylesTest < ActionDispatch::IntegrationTest
  def deck_with_slides(title, slides:, preview:)
    deck = Presentation.create!(author: users(:admin), title: title, content: "Smoke.", price: 10, featured: true, preview_slide_count: preview)
    slides.times { |n| deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "s#{n}.png", content_type: "image/png") }
    deck.update_column(:published, true)
    deck
  end

  def linked_stylesheets
    css_select("link[rel=stylesheet]").map { |l| l["href"] }.select { |h| h.start_with?("/assets/") }
  end

  def assert_no_style_elements(where)
    styles = css_select("style")
    assert_empty styles, "#{where} sends #{styles.size} <style> element(s); a Turbo visit would report them: #{styles.map { |s| s.text.strip[0, 60] }}"
    assert_no_match(/<style[\s>]/i, response.body, "#{where}: no <style> anywhere in the markup")
  end

  test "the homepage sends no <style> element, with or without a reel, and links its three stylesheets" do
    get root_path
    assert_response :success
    assert_no_style_elements("the homepage")

    deck_with_slides("Reel Deck", slides: 5, preview: 3)
    get root_path
    assert_select ".f1 .reel img", 3
    assert_no_style_elements("the homepage with a reel of three")

    %w[home/index home/story_frame home/story_glass].each do |name|
      assert linked_stylesheets.any? { |h| h.match?(%r{\A/assets/#{name}-\h{8}\.css\z}) }, "the homepage links #{name}.css: #{linked_stylesheets}"
    end
  end

  test "a one-slide reel sends no <style> element either" do
    deck_with_slides("One Slide", slides: 1, preview: 3)
    get root_path
    assert_select ".f1 .reel img", 1
    assert_no_style_elements("the homepage with a one-slide reel")
  end

  test "every stylesheet the homepage links is served from this site as CSS" do
    get root_path
    hrefs = linked_stylesheets
    assert hrefs.any?
    hrefs.each do |href|
      get href
      assert_response :success, href
      assert_match %r{\Atext/css}, response.media_type, href
    end
  end

  test "the layout sends no <style> element on any page" do
    [ membership_path, contact_path, presentations_path, societies_path, reviews_path, auth_path ].each do |path|
      get path
      assert_response :success, path
      assert_no_style_elements(path)
      assert linked_stylesheets.any? { |h| h.match?(%r{\A/assets/layout-\h{8}\.css\z}) }, "#{path} links layout.css"
    end
  end

  test "present mode sends no <style> element and links its stylesheet" do
    deck = deck_with_slides("Present Deck", slides: 2, preview: 1)
    sign_in users(:admin)
    get present_presentation_path(deck)
    assert_response :success
    assert_no_style_elements("present mode")
    assert linked_stylesheets.any? { |h| h.match?(%r{\A/assets/present-\h{8}\.css\z}) }, "present mode links present.css"
    css = page_css
    assert_match(/\.slide\.active \{ display: flex; \}/, css)
    assert_match(/html, body \{[^}]*overflow: hidden;/, css)
  end

  # The fix must not be a weaker policy: still report-only, still no
  # 'unsafe-inline' for styles, and a per-request nonce still in style-src.
  test "the policy is unchanged: report-only, no unsafe-inline, a nonce per request" do
    get root_path
    assert_nil response.headers["Content-Security-Policy"], "the policy is not enforced"
    policy = response.headers["Content-Security-Policy-Report-Only"]
    assert policy, "the report-only header is sent"
    style_src = policy[/style-src ([^;]*)/, 1]
    assert style_src, policy
    refute_includes style_src, "'unsafe-inline'"
    first = style_src[/'nonce-([^']+)'/, 1]
    get root_path
    second = response.headers["Content-Security-Policy-Report-Only"][/style-src [^;]*'nonce-([^']+)'/, 1]
    assert first && second
    refute_equal first, second, "the nonce is still fresh per request"
  end
end
