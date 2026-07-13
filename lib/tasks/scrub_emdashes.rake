# One-off maintenance task: strip em-dashes (U+2014) from author-entered deck
# content, replacing them with natural punctuation (comma for a mid-sentence
# pause). Dry-run by default; pass APPLY=1 to write. The em-dash is referenced by
# its code point ("—") so this source file stays em-dash-free.
#
#   bin/rails scrub:emdashes            # dry run, reports affected decks
#   APPLY=1 bin/rails scrub:emdashes    # writes the changes
namespace :scrub do
  desc "Remove em-dashes from Presentation text fields (APPLY=1 to write)"
  task emdashes: :environment do
    emdash = "—"
    apply  = ENV["APPLY"] == "1"

    text_fields = %i[title description content what_youll_learn tasting_notes
                     nose_notes palate_notes finish_notes body_notes
                     whiskey_recommendations slides_preview]

    scrub = lambda do |s|
      return s unless s.is_a?(String)
      out = s.gsub("&mdash;", emdash)
      out = out.gsub(/[ \t]*#{emdash}[ \t]*(?=\n)/, ",") # em-dash ending a line
      out = out.gsub(/[ \t]*#{emdash}[ \t]*/, ", ")      # em-dash mid-line
      out
    end

    decks = 0
    fields = 0

    Presentation.find_each do |p|
      dirty = false

      text_fields.each do |f|
        v = p.public_send(f)
        next unless v.is_a?(String) && (v.include?(emdash) || v.include?("&mdash;"))
        nv = scrub.call(v)
        next if nv == v
        p.public_send("#{f}=", nv)
        fields += 1
        dirty = true
      end

      if p.whiskey_recommendations_json.is_a?(Array)
        scrubbed = p.whiskey_recommendations_json.map do |rec|
          rec.is_a?(Hash) ? rec.transform_values { |val| scrub.call(val) } : rec
        end
        if scrubbed != p.whiskey_recommendations_json
          p.whiskey_recommendations_json = scrubbed
          fields += 1
          dirty = true
        end
      end

      next unless dirty
      decks += 1
      puts "#{apply ? 'SCRUB' : 'WOULD SCRUB'}  ##{p.id}  #{p.title}"
      p.save!(validate: false) if apply
    end

    puts "-" * 40
    puts "#{apply ? 'Scrubbed' : 'Dry run:'} #{decks} deck(s), #{fields} field(s)."
  end
end
