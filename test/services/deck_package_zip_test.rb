require "test_helper"
require_relative "../support/deck_package_fixture"

# An uploaded deck package arrives as a zip. DeckPackageZip opens it into a
# temporary folder for DeckPackageImport, and refuses anything unsafe: paths
# that climb out of the folder, absolute paths, symlinks, too many entries,
# entries or totals that are too large once unzipped.
class DeckPackageZipTest < ActiveSupport::TestCase
  include DeckPackageFixture

  setup do
    @work = Dir.mktmpdir("deck-package-zip-test")
    @package = build_deck_package(File.join(@work, "package"))
  end

  teardown { FileUtils.remove_entry(@work) }

  def zip_with(entries)
    path = File.join(@work, "custom-#{SecureRandom.hex(4)}.zip")
    Zip::OutputStream.open(path) do |zos|
      entries.each do |name, body|
        zos.put_next_entry(name)
        zos.write(body)
      end
    end
    path
  end

  test "a package at the zip root opens as a package folder" do
    zip = zip_deck_package(@package, File.join(@work, "root.zip"))
    DeckPackageZip.open(zip) do |dir|
      assert dir.join("deck.json").file?
      assert dir.join("Test-Deck.pptx").file?
      assert_equal %w[slide-01.png slide-02.png slide-03.png], dir.glob("slides/*.png").map { |p| p.basename.to_s }.sort
    end
  end

  test "a package inside one top-level folder opens the same way" do
    zip = zip_deck_package(@package, File.join(@work, "folder.zip"), folder: "the-rye-from-lawrenceburg")
    DeckPackageZip.open(zip) do |dir|
      assert dir.join("deck.json").file?
      assert dir.join("speaker-notes.md").file?
      assert dir.join("slides/slide-01.png").file?
    end
  end

  test "the temporary folder is always removed, even when the block raises" do
    zip = zip_deck_package(@package, File.join(@work, "root.zip"))
    seen = nil
    assert_raises(RuntimeError) do
      DeckPackageZip.open(zip) do |dir|
        seen = dir
        raise "boom"
      end
    end
    assert_not File.exist?(seen)
  end

  test "only the file types a package uses are extracted; Finder litter is skipped" do
    zip = zip_with("deck.json" => "{}", "speaker-notes.md" => "x", "run.sh" => "rm -rf /",
                   "__MACOSX/._deck.json" => "junk", ".DS_Store" => "junk", "slides/slide-01.png" => "png",
                   "slides/notes.txt" => "no", "nested/deep/file.pdf" => "no")
    DeckPackageZip.open(zip) do |dir|
      assert_equal %w[deck.json slides slides/slide-01.png speaker-notes.md], Dir.glob("**/*", base: dir.to_s).sort
    end
  end

  test "a file that is not a zip is refused in plain words" do
    path = File.join(@work, "fake.zip")
    File.write(path, "not a zip at all")
    error = assert_raises(DeckPackageZip::Invalid) { DeckPackageZip.open(path) { flunk "should not open" } }
    assert_match(/isn't a zip/, error.message)
  end

  test "a zip without deck.json is not a package" do
    zip = zip_with("slides/slide-01.png" => "png", "notes.md" => "x")
    error = assert_raises(DeckPackageZip::Invalid) { DeckPackageZip.open(zip) { flunk } }
    assert_match(/isn't a deck package/, error.message)
    assert_match(/deck\.json/, error.message)
  end

  test "a zip holding two packages is refused" do
    zip = zip_with("one/deck.json" => "{}", "two/deck.json" => "{}")
    error = assert_raises(DeckPackageZip::Invalid) { DeckPackageZip.open(zip) { flunk } }
    assert_match(/more than one/, error.message)
  end

  test "a path that climbs out of the folder is refused" do
    zip = zip_with("deck.json" => "{}", "../evil.md" => "x")
    error = assert_raises(DeckPackageZip::Invalid) { DeckPackageZip.open(zip) { flunk } }
    assert_match(/outside the package/, error.message)
    assert_not File.exist?(File.join(Dir.tmpdir, "evil.md"))
  end

  test "an absolute path is refused" do
    # rubyzip will not write a name starting with "/", so write a placeholder
    # and patch the bytes, as a hand-crafted hostile zip would have them.
    zip = zip_with("deck.json" => "{}", "Xtmp/evil.md" => "x")
    File.binwrite(zip, File.binread(zip).gsub("Xtmp/evil.md", "/tmp/evil.md"))
    assert_raises(DeckPackageZip::Invalid) { DeckPackageZip.open(zip) { flunk } }
  end

  test "a symlink is refused" do
    link = File.join(@package, "speaker-notes-link.md")
    File.symlink("/etc/passwd", link)
    zip = File.join(@work, "symlink.zip")
    Zip::File.open(zip, create: true) do |z|
      z.add("deck.json", File.join(@package, "deck.json"))
      z.add("speaker-notes.md", link)
    end
    error = assert_raises(DeckPackageZip::Invalid) { DeckPackageZip.open(zip) { flunk } }
    assert_match(/shortcut/, error.message)
  end

  test "too many entries are refused" do
    zip = zip_with((1..6).to_h { |i| [ "slides/slide-0#{i}.png", "png" ] }.merge("deck.json" => "{}"))
    error = assert_raises(DeckPackageZip::Invalid) { DeckPackageZip.open(zip, max_entries: 5) { flunk } }
    assert_match(/too many files/, error.message)
  end

  test "an entry larger than the cap once unzipped is refused" do
    zip = zip_with("deck.json" => "{}", "speaker-notes.md" => "a" * 5_000)
    error = assert_raises(DeckPackageZip::Invalid) { DeckPackageZip.open(zip, max_entry_bytes: 1_000) { flunk } }
    assert_match(/speaker-notes\.md is larger than/, error.message)
  end

  test "a total larger than the cap once unzipped is refused" do
    zip = zip_with("deck.json" => "{}", "speaker-notes.md" => "a" * 800, "Deck.pptx" => "b" * 800)
    error = assert_raises(DeckPackageZip::Invalid) do
      DeckPackageZip.open(zip, max_entry_bytes: 1_000, max_total_bytes: 1_200) { flunk }
    end
    assert_match(/larger than .* once unzipped/, error.message)
  end

  test "an entry that lies about its size is caught while it is read" do
    zip = zip_with("deck.json" => "{}", "speaker-notes.md" => "a" * 5_000)
    Zip::Entry.any_instance.stubs(:size).returns(10)
    assert_raises(DeckPackageZip::Invalid) { DeckPackageZip.open(zip, max_entry_bytes: 1_000) { flunk } }
  end

  test "the caps fit a 30-slide deck of 4 MB slides" do
    assert DeckPackageZip::MAX_ENTRIES >= 40
    assert DeckPackageZip::MAX_ENTRY_BYTES >= 50.megabytes, "a deck file may be up to the 50 MB the model allows"
    assert DeckPackageZip::MAX_TOTAL_BYTES >= (30 * 4.megabytes) + 50.megabytes + 40.megabytes
  end
end
