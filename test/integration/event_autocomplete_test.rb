require "test_helper"

# The deck and host pickers are autocomplete fields backed by JSON endpoints.
# Those endpoints hand back deck titles and member names, so they are exactly
# as sensitive as the assignment actions they feed and must be gated the same.
class EventAutocompleteTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = users(:john)
    @outsider = users(:jane)
    @society = Society.create!(name: "Autocomplete Club", description: "x",
                               creator: @organizer, is_private: false)
    @event = Event.new(society: @society, organizer: @organizer, title: "Night",
                       description: "x", location: "den",
                       start_time: 1.day.from_now, end_time: 1.day.from_now + 2.hours)
    @event.save!(validate: false)
    @deck = Presentation.create!(author: @organizer, title: "Peat and Provenance",
                                 content: "x", price: 5)
    @deck.update_column(:published, true)
  end

  def json = JSON.parse(response.body)

  test "deck options search by title" do
    sign_in @organizer
    get deck_options_society_event_path(@society, @event), params: { q: "peat" }
    assert_response :success
    assert_equal [ "Peat and Provenance" ], json.map { |d| d["label"] }
    assert_equal @deck.id, json.first["id"]
  end

  test "deck options only offer decks this event could actually run" do
    other = Presentation.create!(author: @outsider, title: "Someone Else's Deck",
                                 content: "x", price: 5)
    other.update_column(:published, true)

    sign_in @organizer
    get deck_options_society_event_path(@society, @event), params: { q: "deck" }
    assert_empty json, "the picker must not offer a deck assign_deck would reject"
  end

  test "host options list active members" do
    sign_in @organizer
    get host_options_society_event_path(@society, @event), params: { q: "" }
    assert_includes json.map { |m| m["id"] }, @organizer.id
  end

  test "host options exclude people who aren't active members" do
    sign_in @organizer
    get host_options_society_event_path(@society, @event), params: { q: @outsider.full_name }
    assert_empty json, "the picker must not offer a host assign_host would reject"
  end

  # A search endpoint is a read of the same data, not a lesser thing.
  test "someone who cannot manage the event cannot enumerate its options" do
    sign_in @outsider

    get deck_options_society_event_path(@society, @event), params: { q: "" }
    assert_not_equal 200, response.status, "deck titles leak to a non-manager"

    get host_options_society_event_path(@society, @event), params: { q: "" }
    assert_not_equal 200, response.status, "member names leak to a non-manager"
  end

  test "a signed-out visitor gets nothing" do
    get host_options_society_event_path(@society, @event), params: { q: "" }
    assert_not_equal 200, response.status
  end

  test "the page renders autocomplete fields, not selects" do
    sign_in @organizer
    get society_event_path(@society, @event)
    assert_response :success

    assert_match 'data-controller="autocomplete"', response.body
    assert_match "presentation_id", response.body
    assert_match "host_id", response.body
    assert_no_match(/<select name="presentation_id"/, response.body)
    assert_no_match(/<select name="host_id"/, response.body)
  end

  # The blank option was how a dropdown unset these. An empty box has to keep
  # doing that, or a deck could be attached and never removed.
  test "submitting an empty box clears the deck and the host" do
    @event.update!(presentation: @deck, host: @organizer)
    sign_in @organizer

    patch assign_deck_society_event_path(@society, @event), params: { presentation_id: "" }
    assert_nil @event.reload.presentation

    patch assign_host_society_event_path(@society, @event), params: { host_id: "" }
    assert_nil @event.reload.host
  end
end
