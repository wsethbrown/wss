# Use libvips for Active Storage image processing. Both Docker images ship
# libvips and neither ships ImageMagick — :mini_magick here would 500 on the
# first variant render in every environment.
Rails.application.config.active_storage.variant_processor = :vips