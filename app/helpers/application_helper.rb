module ApplicationHelper
  # Returns a styled nav link with active highlighting
  def nav_link_to(name, path, options = {})
    active = current_page?(path)
    classes = [
      'transition-colors',
      'hover:text-indigo-600',
      'px-3',
      'py-2',
      'rounded-lg',
      'font-semibold',
      active ? 'text-indigo-600' : 'text-gray-700'
    ]
    link_to name, path, options.merge(class: classes.join(' '))
  end
end
