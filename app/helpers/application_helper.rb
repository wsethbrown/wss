module ApplicationHelper
  # Returns a styled nav link with active highlighting
  def nav_link_to(name, path, options = {})
    active = current_page?(path)
    classes = [
      'transition',
      'hover:text-indigo-600',
      'px-2',
      'py-1',
      'rounded',
      'font-semibold',
      active ? 'text-indigo-600 bg-indigo-50' : 'text-gray-700'
    ]
    link_to name, path, options.merge(class: classes.join(' '))
  end
end
