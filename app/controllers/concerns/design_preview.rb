# Parallel-design previews: append ?design=next to render the *_next template
# variant of an action, admin-only, without touching the live templates.
# Promote a preview by renaming its _next template over the original.
module DesignPreview
  extend ActiveSupport::Concern

  private

  def render_next_design?(action = action_name)
    # Open to everyone in development (any browser/session can compare);
    # admin-only in production so visitors never stumble into previews.
    allowed = Rails.env.development? || current_user&.admin?
    params[:design] == "next" && allowed &&
      lookup_context.exists?("#{action}_next", lookup_context.prefixes, false)
  end

  def maybe_render_next
    render "#{action_name}_next" if render_next_design?
  end
end
