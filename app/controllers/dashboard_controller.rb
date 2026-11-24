# The signed-in landing page (finding 3): the member's next tastings across
# every society they belong to, what is waiting on them, and their societies.
# /account stays the account page.
#
# Everything is read through the privacy scopes (SocietyPolicy::Scope,
# EventPolicy::Scope) and loaded in a fixed number of queries, whatever the
# number of societies, events or pours (test/integration/query_counts_test.rb).
class DashboardController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_policy_scoped

  UPCOMING_LIMIT = 12
  PAST_NIGHTS_WINDOW = 90.days # pours older than this stop asking to be reviewed
  REVIEW_LIMIT = 8

  def index
    @societies = current_user.belonging_societies
                             .where(id: policy_scope(Society).select(:id))
                             .order(:name).to_a
    @society_roles = current_user.society_role_labels(@societies)
    society_ids = @societies.map(&:id)

    visible_events = policy_scope(Event).where(society_id: society_ids)
    @upcoming = visible_events.upcoming.includes(:society).limit(UPCOMING_LIMIT).to_a
    @answers = current_user.event_rsvps.where(event_id: @upcoming.map(&:id)).pluck(:event_id, :status).to_h
    @unanswered = @upcoming.reject { |event| @answers.key?(event.id) }

    @pours_to_review = pours_to_review(visible_events)

    Rails.logger.info "Dashboard for user #{current_user.id}: #{@societies.size} societies, " \
                      "#{@upcoming.size} upcoming (#{@unanswered.size} unanswered), #{@pours_to_review.size} pours to review"
  end

  private

  # Revealed pours from recent nights the member said yes to, minus the ones
  # they have already reviewed for that night (the same gates as Review).
  def pours_to_review(visible_events)
    yes_event_ids = current_user.event_rsvps.yes.select(:event_id)
    past_nights = visible_events.where(id: yes_event_ids)
                                .where(start_time: PAST_NIGHTS_WINDOW.ago..Time.current)
                                .to_a.select(&:pours_revealed?)
    return [] if past_nights.empty?

    reviewed = current_user.reviews.where(event_id: past_nights.map(&:id)).pluck(:event_id, :bottle_id).to_set
    EventBottle.where(event_id: past_nights.map(&:id))
               .includes(:bottle, event: :society)
               .order(:position, :id).to_a
               .reject { |pour| reviewed.include?([ pour.event_id, pour.bottle_id ]) }
               .sort_by { |pour| [ -pour.event.start_time.to_i, pour.position.to_i ] }
               .first(REVIEW_LIMIT)
  end
end
