# Link-preview card

The default `og:image` / `twitter:image` for every page that does not set its own
(`app/views/layouts/application.html.erb`): `public/og-card-2026.png`, 1200x630.

- `card.html` is the source: the homepage look (paper, bottle green, Instrument Sans with
  one Source Serif 4 italic phrase) and the glass from `app/views/shared/_glass.html.erb`.
  Its words are the site name and the homepage hero heading; change them only with the
  owner's approval.
- `render.sh` renders it with headless Chrome on the host (needs Chrome and network for
  Google Fonts). It checks the fonts loaded and the PNG is exactly 1200x630 before writing.

```bash
tools/og-card/render.sh                      # writes public/og-card-2026.png
tools/og-card/render.sh /tmp/preview.png     # try a change without touching public/
```

Changing the card: render it to a **new** filename (Cloudflare caches the old one, and so
do iMessage and Slack), point the layout's default at it, update
`test/integration/link_previews_test.rb`, and delete the old PNG.
