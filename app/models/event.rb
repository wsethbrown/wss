class Event < ApplicationRecord
  belongs_to :society
  belongs_to :organizer, class_name: "User"
  # Per-event host: a society member given the night. Assigned by society
  # admins/the organizer; sees this event's RSVP replies and joins the RSVP
  # emails, but gains no other management rights.
  belongs_to :host, class_name: "User", optional: true
  # The deck presented that night. OPTIONAL by owner rule: events without a
  # WSS deck are first-class. host_name is the guest-presenter fallback when
  # the host isn't a member (host_id wins whenever both are set).
  belongs_to :presentation, optional: true

  # Decks this night can run (owner decision, November 2026): published decks
  # that the organiser, the host or an admin of the society (its creator and
  # active members with the admin role) can access right now. Access is the
  # existing rule, never a fork of it: the organiser goes through
  # Presentation#can_download_full_presentation? (so a site admin organising
  # the night keeps every deck), everyone else through
  # User#can_access_presentation? (bought outright is forever; a credit unlock
  # counts only while that person's membership is active). Authorship grants
  # nothing. The deck already attached stays selectable unless
  # include_current is false (create, where it is the value being checked).
  #
  # The one rule behind the creation form, the deck_options autocomplete and
  # the server-side checks on create and assign_deck.
  def offerable_decks(organizer: self.organizer, include_current: true)
    decks =
      if organizer&.admin?
        Presentation.published.order(:title).to_a
      else
        offerers = deck_offerers(organizer)
        candidates = Presentation.published
                                 .where(id: UserPresentation.where(user_id: offerers.map(&:id)).select(:presentation_id))
                                 .order(:title).to_a
        candidates.select do |deck|
          (organizer && deck.can_download_full_presentation?(organizer)) ||
            offerers.any? { |person| person != organizer && person.can_access_presentation?(deck.id) }
        end
      end
    decks |= [ presentation ] if include_current && presentation
    decks
  end

  def deck_offerable?(presentation_id, organizer: self.organizer, include_current: true)
    return false if presentation_id.blank?
    offerable_decks(organizer: organizer, include_current: include_current).any? { |deck| deck.id == presentation_id.to_i }
  end

  # The display name for whoever runs the night, member or guest.
  def host_display_name
    host&.full_name.presence || host_name.presence
  end

  # The zone an event's times are meant in (B15). Set from the organiser's
  # browser zone at create; events with none stored fall back to this.
  FALLBACK_TIME_ZONE = "America/New_York".freeze

  def effective_time_zone
    (time_zone.present? && ActiveSupport::TimeZone[time_zone]) || ActiveSupport::TimeZone[FALLBACK_TIME_ZONE]
  end

  # "Thursday, January 14 at 7:30 PM EST", independent of the ambient Time.zone
  # (mail renders in the jobs process, where that is UTC).
  def start_time_label
    local_start.strftime("%A, %B %-d at %-l:%M %p %Z")
  end

  # B15b: a viewer's-zone label ("4:30 PM PST") and, only when the viewer's zone
  # has a different offset at the start time, the event-zone label
  # ("7:30 PM EST"). Zones are compared by offset, so Chicago/Mexico City do not
  # produce a redundant note.
  def start_clock_label(zone = effective_time_zone)
    start_time.in_time_zone(zone).strftime("%-l:%M %p %Z")
  end

  def event_zone_label_for(viewer_zone)
    viewer = viewer_zone.is_a?(ActiveSupport::TimeZone) ? viewer_zone : ActiveSupport::TimeZone[viewer_zone.to_s]
    return nil if viewer.nil?
    return nil if viewer.at(start_time).utc_offset == effective_time_zone.at(start_time).utc_offset
    start_clock_label
  end

  # The people whose decks the night may run: the organiser, the host and the
  # society's admins (creator plus active admin-role members).
  def deck_offerers(organizer = self.organizer)
    ids = [ organizer&.id, host_id ]
    if society
      ids << society.creator_id
      ids.concat(society.society_memberships.where(role: "admin", status: "active").pluck(:user_id))
    end
    User.where(id: ids.compact.uniq).to_a
  end

  def start_date_label
    local_start.strftime("%A, %B %-d")
  end

  # Associations
  has_many :event_rsvps, dependent: :destroy
  has_many :attendees, through: :event_rsvps, source: :user
  # Reviews are members' words, an event that has them can't be deleted.
  has_many :reviews, dependent: :restrict_with_error
  has_many :event_bottles, dependent: :destroy
  has_many :pour_bottles, through: :event_bottles, source: :bottle
  has_many :event_comments, dependent: :destroy

  # Validations
  validates :title, presence: true, length: { minimum: 2, maximum: 200 }
  validates :description, length: { maximum: 2000 }
  validates :location, length: { maximum: 200 }
  validates :start_time, presence: true
  validate :time_zone_is_known
  validates :end_time, presence: true
  validate :end_time_after_start_time

  # Scopes
  scope :upcoming, -> { where("start_time > ?", Time.current).order(:start_time) }
  scope :past, -> { where("start_time < ?", Time.current).order(start_time: :desc) }
  scope :today, -> { where(start_time: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(start_time: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :by_society, ->(society_id) { where(society_id: society_id) if society_id.present? }
  scope :search, ->(query) { where("title ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%") if query.present? }

  # Instance methods
  def yes_attendees
    User.joins(:event_rsvps).where(event_rsvps: { event_id: id, status: "yes" })
  end

  def maybe_attendees
    User.joins(:event_rsvps).where(event_rsvps: { event_id: id, status: "maybe" })
  end

  def no_attendees
    User.joins(:event_rsvps).where(event_rsvps: { event_id: id, status: "no" })
  end

  def yes_count
    event_rsvps.where(status: "yes").count
  end

  def maybe_count
    event_rsvps.where(status: "maybe").count
  end

  def no_count
    event_rsvps.where(status: "no").count
  end

  # Legacy method for compatibility - returns "Yes" attendees
  def confirmed_attendees
    yes_attendees
  end

  def confirmed_attendee_count
    yes_count
  end

  def total_rsvp_count
    event_rsvps.count
  end

  def potential_attendees
    society.members
  end

  def unanswered_count
    # Get society members who haven't RSVPd
    society.members.where.not(id: event_rsvps.select(:user_id)).count
  end

  def unanswered_users
    society.members.where.not(id: event_rsvps.select(:user_id))
  end

  def upcoming?
    start_time > Time.current
  end

  def past?
    start_time < Time.current
  end

  def ongoing?
    start_time <= Time.current && end_time >= Time.current
  end

  def duration
    return nil unless start_time && end_time
    (end_time - start_time) / 1.hour
  end

  # The RSVP window (owner decision, November 2026). Answers can be given,
  # changed or withdrawn until the event starts. A NEW yes (from someone not
  # currently at yes) closes YES_CUTOFF before the start to protect the
  # headcount, except for events created less than YES_CUTOFF before their
  # start ("drinks tonight"), which take yeses until they start.
  YES_CUTOFF = 24.hours

  # Every answer is closed: the night has started.
  def rsvp_closed?
    start_time <= Time.current
  end

  # Whether the last-day cutoff applies to this event at all.
  def yes_cutoff_applies?
    created_at.nil? || start_time - created_at >= YES_CUTOFF
  end

  # A new yes can no longer be given (maybe and no still can, until the start).
  def new_yes_closed?
    rsvp_closed? || (yes_cutoff_applies? && start_time <= YES_CUTOFF.from_now)
  end

  # Whether moving from current_status to status is allowed right now.
  def answer_allowed?(status, current_status = nil)
    return false if rsvp_closed?
    return true unless status.to_s == "yes"
    current_status.to_s == "yes" || !new_yes_closed?
  end

  # OWNER DECISION POINT (B1, Nov 2026): may signed-in NON-members RSVP to
  # events of PUBLIC societies? Default `true` keeps today's behaviour; flip to
  # `false` to require society membership for every event. Private societies
  # always require membership, whatever this says.
  PUBLIC_EVENTS_OPEN_TO_NON_MEMBERS = true

  # Whether this person may answer this event at all (window aside): the
  # society's active members, its creator and the organizer; for a public
  # society, anyone signed in while the switch above is on. Shared by the
  # on-site RSVP (via can_rsvp? / EventRsvpPolicy) and the emailed RSVP link.
  def rsvp_eligible?(user)
    return false unless user && society
    return true if organizer_id == user.id || society.creator_id == user.id || society.has_member?(user)

    society.public? && PUBLIC_EVENTS_OPEN_TO_NON_MEMBERS
  end

  def can_rsvp?(user)
    return false unless user
    return false if past? || rsvp_closed?
    return false unless rsvp_eligible?(user)
    !event_rsvps.exists?(user: user)
  end

  def user_rsvp_status(user)
    return nil unless user
    rsvp = event_rsvps.find_by(user: user)
    rsvp&.status
  end

  # --- Pours (review system Phase 2) ---

  # Secret pours auto-reveal once the night ends; non-secret pours are
  # always revealed (even before the event happens).
  def pours_revealed?
    !pours_hidden_until_complete? || (end_time.present? && end_time <= Time.current)
  end

  # The host sees hidden pours too: they set the list, so the secret toggle
  # cannot blind them (review gating still keys on pours_revealed? alone).
  def pours_visible_to?(user)
    pours_revealed? || managed_by?(user) || (user && host_id == user.id)
  end

  # Table talk stays open until a week after the night ends.
  def comments_open?
    Time.current <= end_time + 7.days
  end

  # Mirrors EventPolicy#update?, the people who run the night.
  def managed_by?(user)
    return false unless user

    user.admin? || organizer_id == user.id || society.has_admin?(user)
  end

  private

  def local_start
    start_time.in_time_zone(effective_time_zone)
  end

  def time_zone_is_known
    return if time_zone.blank? || ActiveSupport::TimeZone[time_zone]
    errors.add(:time_zone, "is not a known time zone")
  end

  def end_time_after_start_time
    return unless start_time && end_time
    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end
