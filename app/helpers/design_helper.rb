# Small building blocks from the 2026 design system (docs/redesign/DESIGN_SYSTEM.md).
module DesignHelper
  # A link's words followed by its arrow, the arrow in its own span so it can
  # nudge on hover (application.css, .arrow). The text reads exactly as
  # "words →", so the link's accessible name does not change.
  def with_arrow(text)
    safe_join([ text, " ", content_tag(:span, "→", class: "arrow") ])
  end

  # A deck's cover: its first rendered slide, else its featured image, else a plain
  # green block. Always 16:9, 18px radius, hairline edge. Never the title on a box.
  #
  # Options:
  #   preloaded: an already-loaded attachment to show (skips the slide query)
  #   class:     extra classes for the wrapper
  #   alt:       alt text (defaults to the deck title)
  #   loading:   "lazy" (default) or "eager", for covers above the fold
  def deck_cover(deck, preloaded: nil, class: nil, alt: nil, loading: "lazy")
    extra = binding.local_variable_get(:class)
    wrapper = [ "deck-cover relative aspect-video w-full overflow-hidden rounded-[18px] border border-hairline bg-char", extra ].compact.join(" ")
    image = preloaded || deck_cover_attachment(deck)

    content_tag(:div, class: wrapper) do
      if image
        # Fades in if it is still loading when the page starts (the appear
        # controller's image target; cached covers are left alone).
        image_tag image_variant(image, :card), alt: alt || deck.title, loading: loading,
                  class: "absolute inset-0 h-full w-full object-cover motion-safe:transition-transform motion-safe:duration-300 motion-safe:group-hover:scale-[1.02]",
                  data: { appear_target: "image" }
      else
        content_tag(:div, class: "flex h-full w-full items-center justify-center") do
          render("shared/glass", level: 0, size: 52, tone: :cream, appear: false, css: "opacity-30")
        end
      end
    end
  end

  # The named variant of an attachment (:card, :hero, :avatar, :thumb), so pages never
  # serve the full-size upload. Falls back to the attachment itself only when it
  # cannot be transformed (a type libvips will not resize); that case is logged.
  def image_variant(attachment, name)
    return attachment unless attachment.respond_to?(:variable?)
    return attachment.variant(name) if attachment.variable?

    Rails.logger.warn "[image_variant] #{attachment.blob&.content_type.inspect} is not variable; serving the original (attachment #{attachment.try(:id)})"
    attachment
  end

  # The attachment deck_cover would show, or nil. One query at most; none when the
  # slide association was preloaded.
  def deck_cover_attachment(deck)
    if deck.slide_images.attached?
      attachments = deck.slide_images_attachments
      first = attachments.loaded? ? attachments.min_by(&:id) : attachments.order(:id).first
      return first if first
    end
    deck.featured_image if deck.featured_image.attached?
  end

  # A person's avatar: their profile image, else initials on a paper-green circle.
  # size is in pixels.
  def avatar(user, size: 40, class: nil)
    extra = binding.local_variable_get(:class)
    classes = [ "shrink-0 rounded-full", extra ].compact.join(" ")
    style = "width: #{size.to_i}px; height: #{size.to_i}px;"

    if user.profile_image.attached?
      image_tag image_variant(user.profile_image, :avatar), alt: user.display_name, class: "#{classes} object-cover", style: style
    else
      content_tag(:span, user.initials,
                  class: "#{classes} inline-flex items-center justify-center bg-whiskey-100 font-semibold text-ink",
                  style: "#{style} font-size: #{(size.to_i * 0.4).round}px;",
                  title: user.display_name, "aria-label": user.display_name)
    end
  end
end
