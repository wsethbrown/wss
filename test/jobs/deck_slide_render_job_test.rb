require "test_helper"

# B14 / I8: one render at a time per deck, the new slide set attached before
# the old one is purged, and every start/finish/no-op/failure logged.
class DeckSlideRenderJobTest < ActiveJob::TestCase
  setup do
    @deck = Presentation.create!(author: users(:admin), title: "Render Deck", content: "Story.", price: 0)
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "render.pdf", content_type: "application/pdf")
    @log = StringIO.new
    @old_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(@log)
  end

  teardown { Rails.logger = @old_logger }

  def fake_slides(prefix, count = 3)
    (1..count).map { |i| { filename: "#{prefix}-#{i}.png", data: "\x89PNG#{prefix}#{i}".b } }
  end

  def slide_names
    @deck.reload.slide_images.attachments.order(:id).map { |a| a.filename.to_s }
  end

  test "runs on the renders queue" do
    assert_equal "renders", DeckSlideRenderJob.new.queue_name
  end

  test "two renders for one deck leave exactly one ordered slide set" do
    DeckImport.stubs(:render_slides).returns(fake_slides("a")).then.returns(fake_slides("b"))
    DeckSlideRenderJob.perform_now(@deck.id)
    assert_equal %w[a-1.png a-2.png a-3.png], slide_names
    DeckSlideRenderJob.perform_now(@deck.id)
    assert_equal %w[b-1.png b-2.png b-3.png], slide_names
    assert_match(/rendering deck #{@deck.id}/, @log.string)
    assert_match(/rendered 3 slides for deck #{@deck.id}.*replaced 3/, @log.string)
  end

  test "a failed render leaves the previous slides intact and is logged" do
    DeckImport.stubs(:render_slides).returns(fake_slides("a"))
    DeckSlideRenderJob.perform_now(@deck.id)

    DeckImport.stubs(:render_slides).raises(DeckImport::ToolTimeout, "soffice timed out after 180s")
    assert_raises(DeckImport::ToolTimeout) { DeckSlideRenderJob.perform_now(@deck.id) }
    assert_equal %w[a-1.png a-2.png a-3.png], slide_names
    assert_match(/render failed for deck #{@deck.id}: DeckImport::ToolTimeout/, @log.string)
  end

  test "a failure while attaching removes the partial new set and keeps the old one" do
    DeckImport.stubs(:render_slides).returns(fake_slides("a"))
    DeckSlideRenderJob.perform_now(@deck.id)

    DeckImport.stubs(:render_slides).returns(fake_slides("b"))
    ActiveStorage::Attached::Many.any_instance.stubs(:attach).raises(ActiveRecord::StatementInvalid, "boom")
    assert_raises(ActiveRecord::StatementInvalid) { DeckSlideRenderJob.perform_now(@deck.id) }
    ActiveStorage::Attached::Many.any_instance.unstub(:attach)
    assert_equal %w[a-1.png a-2.png a-3.png], slide_names
  end

  test "an empty render raises and logs with the deck id" do
    DeckImport.stubs(:run_tool).returns(true) # tools run but write nothing
    assert_raises(DeckImport::RenderError) { DeckSlideRenderJob.perform_now(@deck.id) }
    assert_equal [], slide_names
    assert_match(/render failed for deck #{@deck.id}: DeckImport::RenderError.*no slides/i, @log.string)
  end

  test "a deck with no file is a logged no-op" do
    @deck.pdf_file.purge
    DeckImport.expects(:render_slides).never
    DeckSlideRenderJob.perform_now(@deck.id)
    assert_match(/no-op for deck #{@deck.id}/, @log.string)
  end

  test "a missing deck is a logged no-op" do
    DeckSlideRenderJob.perform_now(0)
    assert_match(/no-op for deck 0: deck not found/, @log.string)
  end

  test "while another render holds the deck's lock, the job retries later instead of rendering" do
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    other = PG.connect(host: config[:host], port: config[:port], dbname: config[:database],
                       user: config[:username], password: config[:password])
    begin
      other.exec_params("SELECT pg_advisory_lock($1, $2)", [ DeckSlideRenderJob::LOCK_NAMESPACE, @deck.id ])
      DeckImport.expects(:render_slides).never
      assert_enqueued_with(job: DeckSlideRenderJob, args: [ @deck.id ]) do
        DeckSlideRenderJob.perform_now(@deck.id)
      end
      assert_match(/already rendering deck #{@deck.id}/, @log.string)
    ensure
      other.exec_params("SELECT pg_advisory_unlock($1, $2)", [ DeckSlideRenderJob::LOCK_NAMESPACE, @deck.id ])
      other.close
    end

    # The lock is released by the job that holds it, so the next run renders.
    DeckImport.unstub(:render_slides)
    DeckImport.stubs(:render_slides).returns(fake_slides("c", 2))
    DeckSlideRenderJob.perform_now(@deck.id)
    assert_equal %w[c-1.png c-2.png], slide_names
  end
end
