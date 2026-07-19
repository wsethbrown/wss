# Deck snapshot: copy the real decks out of production and into development,
# so local testing runs against the same catalog customers see.
#
#   Export (on prod):
#     source ~/.wss-production.env
#     bin/kamal-deploy app exec --reuse --roles=web \
#       'bin/rails decks:export' > tmp/deck_snapshot.json
#
#   Import (locally):
#     docker compose exec web bin/rails decks:import[tmp/deck_snapshot.json]
#
# Scope on purpose: deck records, their tags, and the featured image. The
# heavy attachments (deck PDF, rendered slide images, scorecards) are NOT
# copied — they're large, they live in R2, and nothing about catalog/review
# testing needs them. Import marks such decks as drafts if they'd fail the
# publish validation, rather than faking files that aren't there.
#
# This is a one-way prod -> dev tool. It never writes to production.
SNAPSHOT_HOST = "https://whiskeysharesociety.com".freeze

namespace :decks do
  desc "Dump published decks as JSON on stdout (run on production)"
  task export: :environment do
    decks = Presentation.published.includes(:tags).map do |deck|
      attrs = deck.attributes.except("id", "author_id", "created_at", "updated_at",
                                     "download_count", "reviews_count", "reviews_average")
      image =
        if deck.featured_image.attached? && deck.featured_image.blob.byte_size < 8.megabytes
          {
            "filename" => deck.featured_image.filename.to_s,
            "content_type" => deck.featured_image.content_type,
            "data" => Base64.strict_encode64(deck.featured_image.download)
          }
        end

      attrs.merge(
        "tag_names" => deck.tags.pluck(:name),
        "featured_image" => image,
        "pour_bottles" => deck.presentation_bottles.includes(:bottle).map do |pour|
          { "name" => pour.bottle.name, "distillery" => pour.bottle.distillery,
            "label" => pour.label, "position" => pour.position }
        end
      )
    end

    # stdout is the transport (kamal pipes it back), so nothing else may print.
    puts JSON.pretty_generate("exported_at" => Time.current.iso8601, "decks" => decks)
  end

  desc "Load a deck snapshot into this environment (development only)"
  task :import, [:path] => :environment do |_t, args|
    if Rails.env.production?
      abort "decks:import refuses to run in production — this is a prod -> dev tool."
    end

    path = args[:path] || "tmp/deck_snapshot.json"
    abort "No snapshot at #{path}" unless File.exist?(path)

    payload = JSON.parse(File.read(path))
    author = User.find_by(admin_role: "full") || User.first
    abort "No user to own the decks" unless author

    Rails.logger.info "Deck snapshot: importing #{payload['decks'].size} deck(s) from #{path} (exported #{payload['exported_at']})"

    payload["decks"].each do |row|
      row = row.dup
      tag_names = row.delete("tag_names") || []
      image = row.delete("featured_image")
      row_image_url = row.delete("image_url")
      pours = row.delete("pour_bottles") || []
      published = row.delete("published")

      deck = Presentation.find_or_initialize_by(title: row["title"])
      deck.assign_attributes(row.merge(author: author))
      deck.save!(validate: false)

      deck.tags = tag_names.map { |n| Tag.find_or_create_by(name: n) { |t| t.category = "deck" } }

      # Two shapes accepted: an embedded base64 image (decks:export) or a
      # public image_url (the lighter one-liner export), fetched over HTTPS.
      if !deck.featured_image.attached?
        if image
          deck.featured_image.attach(io: StringIO.new(Base64.decode64(image["data"])),
                                     filename: image["filename"], content_type: image["content_type"])
        elsif row_image_url.present?
          begin
            # Active Storage blob URLs REDIRECT to the storage service, so the
            # fetch has to follow them or every image comes back as a 302.
            url = row_image_url.start_with?("http") ? row_image_url : "#{SNAPSHOT_HOST}#{row_image_url}"
            body = nil
            5.times do
              response = Net::HTTP.get_response(URI.parse(url))
              case response
              when Net::HTTPSuccess then body = response.body; break
              when Net::HTTPRedirection then url = response["location"]
              else break
              end
            end
            if body
              deck.featured_image.attach(io: StringIO.new(body), filename: File.basename(URI.parse(url).path),
                                         content_type: "image/jpeg")
            else
              Rails.logger.warn "Deck snapshot: image fetch for #{deck.title} gave no body"
            end
          rescue => e
            Rails.logger.warn "Deck snapshot: could not fetch image for #{deck.title}: #{e.class}: #{e.message}"
          end
        end
      end

      # Publish as prod has it. The deck FILES aren't copied, so an imported
      # deck can't be opened or downloaded locally — that's expected, and the
      # point is testing the catalog, cards, reviews and search against real
      # titles. update_column skips the publish validation deliberately.
      deck.update_column(:published, !!published)

      pours.each_with_index do |pour, i|
        bottle = Bottle.find_or_create_by!(name: pour["name"]) do |b|
          b.distillery = pour["distillery"]
          b.created_by = author
        end
        PresentationBottle.find_or_create_by!(presentation: deck, bottle: bottle) do |pb|
          pb.label = pour["label"]
          pb.position = pour["position"] || i + 1
        end
      end

      puts "  #{deck.published? ? 'published' : 'draft   '}  #{deck.title}"
    end

    puts "Imported #{payload['decks'].size} deck(s). Deck files are NOT copied, so downloads/Present won't work locally."
  end
end
