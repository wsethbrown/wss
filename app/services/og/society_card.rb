require "vips"

module Og
  # A 1200x630 link-preview card for a society invite: the chapter's name, its
  # logo, and the WSS wordmark on the char surface, so a shared invite link
  # unfurls into something branded instead of a bare domain chip.
  #
  # Composed with libvips (already in the image for Active Storage / deck
  # rendering) rather than headless Chrome. It mirrors the invite masthead:
  # banner behind a char gradient when the society has one, the char label
  # otherwise; eyebrow, serif name, logo chip, wordmark.
  #
  # The bytes are cached (see SocietiesController#invite_card) keyed by a stamp
  # of name + logo + banner, so repeated scrapes don't recompose and a change
  # to any of those busts it.
  class SocietyCard
    W = 1200
    H = 630
    CHAR   = [ 25, 16, 9 ].freeze     # --color-char #191009
    CREAM  = [ 246, 237, 218 ].freeze # --color-cream #f6edda
    AMBER  = [ 217, 171, 116 ].freeze # --color-whiskey-300 #d9ab74
    GLOW   = [ 201, 136, 74 ].freeze  # --color-whiskey-400, the masthead glow
    SERIF  = "Gelasio"                # editorial serif, shipped in the image

    def initialize(society)
      @society = society
    end

    MARGIN = 90
    LOGO = 120

    def png
      canvas = background

      # The logo is decoration in the top-left, not a stacking element: putting
      # it above the text pushed a two-line name into the wordmark. Corner-
      # anchored, it costs the headline no vertical room.
      canvas = over(canvas, logo_chip, MARGIN, MARGIN) if logo_blob

      # The eyebrow + name block is BOTTOM-anchored above the wordmark, so it
      # sits in the same place whether the name is one line or two.
      name_layer, eyebrow_layer = name, eyebrow
      name_y = H - 132 - name_layer.height
      canvas = over(canvas, eyebrow_layer, MARGIN + 4, name_y - eyebrow_layer.height - 14)
      canvas = over(canvas, name_layer, MARGIN, name_y)

      canvas = over(canvas, wordmark, MARGIN + 4, H - 70)
      canvas.pngsave_buffer
    end

    private

    # Banner behind a char gradient when there is one, else char with the same
    # bottom-anchored amber glow the masthead uses.
    def background
      base =
        if banner_blob
          cover(vips(banner_blob)).linear([ 0.42, 0.42, 0.42 ], [ 0, 0, 0 ]).cast(:uchar)
        else
          solid(CHAR)
        end
      base = over(base, char_veil) if banner_blob
      base = over(base, glow) unless banner_blob
      base
    end

    # A vertical char gradient so text stays legible over any banner: fully
    # opaque at the bottom, clearing toward the top.
    def char_veil
      y = Vips::Image.xyz(W, H)[1]
      t = clamp01(y.linear(1.0 / H, 0.0)) ** 1.4
      solid(CHAR).bandjoin((t * 235).cast(:uchar)).copy(interpretation: :srgb)
    end

    # Amber radial glow rising from the bottom, matching the masthead's
    # radial-gradient(...at 50% 110%).
    def glow
      cx, cy, radius = W / 2.0, H * 1.15, H * 0.9
      xy = Vips::Image.xyz(W, H)
      dist = ((xy[0] - cx) ** 2 + (xy[1] - cy) ** 2) ** 0.5
      falloff = clamp01(dist.linear(-1.0 / radius, 1.0)) ** 1.6
      solid(GLOW).bandjoin((falloff * 150).cast(:uchar)).copy(interpretation: :srgb)
    end

    # Element-wise clamp of a 1-band image to [0, 1] (vips #min/#max reduce to
    # a single number, so they can't do this).
    def clamp01(img)
      img = (img < 0).ifthenelse(0, img)
      (img > 1).ifthenelse(1, img)
    end

    def eyebrow
      text("YOU'RE INVITED", "#{SERIF} 30", AMBER, spacing: 2600)
    end

    NAME_BUDGET = 250 # px; the tallest the headline may get before it crowds the eyebrow

    def name
      # Shrink to fit rather than clip: the largest size whose wrap stays within
      # the budget wins, so a short name is big and a long one steps down a size
      # instead of being cut through a glyph.
      [ 84, 68, 54 ].each do |size|
        layer = text(@society.name.to_s, "#{SERIF} Bold #{size}", CREAM, width: 1010)
        return layer if layer.height <= NAME_BUDGET
      end
      # Still too tall at the smallest size (a pathological name): drop trailing
      # words until it fits, with an ellipsis so the truncation is honest.
      text(truncated_name, "#{SERIF} Bold 54", CREAM, width: 1010)
    end

    def truncated_name
      words = @society.name.to_s.split
      while words.size > 1
        words.pop
        candidate = "#{words.join(' ')}…"
        return candidate if text(candidate, "#{SERIF} Bold 54", CREAM, width: 1010).height <= NAME_BUDGET
      end
      "#{words.first}…"
    end

    def wordmark
      text("WHISKEY SHARE SOCIETY", "#{SERIF} 24", CREAM.map { |c| (c * 0.55).round }, spacing: 2200)
    end

    # A rounded logo tile, or nothing.
    def logo_chip
      img = cover(vips(logo_blob), LOGO, LOGO)
      img.bandjoin(rounded_mask(LOGO, LOGO, 24))
    end

    # --- vips helpers -------------------------------------------------------

    def solid(rgb)
      Vips::Image.black(W, H).new_from_image(rgb).copy(interpretation: :srgb).cast(:uchar)
    end

    # Coloured text as an RGBA layer: render the glyphs as an alpha mask, then
    # paint a solid colour through it. `spacing` is pango letter-spacing in
    # 1/1024 em, used for the small-caps eyebrow feel.
    def text(string, font, rgb, width: nil, spacing: nil)
      markup = spacing ? %(<span letter_spacing="#{spacing}">#{ERB::Util.html_escape(string)}</span>) : ERB::Util.html_escape(string)
      alpha = Vips::Image.text(markup, font: font, width: width || 2000, dpi: 72, rgba: false, align: :low)
      colour = Vips::Image.black(alpha.width, alpha.height).new_from_image(rgb).cast(:uchar)
      colour.bandjoin(alpha).copy(interpretation: :srgb)
    end

    # Resize-to-cover a region, centre-cropped.
    def cover(image, w = W, h = H)
      image = image.colourspace(:srgb) unless image.interpretation == :srgb
      image = image.flatten(background: CHAR) if image.bands == 4
      scale = [ w.to_f / image.width, h.to_f / image.height ].max
      resized = image.resize(scale)
      resized.crop(((resized.width - w) / 2).clamp(0, resized.width),
                   ((resized.height - h) / 2).clamp(0, resized.height), w, h)
    end

    def rounded_mask(w, h, r)
      svg = %(<svg width="#{w}" height="#{h}"><rect width="#{w}" height="#{h}" rx="#{r}" ry="#{r}" fill="#fff"/></svg>)
      Vips::Image.new_from_buffer(svg, "", access: :sequential)[3]
    end

    # Composite `layer` (RGBA) onto `base` at (x, y).
    def over(base, layer, x = 0, y = 0)
      positioned = layer.embed(x, y, W, H, extend: :background, background: [ 0, 0, 0, 0 ])
      base.composite2(positioned, :over)
    end

    def vips(blob)
      Vips::Image.new_from_buffer(blob.download, "", access: :sequential)
    end

    def logo_blob
      @logo_blob = @society.profile_picture.attached? ? @society.profile_picture.blob : nil unless defined?(@logo_blob)
      @logo_blob
    end

    def banner_blob
      @banner_blob = @society.banner_image.attached? ? @society.banner_image.blob : nil unless defined?(@banner_blob)
      @banner_blob
    end
  end
end
