require "test_helper"
require "rake"

# `rake scrub:emdashes`: em-dashes out of deck text, the extra sections'
# headings and lines included. Dry run unless APPLY=1.
class ScrubEmdashesTaskTest < ActiveSupport::TestCase
  EMDASH = "—"

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("scrub:emdashes")
    Rake::Task["scrub:emdashes"].reenable
    @deck = Presentation.create!(author: users(:admin), title: "Scrub Deck", content: "A story.", price: 5,
                                 nose_notes: "Pear #{EMDASH} oak",
                                 sections: [ { "heading" => "On the night #{EMDASH} two glasses",
                                               "lines" => [ "Glass A #{EMDASH} first", "Glass B: later" ] } ])
  end

  teardown { ENV.delete("APPLY") }

  test "a dry run changes nothing" do
    capture_io { Rake::Task["scrub:emdashes"].invoke }
    assert_includes @deck.reload.sections.first["heading"], EMDASH
  end

  test "APPLY=1 scrubs the sections' headings and lines, and the old columns" do
    ENV["APPLY"] = "1"
    capture_io { Rake::Task["scrub:emdashes"].invoke }
    @deck.reload
    assert_equal [ { "heading" => "On the night, two glasses", "lines" => [ "Glass A, first", "Glass B: later" ] } ],
                 @deck.sections
    assert_equal "Pear, oak", @deck.nose_notes
  end
end
