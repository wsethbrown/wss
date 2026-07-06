# ActiveRecord encryption keys (used for User OTP secrets / backup codes).
# Keys live in env (.env locally, deploy secrets in production) — see
# .env.example. support_unencrypted_data lets rows written before encryption
# was enabled keep working; new writes are always encrypted.
Rails.application.config.active_record.encryption.primary_key = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
Rails.application.config.active_record.encryption.deterministic_key = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
Rails.application.config.active_record.encryption.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]
Rails.application.config.active_record.encryption.support_unencrypted_data = true
