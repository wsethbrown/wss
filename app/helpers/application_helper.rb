module ApplicationHelper
  # Returns a styled nav link with active highlighting (for the dark char nav).
  def nav_link_to(name, path, options = {})
    active = current_page?(path)
    classes = [
      'transition-colors',
      'hover:text-whiskey-200',
      'px-3',
      'py-2',
      'rounded-lg',
      'font-medium',
      active ? 'text-whiskey-300' : 'text-cream/80'
    ]
    link_to name, path, options.merge(class: classes.join(' '))
  end
end
