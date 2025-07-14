# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create default tags
Tag.create_default_tags
puts "Created default tags"

# Create test user for development
if Rails.env.development?
  test_user = User.find_or_create_by!(email: 'test@example.com') do |user|
    user.password = 'password'
    user.password_confirmation = 'password'
    user.first_name = 'Test'
    user.last_name = 'User'
    user.bio = 'A passionate whiskey enthusiast exploring the world of fine spirits.'
  end
  
  # Add some tags to the test user
  test_user.add_tag('Bourbon')
  test_user.add_tag('Scotch')
  test_user.add_tag('Collector')
  test_user.add_tag('Tasting')
  test_user.add_tag('Blogger')
  
  puts "Created test user: test@example.com / password"
  
  # Create admin user for testing admin panel
  admin_user = User.find_or_create_by!(email: 'admin@whiskeysharesociety.com') do |user|
    user.password = 'password'
    user.password_confirmation = 'password'
    user.first_name = 'Admin'
    user.last_name = 'User'
    user.bio = 'Administrative user for managing presentations.'
  end
  
  puts "Created admin user: admin@whiskeysharesociety.com / password"
  
  # Create sample presentations
  presentations = [
    {
      title: "Introduction to Scotch Whisky",
      category: "Scotch Whisky",
      description: "Perfect for beginners, this comprehensive presentation covers the basics of Scotch whisky production, regions, and tasting techniques.",
      content: "# Introduction to Scotch Whisky\n\n## What is Scotch Whisky?\n\nScotch whisky is a malt or grain whisky (or a blend of the two), made in Scotland. All Scotch whisky must be aged in oak barrels for at least three years. Any age statement on a bottle of Scotch whisky must reflect the youngest whisky used to produce that product.\n\n## The Five Regions\n\n### Highlands\nThe largest whisky-producing region in Scotland...\n\n### Lowlands\nKnown for their gentle, approachable whiskies...\n\n### Speyside\nHome to over half of Scotland's malt whisky distilleries...\n\n### Islay\nFamous for heavily peated whiskies...\n\n### Campbeltown\nOnce the whisky capital of the world...",
      price: 9.99,
      duration: "45 min",
      difficulty: "Beginner",
      rating: 4.8,
      review_count: 127,
      image: "scotch-intro",
      published: true
    },
    {
      title: "Bourbon: America's Native Spirit",
      category: "Bourbon",
      description: "Explore the rich history and production methods of America's favorite whiskey, from mash bills to barrel aging.",
      content: "# Bourbon: America's Native Spirit\n\n## Legal Requirements\n\nFor a whiskey to be called bourbon, it must meet specific legal requirements...\n\n## The Mash Bill\n\nBourbon must be made from a grain mixture that is at least 51% corn...\n\n## Distillation and Aging\n\nBourbon must be distilled to no more than 80% alcohol by volume...",
      price: 12.99,
      duration: "60 min",
      difficulty: "Intermediate",
      rating: 4.9,
      review_count: 89,
      image: "bourbon-guide",
      published: true
    },
    {
      title: "Japanese Whisky Masterclass",
      category: "Japanese Whisky",
      description: "Discover the unique characteristics and craftsmanship behind Japan's world-renowned whisky tradition.",
      content: "# Japanese Whisky Masterclass\n\n## History and Origins\n\nJapanese whisky began in the 1920s when Masataka Taketsuru returned from Scotland...\n\n## Production Philosophy\n\nJapanese distillers focus on precision, attention to detail, and harmony...\n\n## Key Distilleries\n\n### Yamazaki\nJapan's first malt whisky distillery...\n\n### Hakushu\nNestled in the Japanese Alps...",
      price: 14.99,
      duration: "75 min",
      difficulty: "Advanced",
      rating: 4.7,
      review_count: 156,
      image: "japanese-whisky",
      published: true
    }
  ]
  
  presentations.each do |presentation_data|
    presentation = Presentation.find_or_create_by(title: presentation_data[:title]) do |p|
      p.author = admin_user
      p.category = presentation_data[:category]
      p.description = presentation_data[:description]
      p.content = presentation_data[:content]
      p.price = presentation_data[:price]
      p.duration = presentation_data[:duration]
      p.difficulty = presentation_data[:difficulty]
      p.rating = presentation_data[:rating]
      p.review_count = presentation_data[:review_count]
      p.image = presentation_data[:image]
      p.published = presentation_data[:published]
    end
    puts "Created presentation: #{presentation.title}"
  end
end
