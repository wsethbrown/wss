# create/destroy only, favorites render inline on the favoritable's page and
# in full on the owner's own profile (ProfilesController).
class FavoritesController < ApplicationController
  before_action :authenticate_user!

  def create
    favoritable = favoritable_class.find(params[:favoritable_id])
    favorite = current_user.favorites.find_or_initialize_by(favoritable: favoritable)
    fresh_follow = !favorite.persisted?
    if favorite.persisted? || favorite.save
      # A person gaining a follower hears about it (deduped in the model, so
      # unfollow/refollow cycles never stack rows).
      if fresh_follow && favoritable.is_a?(User)
        Notification.notify!(user: favoritable, actor: current_user, notifiable: favoritable, action: "follow")
      end
      swap_button_or_redirect favoritable
    else
      redirect_back_or_to favoritable, alert: favorite.errors.full_messages.to_sentence
    end
  end

  def destroy
    favorite = current_user.favorites.find(params[:id]) # scoped to current_user: 404s on someone else's row
    favoritable = favorite.favoritable
    favorite.destroy
    swap_button_or_redirect favoritable, removed: favorite
  end

  private

  # The button flips in place (star fills/empties), that IS the feedback,
  # so success carries no flash. Failures still redirect with an alert.
  # On unfollow, a remove stream also clears the row on Account → Followed;
  # each stream no-ops on pages where its target frame isn't present.
  def swap_button_or_redirect(favoritable, removed: nil)
    respond_to do |format|
      format.turbo_stream do
        streams = [ turbo_stream.replace(
          helpers.dom_id(favoritable, :favorite),
          partial: "favorites/button",
          locals: { favoritable: favoritable, tone: params[:tone] == "dark" ? :dark : :light }
        ) ]
        streams << turbo_stream.remove(helpers.dom_id(removed)) if removed
        render turbo_stream: streams
      end
      format.html { redirect_back_or_to favoritable }
    end
  end

  def favoritable_class
    case params[:favoritable_type]
    when "User" then User
    when "Society" then Society
    else raise ActiveRecord::RecordNotFound
    end
  end
  def redirect_back_or_to(f, **options) = redirect_to(f.is_a?(User) ? profile_path(f) : society_path(f), **options)
end
