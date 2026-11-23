require "test_helper"

# B16 (I15, I22, I28, M21): the pages that render many rows must not issue more
# queries when there are more rows. Each test measures a page with a few rows,
# adds many more, and asserts the count did not grow.
class QueryCountsTest < ActionDispatch::IntegrationTest
  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")

  # Views allowed to show an original on purpose, or waiting on their owning task:
  #  - societies/edit.html.erb: the banner cropper edits the full-size original, on purpose.
  EXEMPT_FROM_VARIANT_RULE = %w[societies/edit.html.erb].freeze

  # Counts the SQL a block runs, ignoring schema lookups and transaction control.
  def count_queries
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:sql] =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i
      queries << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end

  # Which SQL shapes ran more often in `many` than in `few` (for failure messages).
  def growth(few, many)
    tally = ->(list) { list.map { |q| q.gsub(/IN \([^)]*\)/, "IN (...)")[0, 160] }.tally }
    before = tally.(few)
    tally.(many).filter_map { |q, n| "#{n - before.fetch(q, 0)}x #{q}" if n > before.fetch(q, 0) }.join("\n")
  end

  def measure(path)
    get path # warm the caches (schema, i18n, Pundit) so only per-row work counts
    assert_response :success
    queries = count_queries { get path }
    assert_response :success
    queries
  end

  def attach_png(attachable, name)
    attachable.attach(io: StringIO.new(PNG), filename: name, content_type: "image/png")
  end

  def new_deck(index, slides: 2)
    deck = Presentation.create!(author: users(:admin), title: "Deck #{index} #{SecureRandom.hex(3)}", content: "A story.", price: 5)
    deck.update_column(:published, true)
    attach_png(deck.featured_image, "cover#{index}.png")
    slides.times { |i| attach_png(deck.slide_images, "s#{index}-#{i}.png") }
    deck
  end

  def new_user(index, with_photo: true)
    user = User.create!(email: "qc#{index}-#{SecureRandom.hex(3)}@example.com", password: "password",
                        first_name: "Qc#{index}", last_name: "Member")
    attach_png(user.profile_image, "me#{index}.png") if with_photo
    user
  end

  test "library index query count does not grow with the number of decks" do
    sign_in users(:john)
    2.times { |i| new_deck(i) }
    few = measure(presentations_path)

    8.times { |i| new_deck(10 + i) }
    many = measure(presentations_path)

    assert_operator many.size, :<=, few.size, "library queries grew with deck count:\n#{growth(few, many)}"
  end

  # The homepage's library rows (the face and the story frame) show each
  # deck's cover: preloaded, so a row costs no queries of its own.
  test "homepage query count does not grow with the library's rows" do
    new_deck(1)
    few = measure(root_path)
    2.times { |i| new_deck(2 + i) }
    many = measure(root_path)
    assert_operator many.size, :<=, few.size, "homepage queries grew with library rows:\n#{growth(few, many)}"
  end

  # The tasting record without a verdict night lists the newest public reviews,
  # one row per bottle, each with its reviewer: preloaded, so a row costs no
  # queries of its own.
  test "homepage query count does not grow with the tasting record's rows" do
    Review.destroy_all
    review = lambda do |i|
      Review.new(user: new_user(i, with_photo: false), bottle: Bottle.create!(name: "QC Record #{i}", distillery: "QC"),
                 rating: 4.0, notes: "n", flavor_wheel: { "smoky" => 0.5 }).save!(validate: false)
    end
    2.times { |i| review.(i) }
    few = measure(root_path)
    assert_select ".face.f4 .rv-rows li.pour", 2
    6.times { |i| review.(10 + i) }
    many = measure(root_path)
    assert_select ".face.f4 .rv-rows li.pour", 3
    assert_operator many.size, :<=, few.size, "homepage queries grew with the record's rows:\n#{growth(few, many)}"
  end

  def add_society_rows(society, event, count, offset)
    count.times do |i|
      member = new_user(offset + i)
      SocietyMembership.create!(society: society, user: member, role: "member", status: "active")
      bottle = Bottle.create!(name: "QC Bottle #{offset + i}", distillery: "QC Distillery")
      Review.new(user: member, bottle: bottle, event: event, rating: 4.0, notes: "n").save!(validate: false)
    end
  end

  test "society page query count does not grow with members or reviews" do
    society = societies(:single_malt)
    event = society.events.first
    sign_in users(:admin)
    add_society_rows(society, event, 2, 0)
    few = measure(society_path(society))

    add_society_rows(society, event, 8, 10)
    many = measure(society_path(society))

    assert_operator many.size, :<=, few.size, "society queries grew with rows:\n#{growth(few, many)}"
  end

  test "society page caps the review board at 15 bottles" do
    society = societies(:single_malt)
    event = society.events.first
    20.times do |i|
      bottle = Bottle.create!(name: "Board Bottle #{i}", distillery: "QC Distillery")
      Review.new(user: users(:admin), bottle: bottle, event: event, rating: 3.0, notes: "n").save!(validate: false)
    end
    get society_path(society)
    assert_response :success
    assert_select "[data-role=board-row]", 15
  end

  # G1a: the table (one glass per RSVP) and the verdict (one row per scored pour).
  def add_night_rows(event, count, offset)
    count.times do |i|
      member = new_user(offset + i)
      SocietyMembership.create!(society: event.society, user: member, role: "member", status: "active")
      EventRsvp.new(event: event, user: member, status: i.even? ? "yes" : "maybe").save!(validate: false)
      bottle = Bottle.create!(name: "QC Night Pour #{offset + i}", distillery: "QC Distillery")
      EventBottle.create!(event: event, bottle: bottle, position: 10 + offset + i)
      Review.new(user: member, bottle: bottle, event: event, rating: 3.5, notes: "n").save!(validate: false)
    end
  end

  test "event page query count does not grow with RSVPs, pours or the verdict" do
    event = events(:spring_blind)
    sign_in users(:john)
    add_night_rows(event, 2, 0)
    few = measure(society_event_path(event.society, event))
    assert_select "[data-role=verdict-row]", 5

    add_night_rows(event, 8, 10)
    many = measure(society_event_path(event.society, event))
    assert_select "[data-role=verdict-row]", 13

    assert_operator many.size, :<=, few.size, "event page queries grew with rows:\n#{growth(few, many)}"
  end

  test "society page query count does not grow with the next night's RSVPs" do
    event = events(:mystery_flight)
    sign_in users(:john)
    2.times { |i| EventRsvp.create!(event: event, user: new_user(i), status: "yes") }
    few = measure(society_path(event.society))

    8.times { |i| EventRsvp.create!(event: event, user: new_user(10 + i), status: "maybe") }
    many = measure(society_path(event.society))
    assert_select ".panel-ink [data-role=the-table]", text: /\+/ # more seats than glasses shown

    assert_operator many.size, :<=, few.size, "society queries grew with RSVPs:\n#{growth(few, many)}"
  end

  def add_tastings(count, offset)
    count.times do |i|
      reviewer = new_user(offset + i)
      bottle = Bottle.create!(name: "QC Pour #{offset + i}", distillery: "QC Distillery")
      Review.create!(user: reviewer, bottle: bottle, rating: 4.0, notes: "n")
    end
  end

  test "reviews index query count does not grow with bottles or tastings" do
    sign_in users(:john)
    add_tastings(2, 0)
    few = measure(reviews_path)

    add_tastings(8, 10)
    many = measure(reviews_path)

    assert_operator many.size, :<=, few.size, "reviews index queries changed with rows:\nmore:\n#{growth(few, many)}\nfewer:\n#{growth(many, few)}"
  end

  test "the layout counts unread notifications once per request" do
    user = users(:john)
    Notification.create!(user: user, action: "follow", actor: users(:jane))
    sign_in user
    queries = measure(presentations_path)
    unread = queries.grep(/FROM "notifications"/)
    assert_equal 1, unread.size, "expected one notifications query, got:\n#{unread.join("\n")}"
  end

  test "views never link the original of an uploaded image outside downloads" do
    offenders = Dir[Rails.root.join("app/views/**/*.erb")].reject { |f| f.include?("/home/index_next") || EXEMPT_FROM_VARIANT_RULE.any? { |e| f.end_with?(e) } }.flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, i|
        next unless line =~ /rails_blob_(path|url)\(|url_for\(@?\w+\.(profile_image|profile_picture|banner_image|featured_image)\)|image_tag\s+[@\w.]*(profile_image|profile_picture|banner_image|featured_image)\s*[,)]|image_tag\s+(slide|cover)\s*[,)]/
        "#{file.sub(Rails.root.to_s + '/', '')}:#{i + 1}"
      end
    end
    assert_empty offenders, "image_tag of an original attachment (use a named variant): #{offenders.join(', ')}"
  end

  test "dashboard query count does not grow with the number of events, pours and societies" do
    member = users(:seth)
    society = societies(:single_malt)
    make_night = lambda do |i, start|
      e = Event.new(society: society, organizer: users(:admin), title: "QC night #{i}", description: "x",
                    location: "den", start_time: start, end_time: start + 2.hours)
      e.save!(validate: false)
      e
    end
    sign_in member
    few = measure(dashboard_path)

    6.times do |i|
      upcoming = make_night.(i, (i + 2).days.from_now)
      EventRsvp.create!(event: upcoming, user: member, status: i.even? ? "yes" : "maybe") if i < 3
      past = make_night.(i + 100, (i + 2).days.ago)
      EventRsvp.new(event: past, user: member, status: "yes").save!(validate: false)
      EventBottle.create!(event: past, bottle: bottles(:lagavulin), position: 1)
      other = Society.create!(name: "QC Society #{i}", description: "x", creator: users(:admin), is_private: i.even?)
      SocietyMembership.create!(user: member, society: other, role: "member", status: "active")
    end
    many = measure(dashboard_path)

    assert_operator many.size, :<=, few.size, "dashboard grew:\n#{growth(few, many)}"
  end
end
