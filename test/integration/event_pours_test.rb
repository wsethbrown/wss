require "test_helper"

class EventPoursTest < ActionDispatch::IntegrationTest
  test "event page lists the pours in order with labels and bottle links" do
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_response :success
    assert_match "The pours", response.body
    assert_match "Pour #1 — the blind", response.body
    body = response.body
    assert_operator body.index("Ardbeg 10"), :<, body.index("GlenDronach 12")
    assert_operator body.index("GlenDronach 12"), :<, body.index("Four Roses Small Batch")
    assert_select "a[href=?]", bottle_path(bottles(:ardbeg_10))
  end

  test "secret pours stay hidden from members and strangers until the night ends" do
    sign_in users(:seth) # RSVP'd member — still can't peek
    get society_event_path(societies(:single_malt), events(:mystery_flight))
    assert_response :success
    assert_match "The pours are a secret until the night ends", response.body
    assert_no_match "Lagavulin 16", response.body
  end

  test "the organizer sees secret pours early, flagged as secret" do
    sign_in users(:admin)
    get society_event_path(societies(:single_malt), events(:mystery_flight))
    assert_match "Lagavulin 16", response.body
    assert_match "Secret until the night ends", response.body
  end

  test "organizer adds a pour, appended at the end of the order" do
    sign_in users(:admin)
    event = events(:mystery_flight)
    assert_difference "EventBottle.count", 1 do
      post event_event_bottles_path(event),
           params: { event_bottle: { bottle_id: bottles(:eagle_rare).id, label: "The closer" } }
    end
    pour = event.event_bottles.ordered.last
    assert_equal bottles(:eagle_rare), pour.bottle
    assert_equal 2, pour.position
    assert_redirected_to society_event_path(event.society, event)
  end

  test "non-managers cannot touch the pour list" do
    sign_in users(:seth)
    assert_no_difference "EventBottle.count" do
      post event_event_bottles_path(events(:mystery_flight)),
           params: { event_bottle: { bottle_id: bottles(:eagle_rare).id } }
    end
    assert_response :redirect
  end

  test "organizer removes an unreviewed pour but not a reviewed one" do
    sign_in users(:admin)
    assert_difference "EventBottle.count", -1 do
      delete event_event_bottle_path(events(:mystery_flight), event_bottles(:mystery_flight_pour_one))
    end
    assert_no_difference "EventBottle.count" do
      delete event_event_bottle_path(events(:spring_blind), event_bottles(:spring_blind_pour_one))
    end
    assert_equal "Can't remove a pour that has reviews", flash[:alert]
  end

  test "organizer toggles the secret flag from the event page" do
    sign_in users(:admin)
    event = events(:mystery_flight)
    patch society_event_path(event.society, event),
          params: { event: { pours_hidden_until_complete: "false" } }
    assert_not event.reload.pours_hidden_until_complete?
  end

  test "add-a-bottle honors an internal return_to and ignores external ones" do
    sign_in users(:admin)
    event_page = society_event_path(societies(:single_malt), events(:mystery_flight))

    post bottles_path, params: { bottle: { name: "Springbank 10", distillery: "Springbank" },
                                 return_to: event_page }
    assert_redirected_to event_page

    post bottles_path, params: { bottle: { name: "Springbank 15", distillery: "Springbank" },
                                 return_to: "https://evil.example/phish" }
    assert_redirected_to bottle_path(Bottle.find_by!(name: "Springbank 15"))
  end
end
