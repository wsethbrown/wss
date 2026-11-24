require "test_helper"

# No accidental free decks: a deck goes live at $0 only when an admin says it
# is free on purpose (free_confirmed). Free decks themselves stay possible.
class PresentationFreePublishTest < ActiveSupport::TestCase
  setup do
    @deck = Presentation.create!(author: users(:admin), title: "Price Check", content: "Story.", price: 0)
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 deck"), filename: "deck.pdf", content_type: "application/pdf")
    @deck.slide_images.attach(io: File.open(Rails.root.join("test/fixtures/files/slides/slide-01.png"), "rb"),
                              filename: "slide-01.png", content_type: "image/png")
  end

  test "publishing at $0 without confirmation is refused with a clear message" do
    assert_not @deck.update(published: true)
    assert_match(/This deck is free/, @deck.errors.full_messages.to_sentence)
    assert_not @deck.reload.published?
  end

  test "publishing at $0 with confirmation works" do
    @deck.free_confirmed = true
    assert @deck.update(published: true)
  end

  test "publishing with a price needs no confirmation" do
    assert @deck.update(published: true, price: 9.99)
  end

  test "dropping a live deck's price to $0 needs the confirmation too" do
    @deck.update!(published: true, price: 9.99)
    assert_not @deck.update(price: 0)
    @deck.free_confirmed = "1"
    assert @deck.update(price: 0)
  end

  test "an already-live free deck can still be edited without the box" do
    @deck.free_confirmed = true
    @deck.update!(published: true)
    deck = Presentation.find(@deck.id)
    assert deck.update(description: "Edited.")
  end
end
