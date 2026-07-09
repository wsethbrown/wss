require "aws-sdk-s3" # gem is require:false; the job loads it on demand

# Nightly production safety net: pg_dump the primary database, gzip it, and
# ship it to R2 (same bucket as uploads, under db-backups/). Keeps the last
# KEEP dumps and prunes older ones. Runs via Solid Queue's recurring schedule
# (config/recurring.yml) in the jobs container; also invocable by hand with
# `bin/kamal backup`.
#
# This exists because the server is a single box: Hetzner's snapshot backups
# protect against disk loss, but an off-box logical dump protects against the
# scarier failures — a bad migration, a fat-fingered console session, or the
# provider account itself.
class DatabaseBackupJob < ApplicationJob
  queue_as :default

  KEEP = 14
  PREFIX = "db-backups/"

  def perform
    if ENV["R2_BUCKET"].blank?
      Rails.logger.warn("[db-backup] R2 not configured — skipping")
      return
    end

    path = dump!
    upload!(path)
    prune!
    Rails.logger.info("[db-backup] shipped #{File.basename(path)} (#{File.size(path)} bytes)")
  ensure
    FileUtils.rm_f(path) if path
  end

  private

  def dump!
    db = ActiveRecord::Base.connection_db_config.configuration_hash
    path = Rails.root.join("tmp", "wss_#{Time.now.utc.strftime('%Y%m%d_%H%M%S')}.sql.gz").to_s

    command = [
      "pg_dump",
      "-h", db[:host].to_s.shellescape,
      "-p", (db[:port] || 5432).to_s,
      "-U", db[:username].to_s.shellescape,
      db[:database].to_s.shellescape,
      "| gzip >", path.shellescape
    ].join(" ")

    # bash, not sh: Debian's sh is dash, which lacks pipefail — and without
    # pipefail a failed pg_dump piped into gzip would "succeed" with an empty
    # file (the exact silent-backup failure this job exists to prevent).
    ok = system({ "PGPASSWORD" => db[:password].to_s }, "bash", "-c", "set -o pipefail; #{command}")
    raise "pg_dump failed" unless ok && File.size?(path)

    path
  end

  def upload!(path)
    File.open(path, "rb") do |file|
      s3.put_object(bucket: ENV["R2_BUCKET"], key: "#{PREFIX}#{File.basename(path)}", body: file)
    end
  end

  # Timestamped names sort lexicographically = chronologically.
  def prune!
    keys = s3.list_objects_v2(bucket: ENV["R2_BUCKET"], prefix: PREFIX).contents.map(&:key).sort
    keys[0...-KEEP].each { |key| s3.delete_object(bucket: ENV["R2_BUCKET"], key: key) } if keys.size > KEEP
  end

  def s3
    @s3 ||= Aws::S3::Client.new(
      endpoint: ENV["R2_ENDPOINT"],
      access_key_id: ENV["R2_ACCESS_KEY_ID"],
      secret_access_key: ENV["R2_SECRET_ACCESS_KEY"],
      region: "auto",
      request_checksum_calculation: "when_required",
      response_checksum_validation: "when_required"
    )
  end
end
