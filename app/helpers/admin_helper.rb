# View helpers for the admin shell (layouts/admin.html.erb) and the pattern
# partials in app/views/admin/shared. Everything here is presentation only:
# no authorisation decisions (those stay in Admin::BaseController and the
# `current_user.can_delete?` checks in views).
module AdminHelper
  # The sidebar, in groups. Each item: label, path, icon (SVG path data), and the
  # path prefixes that count as "inside" the section (so nested pages such as
  # /admin/credits/transactions mark Credits as current).
  def admin_nav_groups
    [
      [ nil, [
        { label: "Dashboard", path: admin_root_path, match: [ "/admin/dashboard" ],
          icon: "M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" }
      ] ],
      [ "Content", [
        { label: "Decks", path: admin_presentations_path, match: [ "/admin/presentations", "/admin/deck_packages" ],
          icon: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" },
        { label: "Bottles", path: admin_bottles_path, match: [ "/admin/bottles" ],
          icon: "M9 3v2m6-2v2M5 7h14M5 7l1 12a2 2 0 002 2h8a2 2 0 002-2l1-12M5 7h14" },
        { label: "Moderation", path: admin_moderation_path, match: [ "/admin/moderation", "/admin/review_reports" ],
          icon: "M3 21v-4m0 0V5a2 2 0 012-2h6.5l1 1H21l-3 6 3 6h-8.5l-1-1H5a2 2 0 00-2 2z" }
      ] ],
      [ "People", [
        { label: "Users", path: admin_users_path, match: [ "/admin/users", "/admin/invitations" ],
          icon: "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" },
        { label: "Subscriptions", path: admin_subscriptions_path, match: [ "/admin/subscriptions", "/admin/create_subscription" ],
          icon: "M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" },
        { label: "Credits", path: admin_credits_path, match: [ "/admin/credits" ],
          icon: "M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" },
        { label: "Mailing list", path: admin_mailing_list_path, match: [ "/admin/mailing_list" ],
          icon: "M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" }
      ] ],
      [ "Reports", [
        { label: "Reviews", path: admin_reviews_analytics_path, match: [ "/admin/analytics/reviews" ],
          icon: "M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" },
        { label: "Activity", path: admin_activities_path, match: [ "/admin/activities" ],
          icon: "M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" },
        { label: "Analytics", path: admin_downloads_analytics_path, match: [ "/admin/analytics/downloads", "/admin/analytics/presentations" ],
          icon: "M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" }
      ] ]
    ]
  end

  # True when the current request is inside this sidebar item's section.
  def admin_nav_current?(item)
    path = request.path
    return true if path == item[:path]
    item[:match].any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
  end

  # The label of the current section, for the phone top bar. Nil when none matches.
  def admin_current_section
    admin_nav_groups.flat_map(&:last).find { |item| admin_nav_current?(item) }&.dig(:label)
  end

  # Shared classes so every admin form and table looks the same.
  # Inputs, selects and textareas: f.text_field :name, class: admin_field_class
  def admin_field_class
    "block w-full rounded-2xl border border-hairline bg-white px-4 py-3 text-sm text-gray-900 placeholder:text-mute/70 focus:border-ink/40 focus:outline-none focus:ring-2 focus:ring-ink/30"
  end

  # Labels above inputs: f.label :name, class: admin_label_class
  def admin_label_class
    "mb-1.5 block text-sm font-medium text-ink"
  end

  # A table cell for admin/shared/_table rows. align: :right for numbers and
  # row actions (adds tabular-nums). Pass content or a block.
  #   admin_td(user.credits, align: :right)
  #   admin_td { link_to user.full_name, admin_user_path(user) }
  def admin_td(content = nil, align: :left, **options, &block)
    classes = [ "px-4 py-3 align-middle text-sm" ]
    classes << "text-right tabular-nums whitespace-nowrap" if align == :right
    classes << options.delete(:class) if options[:class]
    content_tag(:td, content, class: classes.join(" "), **options, &block)
  end

  # A quiet text link for row actions and card headers ("View", "Edit", "All →").
  def admin_link_class
    "font-semibold text-ink underline-offset-4 hover:underline"
  end
end
