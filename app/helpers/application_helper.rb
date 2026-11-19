module ApplicationHelper
  # Returns a styled nav link with active highlighting (for the dark char nav).
  def nav_link_to(name, path, options = {})
    active = current_page?(path)
    classes = [
      "transition-colors",
      "hover:text-cream",
      "px-3",
      "py-2",
      "rounded-lg",
      "font-medium",
      active ? "text-cream" : "text-cream/70"
    ]
    link_to name, path, options.merge(class: classes.join(" "))
  end
end
