require "test_helper"

# `rake users:purge_unused` (UnusedAccounts): finds accounts nobody ever used
# (the junk sign-ups a script created through /auth) and, only with CONFIRM=1,
# deletes them. Any single piece of identity or activity excludes a user.
class UnusedAccountsTest < ActiveSupport::TestCase
  def junk(email: "junk#{SecureRandom.hex(4)}@business.example", created_at: 3.days.ago, **attrs)
    user = User.create!(email: email, password: SecureRandom.alphanumeric(24), password_set_manually: false, **attrs)
    user.update_columns(created_at: created_at, updated_at: created_at)
    user
  end

  def candidate_ids(**opts) = UnusedAccounts.new(**opts).candidates.pluck(:id)

  def deck
    @deck ||= Presentation.create!(author: users(:admin), title: "Purge Test Deck", content: "A story.", price: 5)
  end

  test "a junk account is selected and, with confirm, deleted" do
    user = junk
    # The one sign-in a mail scanner made when it opened the link is not activity.
    ActivityLog.create!(user: user, activity_type: "login", metadata: { method: "magic_link" })

    assert_includes candidate_ids, user.id
    out = StringIO.new
    summary = UnusedAccounts.new.run(confirm: true, out: out)

    assert_not User.exists?(user.id)
    assert_equal 0, ActivityLog.where(user_id: user.id).count
    assert_equal 1, summary[:deleted]
    assert_match(/Deleted 1/, out.string)
  end

  test "real fixture accounts are never selected" do
    User.update_all(created_at: 3.days.ago) # past the 24-hour floor, so only the other criteria decide
    fixture_ids = %i[john seth admin].map { |k| users(k).id }
    assert_empty candidate_ids & fixture_ids
  end

  test "dry run deletes nothing and prints ids, dates and a histogram, never an email" do
    a = junk(email: "first.victim@business.example", created_at: Time.utc(2026, 8, 3, 12))
    b = junk(email: "second.victim@business.example", created_at: Time.utc(2026, 8, 3, 15))
    c = junk(email: "third.victim@business.example", created_at: Time.utc(2026, 9, 9, 1))
    out = StringIO.new
    logs = capture_log do
      assert_no_difference -> { User.count } do
        UnusedAccounts.new.run(confirm: false, out: out)
      end
    end

    text = out.string
    assert_match(/3 unused accounts/, text)
    assert_includes text, "user #{a.id}, created 2026-08-03"
    assert_includes text, "user #{c.id}, created 2026-09-09"
    assert_match(/2026-08-03\s+2\b/, text)
    assert_match(/2026-09-09\s+1\b/, text)
    assert_match(/dry run/i, text)
    [ a, b, c ].each { |u| assert_no_match(/#{Regexp.escape(u.email)}/, text + logs) }
    assert_no_match(/@/, text + logs)
  end

  test "deletion output and logs contain no email address" do
    user = junk(email: "deleted.victim@business.example")
    out = StringIO.new
    logs = capture_log { UnusedAccounts.new.run(confirm: true, out: out) }
    assert_match(/user #{user.id}/, logs)
    assert_no_match(/@/, out.string + logs)
  end

  test "CREATED_AFTER and CREATED_BEFORE narrow the selection" do
    aug = junk(created_at: Time.utc(2026, 8, 15))
    oct = junk(created_at: Time.utc(2026, 10, 15))
    assert_equal [ aug.id ], candidate_ids(created_after: Date.new(2026, 8, 1), created_before: Date.new(2026, 9, 1)) & [ aug.id, oct.id ]
    assert_equal [ oct.id ], candidate_ids(created_after: Date.new(2026, 10, 1)) & [ aug.id, oct.id ]
  end

  # --- each single piece of identity or activity excludes the user -----------

  EXCLUSIONS = {
    "a first name" => ->(u, _t) { u.update_columns(first_name: "Ann") },
    "a last name" => ->(u, _t) { u.update_columns(last_name: "Lee") },
    "a password set by hand" => ->(u, _t) { u.update_columns(password_set_manually: true) },
    "an OAuth provider" => ->(u, _t) { u.update_columns(provider: "google_oauth2", uid: "123") },
    "an inviter" => ->(u, t) { u.update_columns(invited_by_id: t.users(:admin).id) },
    "an accepted invitation" => ->(u, _t) { u.update_columns(invitation_accepted_at: 1.day.ago) },
    "a sent invitation" => ->(u, _t) { u.update_columns(invitation_sent_at: 1.day.ago, invitation_token_digest: "x" * 64) },
    "an admin role" => ->(u, _t) { u.update_columns(admin_role: "limited") },
    "a Stripe customer id" => ->(u, _t) { u.update_columns(stripe_customer_id: "cus_123") },
    "a Stripe subscription id" => ->(u, _t) { u.update_columns(stripe_subscription_id: "sub_123") },
    "a subscription status" => ->(u, _t) { u.update_columns(subscription_status: "canceled") },
    "a credit balance" => ->(u, _t) { u.update_columns(credits: 1) },
    "a credit transaction" => lambda { |u, _t|
      CreditTransaction.record!(user: u, amount: 1, transaction_type: CreditTransaction::TRANSACTION_TYPES[:granted])
      u.update_columns(credits: 0)
    },
    "a society membership" => ->(u, t) { SocietyMembership.create!(user: u, society: t.societies(:whiskey_lovers), role: "member", status: "active") },
    "an RSVP" => ->(u, t) { EventRsvp.new(user: u, event: t.events(:spring_blind), status: "yes").save!(validate: false) },
    "a review" => ->(u, t) { Review.create!(user: u, bottle: t.bottles(:four_roses_sb), rating: 4) },
    "a purchase" => ->(u, t) { UserPresentation.create!(user: u, presentation: t.deck, purchase_type: "direct", purchased_at: Time.current) },
    "a favourite of them" => ->(u, t) { Favorite.create!(user: t.users(:john), favoritable: u) },
    "a society invitation" => lambda { |u, t|
      SocietyInvitation.create!(society: t.societies(:whiskey_lovers), user: u, invited_by: t.users(:john), status: "pending")
    },
    "a non-sign-in activity log" => ->(u, _t) { ActivityLog.create!(user: u, activity_type: "profile_updated") },
    "a profile image" => lambda { |u, t|
      u.profile_image.attach(io: StringIO.new(t.file_fixture_png), filename: "a.png", content_type: "image/png")
    },
    "a magic link sent in the last 24 hours" => ->(u, _t) { u.update_columns(magic_link_sent_at: 1.hour.ago, magic_link_token: "y" * 64) },
    "creation within 24 hours" => ->(u, _t) { u.update_columns(created_at: 23.hours.ago) }
  }.freeze

  EXCLUSIONS.each do |what, apply|
    test "#{what} excludes the user" do
      user = junk
      assert_includes candidate_ids, user.id, "sanity: the bare account is a candidate"
      instance_exec(user, self, &apply)
      assert_not_includes candidate_ids, user.id

      UnusedAccounts.new.run(confirm: true, out: StringIO.new)
      assert User.exists?(user.id), "#{what}: the user must survive a confirmed purge"
    end
  end

  test "a user who gains activity after selection is skipped and reported, not deleted" do
    user = junk
    purge = UnusedAccounts.new
    ids = purge.candidates.pluck(:id)
    assert_includes ids, user.id
    SocietyMembership.create!(user: user, society: societies(:whiskey_lovers), role: "member", status: "active")

    out = StringIO.new
    summary = purge.run(confirm: true, out: out, ids: ids)
    assert User.exists?(user.id)
    assert_equal 1, summary[:skipped]
    assert_match(/Skipped user #{user.id}/, out.string)
  end

  test "every foreign key to users is checked" do
    conn = ActiveRecord::Base.connection
    fks = conn.tables.flat_map { |t| conn.foreign_keys(t).select { |fk| fk.to_table == "users" }.map { |fk| [ t, fk.column ] } }
    checked = UnusedAccounts.references.map { |r| [ r[:table], r[:column] ] }
    assert_empty fks - checked, "unchecked foreign keys: #{(fks - checked).inspect}"
    %w[activity_logs credit_transactions event_rsvps reviews society_memberships user_presentations download_logs].each do |t|
      assert_includes checked.map(&:first), t
    end
  end

  def file_fixture_png
    # 1x1 transparent PNG
    Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=")
  end

  private

  def capture_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end
end
