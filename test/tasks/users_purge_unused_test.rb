require "test_helper"
require "rake"

# `rake users:purge_unused`: dry run by default, CONFIRM=1 deletes.
class UsersPurgeUnusedTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("users:purge_unused")
    Rake::Task["users:purge_unused"].reenable
    @junk = User.create!(email: "rake.junk@business.example", password: SecureRandom.alphanumeric(24))
    @junk.update_columns(created_at: Time.utc(2026, 9, 2))
  end

  teardown { %w[CONFIRM CREATED_AFTER CREATED_BEFORE].each { |k| ENV.delete(k) } }

  test "without CONFIRM it only reports" do
    out, = capture_io { Rake::Task["users:purge_unused"].invoke }
    assert User.exists?(@junk.id)
    assert_includes out, "user #{@junk.id}, created 2026-09-02"
    assert_no_match(/@/, out)
  end

  test "CONFIRM=1 deletes, and the date range narrows" do
    ENV["CONFIRM"] = "1"
    ENV["CREATED_AFTER"] = "2026-10-01"
    capture_io { Rake::Task["users:purge_unused"].invoke }
    assert User.exists?(@junk.id), "outside the range: kept"

    Rake::Task["users:purge_unused"].reenable
    ENV["CREATED_AFTER"] = "2026-09-01"
    ENV["CREATED_BEFORE"] = "2026-09-03"
    out, = capture_io { Rake::Task["users:purge_unused"].invoke }
    assert_not User.exists?(@junk.id)
    assert_match(/Deleted 1/, out)
  end
end
