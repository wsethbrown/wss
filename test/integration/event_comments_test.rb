require "test_helper"

class EventCommentsTest < ActionDispatch::IntegrationTest
  setup do
    @open_event = events(:mystery_flight)   # single_malt, upcoming
    @closed_event = events(:spring_blind)   # single_malt, ended 3 weeks ago
    @society = societies(:single_malt)
  end

  test "member can post a comment on an open event" do
    sign_in users(:john)
    assert_difference "EventComment.count", 1 do
      post event_comments_path(@open_event), params: { event_comment: { body: "Bringing the Weller." } }
    end
    assert_redirected_to society_event_path(@society, @open_event, anchor: "table-talk")
    assert_equal "Bringing the Weller.", @open_event.event_comments.last.body
  end

  test "non-member cannot post" do
    sign_in users(:jane)
    assert_no_difference "EventComment.count" do
      post event_comments_path(@open_event), params: { event_comment: { body: "Drive-by." } }
    end
  end

  test "cannot post more than a week after the event" do
    sign_in users(:john)
    assert_no_difference "EventComment.count" do
      post event_comments_path(@closed_event), params: { event_comment: { body: "Too late." } }
    end
  end

  test "blank comment is rejected" do
    sign_in users(:john)
    assert_no_difference "EventComment.count" do
      post event_comments_path(@open_event), params: { event_comment: { body: " " } }
    end
  end

  test "author can delete their comment" do
    sign_in users(:john)
    comment = EventComment.create!(event: @open_event, user: users(:john), body: "Oops.")
    assert_difference "EventComment.count", -1 do
      delete event_comment_path(@open_event, comment)
    end
  end

  test "another member cannot delete someone else's comment" do
    comment = EventComment.create!(event: @open_event, user: users(:john), body: "Mine.")
    sign_in users(:seth)
    assert_no_difference "EventComment.count" do
      delete event_comment_path(@open_event, comment)
    end
  end

  test "organizer can delete any comment" do
    comment = EventComment.create!(event: @open_event, user: users(:john), body: "Moderate me.")
    sign_in users(:admin)
    assert_difference "EventComment.count", -1 do
      delete event_comment_path(@open_event, comment)
    end
  end

  test "event page shows the section with the form for members while open" do
    sign_in users(:john)
    EventComment.create!(event: @open_event, user: users(:seth), body: "Can't wait.")
    get society_event_path(@society, @open_event)
    assert_response :success
    section = css_select("#table-talk").first
    assert section, "expected #table-talk section"
    assert_includes section.text, "Table talk"
    assert_includes section.text, "Can't wait."
    # Assert the box is there by a stable hook, not its placeholder copy,
    # which changes whenever the prompt is reworded.
    assert_select "#table-talk textarea[data-mention-autocomplete-target=?]", "input"
  end

  test "closed event shows comments but no form, with the closed note" do
    sign_in users(:john)
    get society_event_path(@society, @closed_event)
    assert_select "#table-talk textarea", count: 0
    assert_includes css_select("#table-talk").first.text, "Comments close a week after the night."
  end

  test "non-member sees comments but no form" do
    EventComment.create!(event: @open_event, user: users(:john), body: "Members only chatter.")
    sign_in users(:jane)
    get society_event_path(@society, @open_event)
    assert_includes css_select("#table-talk").first.text, "Members only chatter."
    assert_select "#table-talk textarea", count: 0
  end
end
