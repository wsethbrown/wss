# ActiveRecord encryption keys. Nothing in the app encrypts with them today: the
# two-factor columns they protected are ignored since 2FA was removed (B11), but
# those rows still hold encrypted data until a migration drops the columns, so
# keep the keys configured and backed up until then.
# Keys live in env (.env locally, deploy secrets in production) — see
# .env.example. support_unencrypted_data lets rows written before encryption
# was enabled keep working; new writes are always encrypted.
Rails.application.config.active_record.encryption.primary_key = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
Rails.application.config.active_record.encryption.deterministic_key = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
Rails.application.config.active_record.encryption.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]
Rails.application.config.active_record.encryption.support_unencrypted_data = true
