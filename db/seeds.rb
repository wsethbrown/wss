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
  
  # Create admin user for testing admin panel.
  # Admin rights key off the `is_admin` column (unified in the security pass);
  # the old "@whiskeysharesociety.com email == admin" shortcut is gone, so we
  # must set the flag explicitly here.
  admin_user = User.find_or_create_by!(email: 'admin@whiskeysharesociety.com') do |user|
    user.password = 'password'
    user.password_confirmation = 'password'
    user.first_name = 'Admin'
    user.last_name = 'User'
    user.bio = 'Administrative user for managing presentations.'
  end
  admin_user.update!(is_admin: true) unless admin_user.is_admin?

  puts "Created admin user: admin@whiskeysharesociety.com / password (is_admin: true)"
  
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
      p.image = presentation_data[:image]
      # Seed decks have no files; bypass the publish gate (dev-only shortcut).
      p.save!(validate: false) if p.new_record?
      p.update_columns(published: presentation_data[:published])
      
      # Add tasting notes for first presentation
      if presentation_data[:title] == "Introduction to Scotch Whisky"
        p.nose_notes = "Vanilla, honey, light oak, subtle fruit notes"
        p.palate_notes = "Smooth, balanced, with notes of caramel and spice"
        p.finish_notes = "Medium length with warming oak and gentle smoke"
        p.body_notes = "Medium-bodied with a smooth, approachable texture"
        p.whiskey_recommendations = "Glenfiddich 12 Year|Speyside|$45|Light & Fruity|Pear, oak, subtle spice\nLaphroaig 10 Year|Islay|$65|Peaty & Smoky|Iodine, peat, sea salt\nHighland Park 12 Year|Highlands|$55|Balanced|Honey, heather, light smoke\nAuchentoshan 12 Year|Lowlands|$50|Smooth & Light|Vanilla, citrus, nuts"
      end
    end
    puts "Created presentation: #{presentation.title}"
  end
  
  # Load additional presentation seeds
  require_relative 'seeds/presentations'

  # Give the test user an active subscription + a couple of credits so the
  # marketplace / credit-redemption flow can be exercised end to end.
  test_user.update!(
    subscription_status: 'active',
    subscription_plan: 'monthly',
    subscription_ends_at: 1.month.from_now
  )
  if test_user.credit_transactions.none?
    2.times { CreditTransaction.grant_monthly_credit(test_user, 'Seed credit') }
  end
  puts "Test user: active subscription, #{test_user.reload.credits} credit(s)"

  # --- Societies (public + private), memberships, and events ---------------
  society_seeds = [
    {
      name: "Athens Whiskey Society",
      description: "The founding chapter. Each month a member is assigned a topic, " \
                   "researches it, and presents a narrative tasting deck with a pour to match.",
      location: "Athens, GA",
      is_private: false,
      creator: admin_user
    },
    {
      name: "Peat Freaks",
      description: "For the Islay-obsessed. Heavily peated drams, smoke-forward flights, " \
                   "and the occasional coastal cask-strength showdown.",
      location: "Online",
      is_private: false,
      creator: test_user
    },
    {
      name: "The Rare Cask Room",
      description: "Invite-only. Allocated bottles, single-barrel picks, and vertical " \
                   "tastings you won't find on a shelf.",
      location: "Private",
      is_private: true,
      creator: admin_user
    }
  ]

  societies = society_seeds.map do |attrs|
    society = Society.find_or_create_by!(name: attrs[:name]) do |s|
      s.description = attrs[:description]
      s.location    = attrs[:location]
      s.is_private  = attrs[:is_private]
      s.creator     = attrs[:creator]
    end
    puts "Created society: #{society.name} (#{society.public? ? 'public' : 'private'})"
    society
  end

  # Make the test user an active member of the public societies they don't own.
  societies.select(&:public?).each do |society|
    next if society.creator == test_user
    society.society_memberships.find_or_create_by!(user: test_user) do |m|
      m.role = :member
      m.status = :active
    end
  end

  # A few events across the societies, some upcoming and one past, with RSVPs.
  event_seeds = [
    { society: societies[0], title: "May: The Sherried Speyside Thread",
      description: "A narrative flight tracing how sherry-cask maturation reshapes a Speyside spirit.",
      location: "Creature Comforts, Athens", start_offset: 6.days, duration_hours: 2 },
    { society: societies[0], title: "June: Bourbon & the Corn Question",
      description: "Why mash bill matters — a story told through four pours.",
      location: "Member's home", start_offset: 34.days, duration_hours: 2 },
    { society: societies[1], title: "Islay Cask-Strength Showdown",
      description: "Blind-taste four cask-strength Islay drams and rank them.",
      location: "Online (Zoom)", start_offset: 12.days, duration_hours: 1 },
    { society: societies[0], title: "April: Japanese Whisky Origins (recap)",
      description: "Our recorded session on the roots of Japanese whisky.",
      location: "Athens, GA", start_offset: -20.days, duration_hours: 2 }
  ]

  event_seeds.each do |attrs|
    event = attrs[:society].events.find_or_create_by!(title: attrs[:title]) do |e|
      e.description = attrs[:description]
      e.location    = attrs[:location]
      e.organizer   = attrs[:society].creator
      e.start_time  = attrs[:start_offset].from_now
      e.end_time    = attrs[:start_offset].from_now + attrs[:duration_hours].hours
    end
    # RSVP the test user "yes" to upcoming events they're a member of.
    if event.upcoming? && event.society.has_member?(test_user)
      event.event_rsvps.find_or_create_by!(user: test_user) { |r| r.status = 'yes' }
    end
    puts "Created event: #{event.title}"
  end

  # --- Review-system demo chain (Phase 2) -----------------------------------
  # A completed public-society night with three pours and two reviewers, so
  # bottle pages, /reviews, the event page, and the society review board all
  # have provenance to show: review card → event page → society board.
  athens = societies[0] # Athens Whiskey Society (public)

  pour_specs = [
    { name: "Ardbeg 10", distillery: "Ardbeg", region: "Islay",
      style: "Single Malt Scotch", abv: 46.0, label: "Pour #1 — the blind" },
    { name: "GlenDronach 12", distillery: "GlenDronach", region: "Highlands",
      style: "Single Malt Scotch", abv: 43.0, label: nil },
    { name: "Four Roses Small Batch", distillery: "Four Roses", region: "Kentucky",
      style: "Bourbon", abv: 45.0, label: nil }
  ]

  night = athens.events.find_or_create_by!(title: "March: The Blind Islay Flight") do |e|
    e.description = "Three brown-bagged pours, scored before the reveal."
    e.location    = "Athens, GA"
    e.organizer   = athens.creator
    e.start_time  = 3.weeks.ago
    e.end_time    = 3.weeks.ago + 2.hours
  end

  pours = pour_specs.each_with_index.map do |spec, i|
    bottle = Bottle.find_or_create_by!(name: spec[:name], distillery: spec[:distillery]) do |b|
      b.region = spec[:region]
      b.style  = spec[:style]
      b.abv    = spec[:abv]
    end
    night.event_bottles.find_or_create_by!(bottle: bottle) do |eb|
      eb.position = i + 1
      eb.label    = spec[:label]
    end
    bottle
  end

  # Dev shortcut, mirroring the presentation-seed publish bypass: the "no
  # RSVP after the event" rule doesn't apply to seeded history, so skip
  # validations for these two RSVPs only.
  [admin_user, test_user].each do |member|
    rsvp = night.event_rsvps.find_or_initialize_by(user: member)
    rsvp.status = "yes"
    rsvp.save!(validate: false)
  end

  # Event reviews pass every real gate (pours listed + revealed, RSVPs yes).
  scores = {
    admin_user => { pours[0] => [4.5, "Smoke first, then pears — the blind fooled nobody."],
                    pours[1] => [3.5, "Sherry-sweet, a little thin on the finish."],
                    pours[2] => [4.0, "Rye spice over caramel. Crowd-pleaser."] },
    test_user  => { pours[0] => [4.0, "Campfire in a glass."],
                    pours[1] => [3.0, "Fine, but I came for the peat."] }
  }
  scores.each do |member, ratings|
    ratings.each do |bottle, (rating, notes)|
      Review.find_or_create_by!(user: member, bottle: bottle, event: night) do |r|
        r.rating = rating
        r.notes  = notes
      end
    end
  end
  puts "Review demo chain: #{night.title} — #{night.event_bottles.count} pours, #{night.reviews.count} event reviews"
end
