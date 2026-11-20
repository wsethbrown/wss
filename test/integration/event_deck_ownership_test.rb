require "test_helper"

# The three places a deck meets a night (the creation form, the deck_options
# autocomplete and the server-side checks on create/assign) share one rule:
# Event#offerable_decks.
class EventDeckOwnershipTest < ActionDispatch::IntegrationTest
  setup do
    @founder = users(:seth)
    @founder.update_columns(subscription_status: "active", subscription_ends_at: nil)
    @society = Society.create!(name: "Peat Club", description: "x", creator: @founder, is_private: false)
    @owned = Presentation.create!(author: users(:admin), title: "Peat Reek", content: "x", price: 5)
    @owned.update_column(:published, true)
    @unowned = Presentation.create!(author: users(:admin), title: "Rye Country", content: "x", price: 5)
    @unowned.update_column(:published, true)
    UserPresentation.create!(user: @founder, presentation: @owned, purchase_type: "credit", purchased_at: Time.current)
    @event = Event.new(society: @society, organizer: @founder, title: "Islay night", description: "x",
                       location: "den", start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours)
    @event.save!(validate: false)
    sign_in @founder
  end

  test "deck options offer the credit-owned deck and nothing nobody here owns" do
    get deck_options_society_event_path(@society, @event), params: { q: "" }
    assert_response :success
    assert_equal [ "Peat Reek" ], JSON.parse(response.body).map { |d| d["label"] }
  end

  test "the founder can attach the deck they unlocked" do
    patch assign_deck_society_event_path(@society, @event), params: { presentation_id: @owned.id }
    assert_equal @owned, @event.reload.presentation
  end

  test "a forged deck id on assign is refused and logged" do
    logs = capture_logs do
      patch assign_deck_society_event_path(@society, @event), params: { presentation_id: @unowned.id }
    end
    assert_nil @event.reload.presentation
    assert_match(/deck #{@unowned.id} refused/, logs)
  end

  test "the new-event form offers the deck field with owned decks only" do
    get new_society_event_path(@society)
    assert_response :success
    assert_select "select[name='event[presentation_id]']" do
      assert_select "option", text: "Peat Reek"
      assert_select "option", text: "Rye Country", count: 0
    end
  end

  test "creating a night with an owned deck keeps it; a forged one is dropped and logged" do
    params = { society_id: @society.id, title: "Owned deck night", description: "x", location: "den",
               start_time: 4.days.from_now, end_time: 4.days.from_now + 2.hours }
    post society_events_path(@society), params: { event: params.merge(presentation_id: @owned.id) }
    assert_equal @owned, Event.find_by(title: "Owned deck night").presentation

    logs = capture_logs do
      post society_events_path(@society), params: { event: params.merge(title: "Forged deck night", presentation_id: @unowned.id) }
    end
    assert_nil Event.find_by(title: "Forged deck night").presentation
    assert_match(/deck #{@unowned.id} dropped/, logs)
  end

  private

  def capture_logs
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end
end
