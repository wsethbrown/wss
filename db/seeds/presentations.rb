# Create sample presentations if none exist
if Presentation.count == 0
  puts "Creating sample presentations..."

  # Find or create admin user
  admin = User.find_by(email: 'seth@whiskeysharesociety.com')
  unless admin
    admin = User.create!(
      email: 'seth@whiskeysharesociety.com',
      password: 'password123',
      first_name: 'Seth',
      last_name: 'Admin',
      role: 'admin'
    )
  end

  presentations = [
    {
      title: 'Introduction to Scotch Whisky',
      description: 'Perfect for beginners, this comprehensive presentation covers the basics of Scotch whisky production, regions, and tasting techniques.',
      content: 'Full presentation content about Scotch whisky...',
      category: 'Scotch Whisky',
      price: 9.99,
      difficulty: 'Beginner',
      duration: '45 min',
      published: true,
      nose_notes: 'Vanilla, honey, light oak, subtle fruit notes',
      palate_notes: 'Smooth, balanced, with notes of caramel and spice',
      finish_notes: 'Medium length with warming oak and gentle smoke',
      body_notes: 'Medium-bodied with a smooth, approachable texture',
      whiskey_recommendations: "Glenfiddich 12 Year|Speyside|$|Light & Fruity\nLaphroaig 10 Year|Islay|$$|Peaty & Smoky\nHighland Park 12 Year|Highlands|$$|Balanced\nAuchentoshan 12 Year|Lowlands|$|Smooth & Light"
    },
    {
      title: 'The Complete Bourbon Guide',
      description: 'Master the art of America\'s native spirit. Learn about mash bills, aging requirements, and the unique characteristics of bourbon.',
      content: 'Comprehensive bourbon education content...',
      category: 'Bourbon',
      price: 12.99,
      difficulty: 'Intermediate',
      duration: '60 min',
      published: true,
      nose_notes: 'Caramel, vanilla, toasted oak, cinnamon',
      palate_notes: 'Sweet corn, brown sugar, baking spices',
      finish_notes: 'Long and warming with notes of leather and tobacco',
      body_notes: 'Full-bodied with a rich, creamy texture',
      whiskey_recommendations: "Buffalo Trace|Kentucky|$|Classic Bourbon\nWoodford Reserve|Kentucky|$$|Premium Small Batch\nMaker's Mark|Kentucky|$$|Wheated Bourbon\nFour Roses Single Barrel|Kentucky|$$|High Rye"
    },
    {
      title: 'Japanese Whisky Excellence',
      description: 'Explore the precision and artistry of Japanese whisky making, from Yamazaki to Nikka.',
      content: 'Deep dive into Japanese whisky culture and production...',
      category: 'Japanese Whisky',
      price: 14.99,
      difficulty: 'Advanced',
      duration: '75 min',
      published: true,
      nose_notes: 'Delicate florals, green apple, subtle smoke',
      palate_notes: 'Refined and elegant with notes of pear and honey',
      finish_notes: 'Clean and crisp with a hint of white pepper',
      body_notes: 'Light to medium-bodied with silky texture',
      whiskey_recommendations: "Nikka From the Barrel|Japan|$$|Bold & Complex\nYamazaki 12|Japan|$$$|Fruity & Elegant\nHakushu 12|Japan|$$$|Fresh & Smoky\nHibiki Harmony|Japan|$$|Balanced Blend"
    }
  ]

  presentations.each do |attrs|
    presentation = Presentation.create!(
      title: attrs[:title],
      description: attrs[:description],
      content: attrs[:content],
      category: attrs[:category],
      price: attrs[:price],
      difficulty: attrs[:difficulty],
      duration: attrs[:duration],
      published: attrs[:published],
      author: admin,
      nose_notes: attrs[:nose_notes],
      palate_notes: attrs[:palate_notes],
      finish_notes: attrs[:finish_notes],
      body_notes: attrs[:body_notes],
      whiskey_recommendations: attrs[:whiskey_recommendations],
      rating: rand(4.5..5.0).round(1),
      review_count: rand(10..150)
    )

    puts "Created presentation: #{presentation.title}"
  end

  puts "Created #{Presentation.count} presentations"
end
