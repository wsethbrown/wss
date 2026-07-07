# create/destroy only — favorites render inline on the favoritable's page and
# in full on the owner's own profile (ProfilesController).
class FavoritesController < ApplicationController
  before_action :authenticate_user!

  def create
    favoritable = favoritable_class.find(params[:favoritable_id])
    current_user.favorites.build(favoritable: favoritable).save
    redirect_back_or_to favoritable
  end

  def destroy
    favorite = current_user.favorites.find(params[:id]) # scoped to current_user: 404s on someone else's row
    favoritable = favorite.favoritable
    favorite.destroy
    redirect_back_or_to favoritable
  end

  private

  def favoritable_class = params[:favoritable_type] == "User" ? User : Society
  def redirect_back_or_to(f) = redirect_to(f.is_a?(User) ? profile_path(f) : society_path(f))
end
