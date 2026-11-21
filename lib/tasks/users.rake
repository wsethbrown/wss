namespace :users do
  desc "Report (and with CONFIRM=1 delete) accounts nobody ever used. " \
       "Optional CREATED_AFTER=YYYY-MM-DD / CREATED_BEFORE=YYYY-MM-DD. Prints ids and dates, never emails."
  task purge_unused: :environment do
    parse = lambda do |name|
      value = ENV[name].presence
      next nil unless value

      Date.iso8601(value)
    rescue Date::Error
      abort "#{name} must be a date like 2026-08-01 (got #{value.inspect})"
    end

    UnusedAccounts.new(created_after: parse.call("CREATED_AFTER"), created_before: parse.call("CREATED_BEFORE"))
                  .run(confirm: ENV["CONFIRM"] == "1")
  end
end
