namespace :solid_queue do
  desc "One-off purge of finished Solid Queue jobs (they retain mail-job arguments, which include raw tokens)"
  task purge_finished: :environment do
    total = SolidQueue::Job.where.not(finished_at: nil).count
    Rails.logger.info "solid_queue:purge_finished: purging #{total} finished jobs"
    SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)
    Rails.logger.info "solid_queue:purge_finished: done"
    puts "Purged #{total} finished jobs"
  end
end
