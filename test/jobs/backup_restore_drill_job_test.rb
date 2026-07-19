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
      assert_includes statement, "drill_db",
                      "a DROP DATABASE that isn't the drill database: #{statement.inspect}"
    end
  end

  test "the drill database name cannot collide with a real one" do
    name = BackupRestoreDrillJob.new.send(:drill_db)

    assert_not_equal "wss_production", name
    assert_not_equal "wss_development", name
    assert_not_equal "wss_test", name
    assert_match(/drill/, name, "the name should say what it is")
    assert_match(/_#{Process.pid}\z/, name,
                 "the pid suffix is what stops two concurrent drills dropping each other's database")
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

  # The source-text checks above are guardrails, not coverage: they passed
  # happily while the job called a `psql!` helper that was never defined, so it
  # would have raised NoMethodError on its first real run. These exercise the
  # database paths for real against the test Postgres.
  class Executed < ActiveSupport::TestCase
    setup do
      @job = BackupRestoreDrillJob.new
      @drill = @job.send(:drill_db)
    end

    def send_private(name, *args) = @job.send(name, *args)

    teardown do
      send_private(:drop_drill_database!)
    rescue StandardError
      nil
    end

    test "it can create and drop its drill database for real" do
      send_private(:recreate_drill_database!)
      assert_equal 1, send_private(:count_query, "postgres",
                                   "SELECT count(*) FROM pg_database WHERE datname = '#{@drill}'")

      send_private(:drop_drill_database!)
      assert_equal 0, send_private(:count_query, "postgres",
                                   "SELECT count(*) FROM pg_database WHERE datname = '#{@drill}'")
    end

    test "counting runs against a real connection" do
      count = send_private(:count_in, ActiveRecord::Base.connection_db_config.database, "users")
      assert_equal User.count, count
    end

    test "a query against a database that isn't there fails as a drill failure" do
      error = assert_raises(BackupRestoreDrillJob::DrillFailed) do
        send_private(:count_query, "wss_definitely_not_a_database", "SELECT 1")
      end
      assert_match "query failed", error.message
    end

    test "a corrupt dump fails the restore instead of passing as empty" do
      send_private(:recreate_drill_database!)
      path = Rails.root.join("tmp", "drill_corrupt_test.sql.gz").to_s
      File.binwrite(path, "this is not gzip")

      assert_raises(BackupRestoreDrillJob::DrillFailed) { send_private(:restore!, path) }
    ensure
      FileUtils.rm_f(path)
    end
  end
end
