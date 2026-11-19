class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  private

  # Makes fan-out jobs safe to run twice (a deploy mid-run, a Solid Queue
  # retry): the first caller to claim a key proceeds, later ones skip. If the
  # work then raises, the claim is released so a retry can still send.
  # Backed by Rails.cache (Solid Cache in production, so it survives deploys).
  # Returns true when the work ran, false when it was already claimed.
  def once(key, ttl: 14.days)
    return false unless Rails.cache.write(key, true, unless_exist: true, expires_in: ttl)

    begin
      yield
      true
    rescue StandardError
      Rails.cache.delete(key)
      raise
    end
  end
end
