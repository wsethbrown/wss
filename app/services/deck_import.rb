require "zip"
require "tmpdir"

# Parses an uploaded deck file (.pptx, .ppt, or .pdf) into draft deck fields.
# The goal is a good DRAFT, title, story skeleton, slide-preview rows,
# images, for a human to polish in the edit form, never an auto-published deck.
#
# Callers pass raw BYTES (read the upload once); every consumer here works on
# its own copy, so no shared io pointers or tempfile lifecycles are involved.
class DeckImport
  Result = Struct.new(:title, :description, :content, :slides_preview, :images, keyword_init: true)

  A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main".freeze

  ACCEPTED_TYPES = {
    ".pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".ppt"  => "application/vnd.ms-powerpoint",
    ".pdf"  => "application/pdf"
  }.freeze

  def self.content_type_for(filename)
    ACCEPTED_TYPES[File.extname(filename.to_s).downcase]
  end

  def self.parse(data, filename)
    ext = File.extname(filename.to_s).downcase
    ext == ".pptx" ? parse_pptx(data) : parse_via_text(data, ext, filename)
  end

  # .pptx is zipped XML, full structure: per-slide paragraphs and embedded images.
  def self.parse_pptx(data)
    slides = []
    images = []

    Zip::File.open_buffer(data) do |zip|
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
      system("pdftotext", "-layout", pdf, txt, out: File::NULL, err: File::NULL)
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

  # Renders each slide/page to PNG. Returns [{filename:, data:}, ...] in order;
  # [] when rendering tools are unavailable so import still succeeds.
  def self.render_slides(data, filename)
    ext = File.extname(filename.to_s).downcase
    Dir.mktmpdir do |dir|
      pdf = ext == ".pdf" ? write_tmp(dir, data, ".pdf") : convert_to_pdf(dir, data, ext)
      return [] unless pdf

      system("pdftoppm", "-png", "-r", "110", pdf, File.join(dir, "slide"), out: File::NULL, err: File::NULL)
      Dir[File.join(dir, "slide-*.png")].sort.map { |p| { filename: File.basename(p), data: File.binread(p) } }
    end
  rescue Errno::ENOENT
    []
  end

  def self.write_tmp(dir, data, ext)
    path = File.join(dir, "deck#{ext}")
    File.binwrite(path, data)
    path
  end

  def self.convert_to_pdf(dir, data, ext)
    src = write_tmp(dir, data, ext)
    system("soffice", "--headless", "--convert-to", "pdf", "--outdir", dir, src, out: File::NULL, err: File::NULL)
    pdf = File.join(dir, "deck.pdf")
    File.exist?(pdf) ? pdf : nil
  rescue Errno::ENOENT
    nil
  end

  def self.title_from(filename)
    File.basename(filename.to_s, ".*").tr("_-", "  ").squeeze(" ").strip.presence || "Imported deck"
  end
end
