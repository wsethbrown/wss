require "test_helper"

# Tagging a member in Table talk. The comment stays plain text; a handle is
# resolved on save (to notify) and on display (to link), and resolution fails
# CLOSED so a tag never points at, or notifies, the wrong person.
class EventMentionsTest < ActionDispatch::IntegrationTest
  setup do
    @author = users(:john)
    @ethan = User.create!(email: "ethan@example.com", password: "password123",
                          first_name: "Ethan", last_name: "Frank")
    @society = Society.create!(name: "Mention Club", description: "x",
                               creator: @author, is_private: false)
    [ @author, @ethan ].each do |user|
      SocietyMembership.find_or_create_by!(society: @society, user: user) do |m|
        m.role = "member"
        m.status = "active"
      end
    end
    @event = Event.new(society: @society, organizer: @author, title: "Tasting Night",
                       description: "x", location: "den",
                       start_time: 1.hour.ago, end_time: 30.minutes.ago)
    @event.save!(validate: false)
  end

  def post_comment(body, as: @author)
    sign_in as
    post event_comments_path(@event), params: { event_comment: { body: body } }
  end

  test "a handle resolves to the member and notifies them" do
    assert_difference "Notification.where(action: 'mention').count", 1 do
      post_comment("Thanks for hosting @EthanFrank")
    end

    note = Notification.where(action: "mention").last
    assert_equal @ethan, note.user
    assert_equal @author, note.actor
    assert_equal EventComment.last, note.notifiable
  end

  test "the tag renders as a link to the member" do
    post_comment("Thanks for hosting @EthanFrank")
    get society_event_path(@society, @event)

    assert_select "a[href=?]", profile_path(@ethan), text: "@EthanFrank"
  end

  test "matching is case-insensitive but renders the member's real handle" do
    post_comment("cheers @ethanfrank")
    get society_event_path(@society, @event)

    assert_select "a[href=?]", profile_path(@ethan), text: "@EthanFrank"
  end

  test "a handle nobody has stays plain text and notifies nobody" do
    assert_no_difference "Notification.where(action: 'mention').count" do
      post_comment("Thanks @NobodyAtAll")
    end

    get society_event_path(@society, @event)
    assert_select "a", text: "@NobodyAtAll", count: 0
    assert_match "@NobodyAtAll", response.body, "the text the author typed must survive"
  end

  # Handles are derived from names, so they are not unique. Guessing between
  # two people of the same name is worse than not linking (owner decision).
  test "an ambiguous handle links to nobody and notifies nobody" do
    twin = User.create!(email: "ethan2@example.com", password: "password123",
                        first_name: "Ethan", last_name: "Frank")
    SocietyMembership.create!(society: @society, user: twin, role: "member", status: "active")

    assert_no_difference "Notification.where(action: 'mention').count" do
      post_comment("Thanks @EthanFrank")
    end

    get society_event_path(@society, @event)
    assert_select "a", text: "@EthanFrank", count: 0
  end

  test "someone outside the society cannot be tagged" do
    outsider = users(:jane)
    assert_not @society.has_member?(outsider)

    assert_no_difference "Notification.where(action: 'mention').count" do
      post_comment("Hello @#{outsider.handle}")
    end
  end

  test "an email address in a comment is not a mention" do
    assert_no_difference "Notification.where(action: 'mention').count" do
      post_comment("mail me at someone@example.com")
    end
  end

  test "tagging yourself notifies nobody" do
    assert_no_difference "Notification.where(action: 'mention').count" do
      post_comment("note to self @#{@author.handle}")
    end
  end

  # The body is escaped BEFORE mentions are linked. Reversing that order would
  # let a comment inject markup.
  test "a comment cannot inject markup through the mention renderer" do
    post_comment("<script>alert(1)</script> hi @EthanFrank")
    get society_event_path(@society, @event)

    assert_no_match "<script>alert(1)</script>", response.body
    assert_match "&lt;script&gt;", response.body
    assert_select "a[href=?]", profile_path(@ethan), text: "@EthanFrank"
  end

  test "the mention endpoint offers taggable members to a commenter" do
    sign_in @author
    get mention_options_society_event_path(@society, @event), params: { q: "eth" }
    assert_response :success

    match = JSON.parse(response.body).find { |m| m["id"] == @ethan.id }
    assert_equal "EthanFrank", match["handle"]
    assert_equal "Ethan Frank", match["name"]
  end

  test "the endpoint hides handles that would be ambiguous" do
    twin = User.create!(email: "ethan3@example.com", password: "password123",
                        first_name: "Ethan", last_name: "Frank")
    SocietyMembership.create!(society: @society, user: twin, role: "member", status: "active")

    sign_in @author
    get mention_options_society_event_path(@society, @event), params: { q: "eth" }
    assert_empty JSON.parse(response.body),
                 "offering a handle that resolves to nobody would be a trap"
  end

  test "a non-member cannot enumerate who is taggable" do
    sign_in users(:jane)
    get mention_options_society_event_path(@society, @event), params: { q: "" }
    assert_not_equal 200, response.status, "member names leak to someone who can't comment"
  end
end
