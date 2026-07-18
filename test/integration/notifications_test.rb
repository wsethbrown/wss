require "test_helper"

# The in-app notification system: follows, review likes, and society event
# announcements land on the bell; visiting /notifications marks them read.
class NotificationsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @other = users(:jane)
  end

  test "following someone notifies them once, refollows do not stack" do
    sign_in @user
    2.times do
      post favorites_path, params: { favoritable_type: "User", favoritable_id: @other.id }
      delete favorite_path(@user.favorites.find_by(favoritable: @other)) if @user.favorites.exists?(favoritable: @other)
      post favorites_path, params: { favoritable_type: "User", favoritable_id: @other.id }
    end
    assert_equal 1, @other.notifications.where(action: "follow", actor: @user).count
  end

  test "liking a review notifies its author" do
    review = reviews(:john_eagle_rare)
    sign_in @other
    post review_votes_path, params: { review_id: review.id }
    assert review.user.notifications.exists?(action: "review_vote", actor: @other, notifiable: review)
  end

  test "voting your own review does not notify you" do
    review = reviews(:john_eagle_rare)
    sign_in review.user
    post review_votes_path, params: { review_id: review.id }
    assert_not review.user.notifications.exists?(action: "review_vote")
  end

  test "a new event notifies members even with event emails muted" do
    society = Society.create!(name: "Bell Club", description: "x", creator: @user, is_private: false)
    SocietyMembership.create!(user: @other, society: society, role: "member", status: "active")
    @other.update!(event_emails: false)
    st = 3.days.from_now
    event = Event.create!(society: society, organizer: @user, title: "Bell Night",
                          description: "x", location: "den", start_time: st, end_time: st + 2.hours)
    EventNotificationJob.perform_now(event.id, "created")
    assert @other.notifications.exists?(action: "event_created", notifiable: event)
    assert_not @user.notifications.exists?(action: "event_created"), "organizer is not notified"
  end

  test "the notifications page lists and marks read" do
    Notification.notify!(user: @user, actor: @other, notifiable: @other, action: "follow")
    sign_in @user
    assert_equal 1, @user.notifications.unread.count
    get notifications_path
    assert_response :success
    assert_match "followed you", response.body
    assert_equal 0, @user.notifications.unread.count
  end

  test "the bell badge shows unread count" do
    Notification.notify!(user: @user, actor: @other, notifiable: @other, action: "follow")
    sign_in @user
    get reviews_path
    assert_match ">1</span>", response.body
  end

  test "notifications require sign-in" do
    get notifications_path
    assert_response :redirect
  end
end
