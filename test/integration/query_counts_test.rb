require "test_helper"

# B16 (I15, I22, I28, M21): the pages that render many rows must not issue more
# queries when there are more rows. Each test measures a page with a few rows,
# adds many more, and asserts the count did not grow.
class QueryCountsTest < ActionDispatch::IntegrationTest
  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")

  # Views allowed to show an original on purpose, or waiting on their owning task:
  #  - societies/edit.html.erb: the banner cropper edits the full-size original, on purpose.
  #  - presentations/show.html.erb: B17 owns it; its slide image_tag and og:image still need the
  #    variants (see the B16 hand-back).
  EXEMPT_FROM_VARIANT_RULE = %w[societies/edit.html.erb presentations/show.html.erb].freeze

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
end
