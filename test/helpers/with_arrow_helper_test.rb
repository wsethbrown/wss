require "test_helper"

# with_arrow puts a link's arrow in its own span so it can nudge on hover,
# without changing what the link says or letting markup through.
class WithArrowHelperTest < ActionView::TestCase
  include DesignHelper

  def fragment(html)
    Nokogiri::HTML5.fragment(html.to_s)
  end

  test "the text reads exactly as the words and the arrow" do
    assert_equal "See all →", fragment(with_arrow("See all")).text
  end

  test "the arrow is its own span" do
    span = fragment(with_arrow("See all")).at_css("span.arrow")
    assert span
    assert_equal "→", span.text
  end

  test "the words are escaped, never rendered as markup" do
    html = with_arrow("<b>x</b>")
    assert html.html_safe?
    assert_includes html, "&lt;b&gt;x&lt;/b&gt;"
    assert_nil fragment(html).at_css("b")
    assert_equal "<b>x</b> →", fragment(html).text
  end

  test "inside a link the accessible text is unchanged" do
    link = fragment(link_to(with_arrow("See the night"), "/x")).at_css("a")
    assert_equal "See the night →", link.text
  end
end
