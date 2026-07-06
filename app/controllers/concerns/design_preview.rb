# Parallel-design previews: append ?design=next to render the *_next template
# variant of an action, admin-only, without touching the live templates.
# Promote a preview by renaming its _next template over the original.
module DesignPreview
  extend ActiveSupport::Concern

  private

  def render_next_design?(action = action_name)
    params[:design] == "next" && current_user&.admin? &&
      lookup_context.exists?("#{action}_next", lookup_context.prefixes, false)
  end

  def maybe_render_next
    render "#{action_name}_next" if render_next_design?
  end
end
