namespace :events do
  # B15b: READ-ONLY. Lists upcoming events with the zone each is stored in, so
  # the owner can eyeball them before deploy. Zones are never inferred from
  # location text and nothing is written.
  desc "List upcoming events with society, society location and stored time zone (read-only)"
  task zones: :environment do
    events = Event.where("start_time >= ?", Time.current).includes(:society).order(:start_time)
    if events.empty?
      puts "No upcoming events."
      next
    end

    puts format("%-6s %-32s %-26s %-24s %s", "id", "title", "society", "society location", "time_zone")
    events.each do |e|
      puts format("%-6s %-32s %-26s %-24s %s", e.id, e.title.to_s.truncate(30), e.society&.name.to_s.truncate(24),
                  e.society&.location.to_s.truncate(22), e.time_zone.presence || "(none; falls back to #{Event::FALLBACK_TIME_ZONE})")
    end
    puts "#{events.size} upcoming event(s). Nothing was changed."
  end
end
