require "test_helper"
require "aws-sdk-s3" # require:false gem — load before stubbing Aws::S3::Client

class DatabaseBackupJobTest < ActiveSupport::TestCase
  test "skips quietly when R2 is not configured" do
    original = ENV.delete("R2_BUCKET")
    assert_nothing_raised { DatabaseBackupJob.perform_now }
  ensure
    ENV["R2_BUCKET"] = original if original
  end

  test "dumps the database for real and uploads/prunes via the S3 client" do
    ENV["R2_BUCKET"] = "test-bucket"

    uploaded = {}
    client = Object.new
    client.define_singleton_method(:put_object) do |bucket:, key:, body:|
      uploaded[:bucket] = bucket
      uploaded[:key] = key
      uploaded[:bytes] = body.read.bytesize
    end
    # Old keys beyond KEEP must be pruned, newest retained.
    old_keys = (1..16).map { |i| "db-backups/wss_202601#{format('%02d', i)}_000000.sql.gz" }
    contents = old_keys.map { |k| Struct.new(:key).new(k) }
    deleted = []
    client.define_singleton_method(:list_objects_v2) { |**| Struct.new(:contents).new(contents) }
    client.define_singleton_method(:delete_object) { |bucket:, key:| deleted << key }

    Aws::S3::Client.stubs(:new).returns(client)

    DatabaseBackupJob.perform_now

    assert_equal "test-bucket", uploaded[:bucket]
    assert_match %r{\Adb-backups/wss_\d{8}_\d{6}\.sql\.gz\z}, uploaded[:key]
    assert_operator uploaded[:bytes], :>, 100, "gzipped dump should have real content"
    # 16 old keys, keep the newest 14 → the 2 oldest go.
    assert_equal old_keys.first(2), deleted.sort
    # The local temp file is cleaned up.
    assert_empty Dir[Rails.root.join("tmp", "wss_*.sql.gz")]
  ensure
    ENV.delete("R2_BUCKET")
  end
end
