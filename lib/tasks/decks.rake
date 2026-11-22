namespace :decks do
  desc "Load deck packages: rake decks:load DIR=/path/to/packages [PUBLISH=1] [AUTHOR=email] [DECK_ID=id] [FREE=1]"
  task load: :environment do
    root = ENV["DIR"].to_s
    abort "Give the folder that holds the deck packages: rake decks:load DIR=/path/to/packages" if root.blank?
    abort "#{root} is not a folder" unless File.directory?(root)

    author = ENV["AUTHOR"].present? ? User.find_by(email: ENV["AUTHOR"]) : User.where(admin_role: "full").order(:id).first
    abort "No author found. Pass AUTHOR=<an existing user's email>." unless author

    packages = Dir[File.join(root, "*", "deck.json")].sort.map { |file| File.dirname(file) }
    packages = [ root ] if packages.empty? && File.file?(File.join(root, "deck.json"))
    abort "No deck packages (folders with a deck.json) found in #{root}" if packages.empty?

    # DECK_ID: load the one package into that deck, whatever its title (the
    # same as the admin's "Replace with a package"). Without it, decks are
    # matched by title.
    target = nil
    if ENV["DECK_ID"].present?
      target = Presentation.find_by(id: ENV["DECK_ID"])
      abort "No deck with id #{ENV['DECK_ID']}." unless target
      abort "DECK_ID loads one package; #{root} holds #{packages.size}." if packages.size > 1
    end

    # PUBLISH=1 publishes; a package priced $0 also needs FREE=1 (no accidental free decks).
    publish = ENV["PUBLISH"] == "1"
    failed = []
    packages.each do |dir|
      importer = DeckPackageImport.new(dir, author: author, publish: publish, into: target,
                                       free_confirmed: ENV["FREE"] == "1")
      deck = importer.call
      state = deck.published? ? "published" : "draft"
      puts format("%-28s %s, %d slides, %d pours, $%.2f", deck.title, state, deck.slide_images.count,
                  deck.presentation_bottles.count, deck.price)
      importer.warnings.each { |warning| puts "  note: #{warning}" }
    rescue DeckPackageImport::Invalid => e
      failed << e.message
      puts "FAILED  #{File.basename(dir)}: #{e.message}"
    end

    puts "#{packages.size - failed.size} of #{packages.size} imported as #{author.email}."
    exit 1 if failed.any?
  end
end
