require "test_helper"

# Which decks a night can run (owner decision, November 2026): a published deck
# that the organiser, the host, or an admin of the society (its creator and
# members with the admin role) can currently access under the existing access
# rule. Bought outright is forever; unlocked with a credit counts only while
# that person's membership is active. Authorship grants nothing on its own; a
# site admin organising the night keeps every deck through the admin rule.
class EventOfferableDecksTest < ActiveSupport::TestCase
  setup do
    @founder = users(:john)
    @organiser = users(:seth)
    @host = users(:jane)
    @plain_member = users(:one)
    @society = Society.create!(name: "Offerable Club", description: "x", creator: @founder, is_private: false)
    SocietyMembership.create!(user: @organiser, society: @society, role: "officer", status: "active")
    SocietyMembership.create!(user: @host, society: @society, role: "member", status: "active")
    SocietyMembership.create!(user: @plain_member, society: @society, role: "member", status: "active")
    @event = Event.new(society: @society, organizer: @organiser, host: @host, title: "Night", description: "x",
                       location: "den", start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours)
    @event.save!(validate: false)
  end

  def deck(title, author: users(:admin), published: true)
    Presentation.create!(author: author, title: title, content: "x", price: 5).tap do |d|
      d.update_column(:published, published)
    end
  end

  def own(user, deck, type)
    UserPresentation.create!(user: user, presentation: deck, purchase_type: type, purchased_at: Time.current)
  end

  def activate(user) = user.update_columns(subscription_status: "active", subscription_ends_at: nil)
  def lapse(user) = user.update_columns(subscription_status: "canceled")

  test "a deck the organiser unlocked with a credit is offerable while their membership is active" do
    d = deck("Peat Reek")
    own(@organiser, d, "credit")
    activate(@organiser)
    assert_includes @event.offerable_decks, d
    assert @event.deck_offerable?(d.id)
  end

  test "a credit unlock stops counting when that membership lapses" do
    d = deck("Peat Reek")
    own(@organiser, d, "credit")
    lapse(@organiser)
    assert_not_includes @event.offerable_decks, d
    assert_not @event.deck_offerable?(d.id)
  end

  test "a deck bought outright counts forever, for the host too" do
    d = deck("Bought Outright")
    own(@host, d, "direct")
    lapse(@host)
    assert_includes @event.offerable_decks, d
  end

  test "the society creator and society admins count" do
    founder_deck = deck("Founder's")
    admin_deck = deck("Admin's")
    other_admin = users(:limited_admin)
    SocietyMembership.create!(user: other_admin, society: @society, role: "admin", status: "active")
    own(@founder, founder_deck, "direct")
    own(other_admin, admin_deck, "direct")
    assert_includes @event.offerable_decks, founder_deck
    assert_includes @event.offerable_decks, admin_deck
  end

  test "a plain member's deck does not count" do
    d = deck("Member's")
    own(@plain_member, d, "direct")
    assert_not_includes @event.offerable_decks, d
  end

  test "authorship alone grants nothing" do
    d = deck("Authored", author: @organiser)
    assert_not_includes @event.offerable_decks, d
  end

  test "a society founded by a site admin does not offer every deck" do
    admin_founded = Society.create!(name: "Admin Founded", description: "x", creator: users(:admin), is_private: false)
    SocietyMembership.create!(user: @organiser, society: admin_founded, role: "officer", status: "active")
    night = Event.new(society: admin_founded, organizer: @organiser, title: "N", description: "x", location: "den",
                      start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours)
    night.save!(validate: false)
    unowned = deck("Nobody Owns This")
    assert_not_includes night.offerable_decks, unowned
  end

  test "a site admin organising the night keeps every published deck" do
    @event.update_columns(organizer_id: users(:admin).id)
    published = deck("Any Deck")
    draft = deck("Draft", published: false)
    offered = @event.reload.offerable_decks
    assert_includes offered, published
    assert_not_includes offered, draft
  end

  test "unpublished decks are never offerable, owned or not" do
    d = deck("Draft", published: false)
    own(@organiser, d, "direct")
    assert_not_includes @event.offerable_decks, d
  end

  test "the deck already attached stays selectable" do
    d = deck("Attached Earlier")
    @event.update_columns(presentation_id: d.id)
    assert_includes @event.reload.offerable_decks, d
    assert_not_includes @event.offerable_decks(include_current: false), d
  end

  test "a new event uses the person creating it as organiser" do
    d = deck("Mine")
    own(@organiser, d, "direct")
    fresh = Event.new(society: @society)
    assert_includes fresh.offerable_decks(organizer: @organiser), d
    assert_not_includes fresh.offerable_decks(organizer: @plain_member), d
  end
end
