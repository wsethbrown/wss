require "test_helper"
require "rake"
require_relative "../support/deck_package_fixture"

# `rake decks:load DIR=... [DECK_ID=...]`: with DECK_ID the package goes into
# that deck, whatever its title, exactly as the admin's "Replace with a package".
class DecksLoadTaskTest < ActiveSupport::TestCase
  include DeckPackageFixture

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("decks:load")
    Rake::Task["decks:load"].reenable
    @dir = build_deck_package(Dir.mktmpdir("decks-load"))
  end

  teardown do
    FileUtils.remove_entry(@dir)
    %w[DIR DECK_ID PUBLISH].each { |key| ENV.delete(key) }
  end

  test "DECK_ID loads the package into that deck, whatever its title" do
    deck = Presentation.create!(author: users(:admin), title: "Named Differently", content: "Old.", price: 30)
    ENV["DIR"] = @dir
    ENV["DECK_ID"] = deck.id.to_s

    out, = capture_io do
      assert_no_difference -> { Presentation.count } do
        Rake::Task["decks:load"].invoke
      end
    end

    assert_equal "Test Deck", deck.reload.title
    assert_equal BigDecimal("30"), deck.price
    assert_includes out, "Test Deck"
  end

  test "without DECK_ID it still matches by title" do
    ENV["DIR"] = @dir
    capture_io { Rake::Task["decks:load"].invoke }
    assert Presentation.find_by(title: "Test Deck")
  end
end
