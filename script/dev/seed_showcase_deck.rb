# Dev-only: gives the local catalogue one deck with rendered slides, so pages
# that show slide covers and the homepage player have something real to show
# without running LibreOffice. Usage:
#   bin/rails runner script/dev/seed_showcase_deck.rb
abort "development only" unless Rails.env.development?

deck = Presentation.find_or_initialize_by(title: "The Honest Bottle")
deck.assign_attributes(
  author: User.where.not(admin_role: "none").first || User.first,
  category: "Bourbon", difficulty: "Beginner", duration: "45 min", price: 12.99,
  description: "What bottled in bond means on a whiskey label, and the 1897 law it comes from. Four pours.",
  content: "## The Honest Bottle\n\nA sample story for local development.\n\n## Whiskey was sold from the barrel\n\nPlaceholder chapter."
)
deck.save!(validate: false)
deck.slide_images.purge if deck.slide_images.attached?
Dir[Rails.root.join("test/fixtures/files/slides/slide-*.png")].sort.each do |path|
  deck.slide_images.attach(io: File.open(path), filename: File.basename(path), content_type: "image/png")
end
deck.update_columns(published: true, featured: true)
puts "Showcase deck #{deck.id}: #{deck.slide_images.count} slides attached"
