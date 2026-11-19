require "test_helper"

# B14 / I5: LibreOffice work has its own single-thread worker, and mail and
# everyday jobs have theirs, so a slow or hung render can never stop a
# magic-link email from being picked up.
class DeckQueueConfigTest < ActiveJob::TestCase
  def workers(env)
    yaml = ERB.new(File.read(Rails.root.join("config/queue.yml"))).result
    YAML.safe_load(yaml, aliases: true).fetch(env).fetch("workers")
  end

  def queues_of(worker) = Array(worker["queues"])

  %w[production development].each do |env|
    test "#{env}: renders have their own one-thread worker" do
      render_workers = workers(env).select { |w| queues_of(w).include?("renders") }
      assert_equal 1, render_workers.size
      assert_equal [ "renders" ], queues_of(render_workers.first)
      assert_equal 1, render_workers.first["threads"]
      assert_equal 1, render_workers.first["processes"]
    end

    test "#{env}: mail is served by a worker that never takes renders" do
      mail_queue = (ActionMailer::Base.deliver_later_queue_name || ActiveJob::Base.default_queue_name).to_s
      mail_workers = workers(env).select { |w| queues_of(w).include?(mail_queue) }
      assert_not_empty mail_workers
      mail_workers.each do |w|
        assert_not_includes queues_of(w), "renders"
        assert_not_includes queues_of(w), "*"
      end
    end

    test "#{env}: every application job's queue has a worker" do
      served = workers(env).flat_map { |w| queues_of(w) }
      Rails.application.eager_load!
      ApplicationJob.descendants.each do |job|
        assert_includes served, job.new.queue_name, "#{job} queue has no worker"
      end
      assert_includes served, ActiveStorage::AnalyzeJob.new.queue_name.to_s.presence || "default"
    end
  end

  test "the deck jobs run on the renders queue" do
    assert_equal "renders", DeckSlideRenderJob.new.queue_name
    assert_equal "renders", DeckImportJob.new.queue_name
  end

  # A magic-link mail enqueued while a render is queued goes to a queue that
  # only the mail worker serves, so the render worker being busy can't hold it.
  test "a magic-link mail enqueued behind a render is served by the mail worker" do
    DeckSlideRenderJob.perform_later(1)
    Auth::MagicLinkService.deliver(users(:john).email)
    mail = enqueued_jobs.find { |j| j[:job] == ActionMailer::MailDeliveryJob }
    assert mail, "no magic-link mail was enqueued"
    mail_worker = workers("production").find { |w| queues_of(w).include?(mail[:queue]) }
    assert mail_worker, "no worker serves the #{mail[:queue]} queue"
    assert_not_includes queues_of(mail_worker), "renders"
  end
end
