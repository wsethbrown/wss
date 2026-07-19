require "aws-sdk-s3" # gem is require:false; the job loads it on demand

# Weekly proof that the nightly backup can actually be restored.
#
# A backup nobody has restored is a hope, not a backup. DatabaseBackupJob
# already guards against a truncated dump (pipefail + a size check), but that
# only proves bytes were written. It cannot tell you the dump will rebuild the
# schema, that the data survived, or that the file in R2 is still readable
# months later. The failures that matter here are silent: a dump that has been
# quietly empty since a Postgres upgrade, an R2 lifecycle rule expiring
# objects, a schema change that dumps but won't reload.
#
# So this pulls the NEWEST backup out of R2, restores it into a throwaway
# database beside the real one, checks the data is really there, and drops it.
# It never touches the production database: it only ever CREATEs and DROPs
# `DRILL_DB`, and every statement it runs is against that name.
#
# Runs from config/recurring.yml. Invoke by hand with:
#   bin/kamal-deploy app exec --reuse --roles=web \
#     'bin/rails runner BackupRestoreDrillJob.perform_now'
class BackupRestoreDrillJob < ApplicationJob
  queue_as :default

  DRILL_DB = "wss_restore_drill".freeze
  PREFIX = "db-backups/".freeze

  # Tables whose emptiness would mean the restore silently lost the business.
  # Checked as "production has rows => the restore has the same count".
  CRITICAL_TABLES = %w[
    users presentations societies events credit_transactions user_presentations
  ].freeze

  class DrillFailed < StandardError; end

  def perform
    if ENV["R2_BUCKET"].blank?
      Rails.logger.warn("[restore-drill] R2 not configured, skipping")
      return
    end

    key, body = newest_backup
    if key.nil?
      Rails.logger.error("[restore-drill] FAILED: no backups found in #{PREFIX}")
      raise DrillFailed, "no backups in R2"
    end

    age_days = ((Time.current - @backup_time) / 1.day).round(1)
    Rails.logger.info("[restore-drill] restoring #{key} (#{body.bytesize} bytes, #{age_days} days old)")

    # A backup that stopped being written is the failure this drill exists to
    # catch, and it would otherwise restore perfectly while being stale.
    if age_days > 2
      Rails.logger.error("[restore-drill] FAILED: newest backup is #{age_days} days old, nightly backups have stopped")
      raise DrillFailed, "newest backup is #{age_days} days old"
    end

    path = write_dump(body)
    begin
      recreate_drill_database!
      restore!(path)
      verify!
      Rails.logger.info("[restore-drill] PASSED: #{key} restored and verified")
    ensure
      FileUtils.rm_f(path)
      drop_drill_database!
    end
  rescue DrillFailed
    raise
  rescue => e
    Rails.logger.error("[restore-drill] FAILED: #{e.class}: #{e.message}")
    raise
  end

  private

  def newest_backup
    objects = s3.list_objects_v2(bucket: ENV["R2_BUCKET"], prefix: PREFIX).contents
    newest = objects.max_by(&:last_modified)
    return [ nil, nil ] if newest.nil?

    @backup_time = newest.last_modified
    [ newest.key, s3.get_object(bucket: ENV["R2_BUCKET"], key: newest.key).body.read ]
  end

  def write_dump(body)
    path = Rails.root.join("tmp", "restore_drill_#{Process.pid}.sql.gz").to_s
    File.binwrite(path, body)
    path
  end

  # NOTE: every psql call below targets DRILL_DB or the `postgres` maintenance
  # database. Nothing here names the production database.
  def recreate_drill_database!
    psql!("postgres", "DROP DATABASE IF EXISTS #{DRILL_DB}")
    psql!("postgres", "CREATE DATABASE #{DRILL_DB}")
  end

  def drop_drill_database!
    psql!("postgres", "DROP DATABASE IF EXISTS #{DRILL_DB}")
    Rails.logger.info("[restore-drill] drill database dropped")
  rescue => e
    # Leaving it behind wastes disk and holds a copy of production data, so
    # this is worth shouting about even though the drill itself may have passed.
    Rails.logger.error("[restore-drill] could not drop #{DRILL_DB}: #{e.class}: #{e.message}")
  end

  def restore!(path)
    # bash for pipefail: without it a corrupt gzip would "succeed" into an
    # empty psql, which is precisely the false pass this job must not give.
    command = "set -o pipefail; gunzip -c #{path.shellescape} | psql #{conn_args} -d #{DRILL_DB} -q -v ON_ERROR_STOP=1"
    ok = system({ "PGPASSWORD" => db[:password].to_s }, "bash", "-c", command, out: File::NULL)
    raise DrillFailed, "psql restore of #{path} failed" unless ok
  end

  def verify!
    empty = []

    CRITICAL_TABLES.each do |table|
      production = count_in(db[:database], table)
      restored = count_in(DRILL_DB, table)

      raise DrillFailed, "#{table}: production has #{production} rows, restore has #{restored}" if production != restored

      empty << table if production.zero?
    end

    # The credit ledger is the money. A restore that loses its consistency is
    # worse than no restore, because it looks usable.
    drift = count_query(DRILL_DB, <<~SQL)
      SELECT count(*) FROM users u
      WHERE u.credits <> COALESCE((SELECT SUM(amount) FROM credit_transactions ct WHERE ct.user_id = u.id), 0)
    SQL
    raise DrillFailed, "#{drift} user(s) have credits that disagree with the ledger in the restored copy" if drift.positive?

    tables = count_query(DRILL_DB, "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'")
    raise DrillFailed, "restored schema has only #{tables} tables" if tables < 20

    Rails.logger.info("[restore-drill] verified #{tables} tables, ledger consistent" \
                      "#{empty.any? ? ", note: #{empty.join(', ')} empty in production too" : ''}")
  end

  def count_in(database, table) = count_query(database, "SELECT count(*) FROM #{table}")

  def count_query(database, sql)
    out = `PGPASSWORD=#{db[:password].to_s.shellescape} psql #{conn_args} -d #{database.to_s.shellescape} -tAc #{sql.shellescape}`
    raise DrillFailed, "query failed against #{database}" unless $?.success?

    out.strip.to_i
  end

  def conn_args
    "-h #{db[:host].to_s.shellescape} -p #{(db[:port] || 5432)} -U #{db[:username].to_s.shellescape}"
  end

  def db = @db ||= ActiveRecord::Base.connection_db_config.configuration_hash

  def s3
    @s3 ||= Aws::S3::Client.new(
      access_key_id: ENV["R2_ACCESS_KEY_ID"],
      secret_access_key: ENV["R2_SECRET_ACCESS_KEY"],
      endpoint: ENV["R2_ENDPOINT"],
      region: "auto"
    )
  end
end
