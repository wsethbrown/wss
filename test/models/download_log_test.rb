require "test_helper"

class DownloadLogTest < ActiveSupport::TestCase
  setup do
    @deck = Presentation.create!(author: users(:admin), title: "Log Deck", content: "Story.", price: 15)
  end

  DownloadLog::FILE_TYPES.each do |type|
    test "#{type} is a valid file type" do
      log = DownloadLog.new(user: users(:john), presentation: @deck, file_type: type, downloaded_at: Time.current)
      assert log.valid?, log.errors.full_messages.to_sentence
    end
  end

  test "covers every type the downloads controller records" do
    recorded = File.read(Rails.root.join("app/controllers/presentations/downloads_controller.rb"))
                   .scan(/track_download\("(\w+)"\)/).flatten.uniq
    assert_empty recorded - DownloadLog::FILE_TYPES
  end

  test "an unknown file type is invalid" do
    log = DownloadLog.new(user: users(:john), presentation: @deck, file_type: "bogus", downloaded_at: Time.current)
    assert_not log.valid?
  end
end
