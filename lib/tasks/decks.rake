namespace :decks do
  desc "Load deck packages: rake decks:load DIR=/path/to/packages [PUBLISH=1] [AUTHOR=email]"
  task load: :environment do
    root = ENV["DIR"].to_s
    abort "Give the folder that holds the deck packages: rake decks:load DIR=/path/to/packages" if root.blank?
    abort "#{root} is not a folder" unless File.directory?(root)

    author = ENV["AUTHOR"].present? ? User.find_by(email: ENV["AUTHOR"]) : User.where(admin_role: "full").order(:id).first
    abort "No author found. Pass AUTHOR=<an existing user's email>." unless author

    packages = Dir[File.join(root, "*", "deck.json")].sort.map { |file| File.dirname(file) }
    packages = [ root ] if packages.empty? && File.file?(File.join(root, "deck.json"))
    abort "No deck packages (folders with a deck.json) found in #{root}" if packages.empty?

    publish = ENV["PUBLISH"] == "1"
    failed = []
    packages.each do |dir|
      deck = DeckPackageImport.call(dir, author: author, publish: publish)
      state = deck.published? ? "published" : "draft"
      puts format("%-28s %s, %d slides, %d pours, $%.2f", deck.title, state, deck.slide_images.count,
                  deck.presentation_bottles.count, deck.price)
    rescue DeckPackageImport::Invalid => e
      failed << e.message
      puts "FAILED  #{e.message}"
    end

    puts "#{packages.size - failed.size} of #{packages.size} imported as #{author.email}."
    exit 1 if failed.any?
  end
end
