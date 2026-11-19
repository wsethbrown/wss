# Use libvips for Active Storage image processing. Both Docker images ship
# libvips and neither ships ImageMagick — :mini_magick here would 500 on the
# first variant render in every environment.
Rails.application.config.active_storage.variant_processor = :vips

# Variant generation (ActiveStorage::TransformJob) is image work like the deck
# renders: run it on the one-thread `renders` worker, never on `default`, which
# carries mail (magic-link sign-in). See config/queue.yml and
# test/jobs/deck_queue_config_test.rb.
Rails.application.config.active_storage.queues.transform = :renders
