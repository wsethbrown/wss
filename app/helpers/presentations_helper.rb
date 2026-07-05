module PresentationsHelper
  # Renders deck content (authored as Markdown) to sanitized HTML.
  #
  # The renderer strips any raw HTML in the source (filter_html) and the output
  # is passed through Rails' sanitizer with an explicit allowlist, so author
  # content can never inject script/style into the page.
  def render_markdown(text)
    return "".html_safe if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: true,
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
end
