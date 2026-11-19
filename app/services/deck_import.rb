require "zip"
require "tmpdir"

# Parses an uploaded deck file (.pptx, .ppt, or .pdf) into draft deck fields.
# The goal is a good DRAFT, title, story skeleton, slide-preview rows,
# images, for a human to polish in the edit form, never an auto-published deck.
#
# Callers pass raw BYTES (read the upload once); every consumer here works on
# its own copy, so no shared io pointers or tempfile lifecycles are involved.
#
# Only .pptx is parsed in the web request (pure XML). Anything that needs
# LibreOffice or poppler (.ppt/.pdf text, every slide render) runs in the
# jobs process on the `renders` queue: DeckImportJob and DeckSlideRenderJob.
# Every tool run is bounded by a timeout (the process group is killed), and
# each LibreOffice run gets its own profile directory, so a hung or parallel
# soffice can neither wedge a worker nor silently produce nothing (I5).
class DeckImport
  Result = Struct.new(:title, :description, :content, :slides_preview, :images, keyword_init: true)

  class RenderError < StandardError; end
  class ToolTimeout < RenderError; end
  class ToolMissing < RenderError; end

  SOFFICE_TIMEOUT   = 180 # seconds; a normal deck converts in well under a minute
  PDFTOPPM_TIMEOUT  = 120
  PDFTOTEXT_TIMEOUT = 60

  A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main".freeze

  ACCEPTED_TYPES = {
    ".pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".ppt"  => "application/vnd.ms-powerpoint",
    ".pdf"  => "application/pdf"
  }.freeze

  def self.content_type_for(filename)
    ACCEPTED_TYPES[File.extname(filename.to_s).downcase]
  end

  # True when the file's text can be drafted inside the web request.
  def self.inline_parse?(filename)
    File.extname(filename.to_s).downcase == ".pptx"
  end

  # The draft a .ppt/.pdf import starts from before DeckImportJob has
  # extracted its text: the same fields an empty parse produces.
  def self.placeholder(filename)
    title = title_from(filename)
    Result.new(title: title, description: "", content: title, slides_preview: "", images: [])
  end

  def self.parse(data, filename)
    ext = File.extname(filename.to_s).downcase
    ext == ".pptx" ? parse_pptx(data) : parse_via_text(data, ext, filename)
  end

  # .pptx is zipped XML, full structure: per-slide paragraphs and embedded images.
  def self.parse_pptx(data)
    slides = []
    images = []

    Zip::File.open_buffer(StringIO.new(data)) do |zip|
      zip.glob("ppt/slides/slide*.xml").sort_by { |e| e.name[/\d+/].to_i }.each do |entry|
        doc = Nokogiri::XML(entry.get_input_stream.read)
        paras = doc.xpath("//a:p", "a" => A_NS).map { |p|
          p.xpath(".//a:t", "a" => A_NS).map(&:text).join.strip
        }.reject(&:blank?)
        slides << paras
      end

      zip.glob("ppt/media/image*").each do |entry|
        next unless entry.name =~ /\.(png|jpe?g|gif|webp)$/i
        images << { filename: File.basename(entry.name), data: entry.get_input_stream.read }
      end
    end

    build_result(slides, images.sort_by { |i| -i[:data].bytesize })
  end

  # .ppt / .pdf: no clean XML to walk, extract text per page via LibreOffice/
  # poppler and draft from that. Rendering (render_slides) supplies the visuals.
  def self.parse_via_text(data, ext, filename)
    pages = Dir.mktmpdir do |dir|
      pdf = ext == ".pdf" ? write_tmp(dir, data, ".pdf") : convert_to_pdf(dir, data, ext)
      next [] unless pdf

      txt = File.join(dir, "deck.txt")
      run_tool("pdftotext", "-layout", pdf, txt, timeout: PDFTOTEXT_TIMEOUT)
      File.exist?(txt) ? File.read(txt).split("\f") : []
    end

    slides = pages.map { |page| page.lines.map(&:strip).reject(&:blank?) }
    slides = [ [ title_from(filename) ] ] if slides.flatten.empty?

    build_result(slides, [])
  end

  def self.build_result(slides, images)
    title = slides.first&.first.presence || "Imported deck"
    body_slides = slides.drop(1)

    preview_rows = body_slides.each_with_index.map { |paras, i|
      "Slide #{i + 1}|#{paras.first.to_s.truncate(80)}|#{paras.second.to_s.truncate(120)}|"
    }

    content = body_slides.map { |paras|
      next if paras.empty?
      [ "## #{paras.first}", *paras.drop(1) ].join("\n\n")
    }.compact.join("\n\n")

    description = (slides.first&.second.presence || body_slides.dig(0, 1).to_s).truncate(200)

    Result.new(title: title.truncate(200), description: description, content: content,
               slides_preview: preview_rows.join("\n"), images: images)
  end

  # Renders each slide/page to PNG. Returns [{filename:, data:}, ...] in
  # order. Raises RenderError (or a subclass) when a tool is missing, times
  # out, or no slides come out: an empty render is a failure, never success.
  def self.render_slides(data, filename)
    ext = File.extname(filename.to_s).downcase
    Dir.mktmpdir do |dir|
      pdf = ext == ".pdf" ? write_tmp(dir, data, ".pdf") : convert_to_pdf(dir, data, ext)
      raise RenderError, "LibreOffice produced no PDF from #{ext} file" unless pdf

      run_tool("pdftoppm", "-png", "-r", "110", pdf, File.join(dir, "slide"), timeout: PDFTOPPM_TIMEOUT)
      pngs = Dir[File.join(dir, "slide-*.png")].sort
      raise RenderError, "no slides came out of the #{ext} file" if pngs.empty?

      pngs.map { |p| { filename: File.basename(p), data: File.binread(p) } }
    end
  end

  def self.write_tmp(dir, data, ext)
    path = File.join(dir, "deck#{ext}")
    File.binwrite(path, data)
    path
  end

  # Each run gets its own LibreOffice profile inside its own temp dir: two
  # soffice processes sharing one profile lock each other out and can exit
  # "successfully" having written nothing.
  def self.convert_to_pdf(dir, data, ext)
    src = write_tmp(dir, data, ext)
    profile = File.join(dir, "lo-profile")
    run_tool("soffice", "-env:UserInstallation=file://#{profile}", "--headless",
             "--convert-to", "pdf", "--outdir", dir, src, timeout: SOFFICE_TIMEOUT)
    pdf = File.join(dir, "deck.pdf")
    File.exist?(pdf) ? pdf : nil
  end

  # Runs an external tool with output discarded. Returns true on a zero exit.
  # Past `timeout` seconds the whole process group is killed (soffice forks
  # soffice.bin) and ToolTimeout is raised. ToolMissing when not installed.
  def self.run_tool(*cmd, timeout:)
    pid = Process.spawn(*cmd, out: File::NULL, err: File::NULL, pgroup: true)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      _, status = Process.wait2(pid, Process::WNOHANG)
      return status.success? if status

      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        kill_group(pid)
        raise ToolTimeout, "#{cmd.first} timed out after #{timeout}s"
      end
      sleep 0.1
    end
  rescue Errno::ENOENT
    raise ToolMissing, "#{cmd.first} is not installed"
  end

  def self.kill_group(pid)
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH
    nil
  ensure
    begin
      Process.wait(pid)
    rescue Errno::ECHILD
      nil
    end
  end

  def self.title_from(filename)
    File.basename(filename.to_s, ".*").tr("_-", "  ").squeeze(" ").strip.presence || "Imported deck"
  end
end
