module PresentationsHelper
  # Renders deck content (authored as Markdown) to sanitized HTML.
  #
  # The renderer strips any raw HTML in the source (filter_html) and the output
  # is passed through Rails' sanitizer with an explicit allowlist, so author
  # content can never inject script/style into the page.
  def render_markdown(text)
    return "".html_safe if text.blank?

    # No hard_wrap: authors hard-wrap their Markdown source, and turning every
    # newline into <br> shredded paragraphs into ragged lines. Standard
    # Markdown treats single newlines as soft.
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      link_attributes: { rel: "noopener noreferrer", target: "_blank" }
    )
    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      no_intra_emphasis: true,
      lax_spacing: true
    )

    sanitize(
      markdown.render(text),
      tags: %w[h1 h2 h3 h4 h5 h6 p br hr em strong del a ul ol li blockquote code pre
               table thead tbody tr th td img],
      attributes: %w[href rel target src alt]
    )
  end

  # A teaser of the deck's story for readers without access: roughly the first
  # third of the source, cut at a line boundary so the Markdown still parses.
  # Truncating the SOURCE (not hiding rendered HTML with CSS) means the rest of
  # the story never reaches the page at all.
  def preview_markdown(text, max_lines: 24)
    return "".html_safe if text.blank?

    lines = text.lines
    teaser = lines.first(max_lines).join
    render_markdown(teaser)
  end

  # True when the teaser actually hides something (no fade/CTA otherwise).
  def story_truncated?(text, max_lines: 24)
    text.present? && text.lines.count > max_lines
  end

  # The deck page's sections: the heading in the narrow column, the content in
  # the wide one. Shared by every section partial (presentations/show and the
  # admin's "What the customer sees" preview render the same partials).
  def deck_section_class
    "grid gap-6 border-t border-hairline py-12 md:grid-cols-12 md:gap-10"
  end

  def deck_heading_class
    "font-display text-2xl font-semibold text-ink sm:text-3xl"
  end

  # A line shaped "Label: text" (a label of up to 24 characters, a colon and a
  # space) is a labelled row.
  SECTION_LABELLED_LINE = /\A([^:]{1,24}): +(\S.*)\z/

  # How one extra section renders, the one rule for every page that shows it:
  #   [:paragraph, line]  its only line is a plain line: a short paragraph
  #   [:rows, rows]       otherwise a list of rows, each [label, text], where
  #                       label is nil for a plain line
  # Plain text: the caller escapes it (ERB does), nothing here is HTML.
  def deck_section_layout(lines)
    lines = Array(lines).map(&:to_s)
    if lines.size == 1 && !lines.first.match?(SECTION_LABELLED_LINE)
      return [ :paragraph, lines.first ]
    end

    rows = lines.map do |line|
      match = line.match(SECTION_LABELLED_LINE)
      match ? [ match[1].strip, match[2] ] : [ nil, line ]
    end
    [ :rows, rows ]
  end
end
