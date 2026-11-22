require "test_helper"

# The deck's subtitle: one optional line under the title on the deck page.
class PresentationSubtitleTest < ActiveSupport::TestCase
  def deck(**attrs)
    Presentation.new(author: users(:admin), title: "Subtitle Deck", content: "A story.", price: 5, **attrs)
  end

  test "it is stripped, and blank becomes nil" do
    assert_equal "Cocktails, Chapter One", deck(subtitle: "  Cocktails, Chapter One \n").subtitle
    assert_nil deck(subtitle: "   ").subtitle
    assert_nil deck(subtitle: "").subtitle
    assert_nil deck.subtitle
  end

  test "at most 140 characters, with a plain-language error" do
    assert deck(subtitle: "s" * 140).valid?
    d = deck(subtitle: "s" * 141)
    assert_not d.valid?
    assert_includes d.errors.full_messages, "Subtitle can be at most 140 characters"
  end
end
