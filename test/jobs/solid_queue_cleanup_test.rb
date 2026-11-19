require "test_helper"
require "rake"

# I1: finished jobs hold raw mail arguments, and nothing was clearing them.
class SolidQueueCleanupTest < ActiveSupport::TestCase
  test "production recurring schedule clears finished jobs" do
    config = YAML.safe_load(ERB.new(File.read(Rails.root.join("config/recurring.yml"))).result, aliases: true)
    entry = config.dig("production", "clear_solid_queue_finished_jobs")
    assert entry, "recurring.yml needs the finished-job cleanup entry"
    assert_match "clear_finished_in_batches", entry["command"]
    assert entry["schedule"].present?
  end

  test "a one-off purge task exists" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("solid_queue:purge_finished")
    assert Rake::Task.task_defined?("solid_queue:purge_finished")
  end
end
