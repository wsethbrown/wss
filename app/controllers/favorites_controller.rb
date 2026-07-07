# create/destroy only — favorites render inline on the favoritable's page and
# in full on the owner's own profile (ProfilesController).
class FavoritesController < ApplicationController
  before_action :authenticate_user!

  def create
    favoritable = favoritable_class.find(params[:favoritable_id])
    favorite = current_user.favorites.find_or_initialize_by(favoritable: favoritable)
    if favorite.persisted? || favorite.save
      redirect_back_or_to favoritable, notice: "Favorited."
    else
      redirect_back_or_to favoritable, alert: favorite.errors.full_messages.to_sentence
    end
  end

  def destroy
    favorite = current_user.favorites.find(params[:id]) # scoped to current_user: 404s on someone else's row
    favoritable = favorite.favoritable
    favorite.destroy
    redirect_back_or_to favoritable
  end

  private

  def favoritable_class
    case params[:favoritable_type]
    when "User" then User
    when "Society" then Society
    else raise ActiveRecord::RecordNotFound
    end
  end
  def redirect_back_or_to(f, **options) = redirect_to(f.is_a?(User) ? profile_path(f) : society_path(f), **options)
end
