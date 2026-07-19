require "test_helper"

# The drill is the thing that tells us the backups are real, so its own
# failure modes matter: it must refuse to pass quietly, and it must never
# aim a destructive statement at the production database.
class BackupRestoreDrillJobTest < ActiveSupport::TestCase
  test "it skips, loudly and safely, when R2 isn't configured" do
    original = ENV["R2_BUCKET"]
    ENV["R2_BUCKET"] = ""
    assert_nothing_raised { BackupRestoreDrillJob.perform_now }
  ensure
    ENV["R2_BUCKET"] = original
  end

  test "it only ever drops its own drill database" do
    source = File.read(Rails.root.join("app/jobs/backup_restore_drill_job.rb"))
    drops = source.scan(/DROP DATABASE[^"]*/)

    assert drops.any?, "the drill is supposed to clean up after itself"
    drops.each do |statement|
      assert_includes statement, "DRILL_DB",
                      "a DROP DATABASE that isn't the drill database: #{statement.inspect}"
    end
  end

  test "the drill database name cannot collide with a real one" do
    assert_not_equal "wss_production", BackupRestoreDrillJob::DRILL_DB
    assert_not_equal "wss_development", BackupRestoreDrillJob::DRILL_DB
    assert_not_equal "wss_test", BackupRestoreDrillJob::DRILL_DB
    assert_match(/drill/, BackupRestoreDrillJob::DRILL_DB, "the name should say what it is")
  end

  test "it restores with ON_ERROR_STOP and pipefail so a broken dump can't pass" do
    source = File.read(Rails.root.join("app/jobs/backup_restore_drill_job.rb"))
    assert_includes source, "ON_ERROR_STOP=1", "psql must stop on the first error, not plough on"
    assert_includes source, "set -o pipefail", "a corrupt gzip must fail the pipeline, not empty it"
  end

  test "it checks the tables that would mean the business was lost" do
    %w[users credit_transactions user_presentations presentations].each do |table|
      assert_includes BackupRestoreDrillJob::CRITICAL_TABLES, table
    end
  end
end
