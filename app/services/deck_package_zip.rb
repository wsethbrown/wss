# Opens an uploaded deck package (.zip) into a temporary folder laid out the
# way DeckPackageImport reads it, yields that folder, and always removes it.
#
#   DeckPackageZip.open(upload.path) { |dir| DeckPackageImport.call(dir, ...) }
#
# The package may sit at the zip's root or inside one top-level folder (what
# Finder's "Compress" makes). The zip comes from a browser upload, so it is
# treated as hostile: every entry name is checked before anything is written
# (no absolute paths, no "..", no backslashes, no symlinks), the entry count
# and the declared sizes are capped, and the bytes actually written are
# counted as they stream, so an entry that lies about its size is still caught.
# Only the file types a package uses are extracted; anything else (Finder's
# __MACOSX folder, .DS_Store, sources, scripts) is skipped.
class DeckPackageZip
  class Invalid < StandardError; end

  # A 30-slide deck with 4 MB slides, a 50 MB deck file (the most the model
  # accepts) and two PDFs comes to about 230 MB; the caps leave headroom.
  MAX_ENTRIES = 300
  MAX_ENTRY_BYTES = 60.megabytes
  MAX_TOTAL_BYTES = 300.megabytes
  CHUNK_BYTES = 64.kilobytes

  # What a package uses, relative to the package folder.
  TOP_LEVEL_FILE = /\A[^\/]+\.(json|md|pptx|pdf)\z/i
  SLIDE_FILE = %r{\Aslides/slide-\d+\.png\z}i
  IGNORED = %r{(\A|/)(__MACOSX/|\.DS_Store\z|\._)}

  def self.open(path, **limits, &block)
    new(path, **limits).open(&block)
  end

  def initialize(path, max_entries: MAX_ENTRIES, max_entry_bytes: MAX_ENTRY_BYTES, max_total_bytes: MAX_TOTAL_BYTES)
    @path = path.to_s
    @max_entries = max_entries
    @max_entry_bytes = max_entry_bytes
    @max_total_bytes = max_total_bytes
  end

  def open
    dir = Pathname(Dir.mktmpdir("deck-package-upload"))
    extract_into(dir)
    yield dir
  ensure
    FileUtils.remove_entry(dir.to_s) if dir && File.exist?(dir.to_s)
  end

  private

  def extract_into(dir)
    Zip::File.open(@path) do |zip|
      entries = zip.entries
      refuse!("That zip holds too many files (#{entries.size}). A deck package has well under #{@max_entries}.") if entries.size > @max_entries
      entries.each { |entry| check_entry!(entry) }

      root = package_root(entries)
      wanted = entries.filter_map do |entry|
        next if entry.directory? || entry.name.match?(IGNORED) || !entry.name.start_with?(root)

        relative = entry.name.delete_prefix(root)
        [ entry, relative ] if relative.match?(TOP_LEVEL_FILE) || relative.match?(SLIDE_FILE)
      end

      declared = wanted.sum { |entry, _| entry.size.to_i }
      refuse_total! if declared > @max_total_bytes

      total = 0
      wanted.each do |entry, relative|
        total += write_entry(entry, relative, dir, total)
      end
    end
  rescue Zip::Error => e
    Rails.logger.warn("[DeckPackageZip] unreadable zip: #{e.class}: #{e.message}")
    raise Invalid, "That file isn't a zip that can be opened. Upload the deck package as a .zip file."
  end

  def check_entry!(entry)
    name = entry.name.to_s
    if entry.symlink?
      refuse!("That zip can't be used: it contains a shortcut (symlink), #{name}. Zip the package's real files.")
    end
    unsafe = name.start_with?("/") || name.include?("\\") || name.include?("\0") ||
             name.match?(/\A[a-z]:/i) || name.split("/").include?("..")
    refuse!("That zip can't be used: it contains a file path that points outside the package (#{name}).") if unsafe
    if entry.size.to_i > @max_entry_bytes
      refuse!("#{File.basename(name)} is larger than #{human(@max_entry_bytes)} once unzipped, too large for a deck package.")
    end
  end

  # "" for a package at the root, "folder/" for one inside a single folder.
  def package_root(entries)
    candidates = entries.map(&:name).reject { |n| n.match?(IGNORED) }
                        .select { |n| File.basename(n) == "deck.json" && n.count("/") <= 1 }
    if candidates.empty?
      refuse!("That zip isn't a deck package: there is no deck.json at its top level or inside one folder.")
    end
    refuse!("That zip holds more than one deck package. Upload one package at a time.") if candidates.size > 1

    folder = File.dirname(candidates.first)
    folder == "." ? "" : "#{folder}/"
  end

  def write_entry(entry, relative, dir, total_so_far)
    target = dir.join(relative).cleanpath
    refuse!("That zip can't be used: it contains a file path that points outside the package.") unless target.to_s.start_with?("#{dir}/")

    FileUtils.mkdir_p(target.dirname)
    written = 0
    File.open(target, "wb") do |out|
      entry.get_input_stream do |io|
        while (chunk = io.read(CHUNK_BYTES))
          written += chunk.bytesize
          if written > @max_entry_bytes
            refuse!("#{File.basename(relative)} is larger than #{human(@max_entry_bytes)} once unzipped, too large for a deck package.")
          end
          refuse_total! if total_so_far + written > @max_total_bytes
          out.write(chunk)
        end
      end
    end
    written
  end

  def refuse_total!
    refuse!("The package is larger than #{human(@max_total_bytes)} once unzipped, too large to upload.")
  end

  def refuse!(message)
    Rails.logger.warn("[DeckPackageZip] refused: #{message}")
    raise Invalid, message
  end

  def human(bytes) = ActiveSupport::NumberHelper.number_to_human_size(bytes)
end
