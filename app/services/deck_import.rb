require "zip"

# Parses an uploaded .pptx into draft deck fields. The goal is a good DRAFT —
# title, story skeleton, slide-preview rows, images — for a human to polish in
# the edit form, never an auto-published deck.
class DeckImport
  Result = Struct.new(:title, :description, :content, :slides_preview, :images, keyword_init: true)

  A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main".freeze

  def self.parse(io)
    slides = []
    images = []

    Zip::File.open_buffer(io) do |zip|
      slide_entries = zip.glob("ppt/slides/slide*.xml")
                         .sort_by { |e| e.name[/\d+/].to_i }
      slide_entries.each do |entry|
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

  def self.build_result(slides, images)
    title = slides.first&.first.presence || "Imported deck"
    # Slide 1 is usually the cover; body slides drive the outline and story.
    body_slides = slides.drop(1)

    preview_rows = body_slides.each_with_index.map { |paras, i|
      heading = paras.first.to_s.truncate(80)
      detail  = paras.second.to_s.truncate(120)
      "Slide #{i + 1}|#{heading}|#{detail}|"
    }

    content = body_slides.map { |paras|
      next if paras.empty?
      ["## #{paras.first}", *paras.drop(1)].join("\n\n")
    }.compact.join("\n\n")

    description = (slides.first&.second.presence || body_slides.dig(0, 1).to_s).truncate(200)

    Result.new(title: title, description: description, content: content,
               slides_preview: preview_rows.join("\n"), images: images)
  end
end
