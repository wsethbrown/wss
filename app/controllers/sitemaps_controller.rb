# /sitemap.xml (SEO, owner-approved July 2026). Only genuinely public,
# stable pages: the veil rules hold here exactly as on-site — private
# societies never appear, unpublished decks never appear.
class SitemapsController < ApplicationController
  HOST = "https://whiskeysharesociety.com".freeze

  def show
    @host = HOST
    @static_paths = ["/", "/membership", "/reviews", "/societies", "/presentations", "/contact"]
    @societies = Society.where(is_private: false).select(:id, :updated_at)
    @presentations = Presentation.published.select(:id, :updated_at)
    @bottles = Bottle.select(:id, :slug, :updated_at)
    @reviews = Review.select(:id, :updated_at)
    render formats: :xml
  end
end
