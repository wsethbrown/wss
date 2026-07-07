---
name: wss-deck-pipeline
description: The WSS deck lifecycle — import from pptx/ppt/pdf, background slide rendering, the story teaser gate, markdown pipeline, Present mode, tags. Use for anything touching deck authoring, display, or files.
---

# WSS Deck Pipeline

## Import (admin → New Presentation → "Start from your deck file")
Accepts .pptx (full XML parse: per-slide text + embedded images), .ppt/.pdf
(LibreOffice→PDF→pdftotext for a per-page draft). Creates an UNPUBLISHED
draft: title, story skeleton (## chapter per slide), slide-preview rows,
cover + up to 3 preview images (only images ≤ Presentation::MAX_IMAGE_SIZE,
15MB — oversized embeds are skipped, never fatal), the file attached as the
buyer download. Philosophy: **import drafts, humans polish, never
auto-publish** — the narrative voice is the product.

### The two iron rules of import code
1. **Read the upload ONCE** (`data = file.read`), hand every consumer its own
   StringIO. Re-reading the request tempfile after attach ⇒
   ActiveStorage::IntegrityError at save.
2. **LibreOffice never runs in the web process.** DeckSlideRenderJob renders
   slides in the jobs container (soffice→pdf→pdftoppm PNGs, attached as
   slide_images). Import returns immediately; slides appear when the job
   lands. Inline rendering once crashed the whole dev container.

## Story rendering & the teaser gate
- render_markdown (PresentationsHelper): redcarpet, filter_html + sanitize
  allowlist, **NO hard_wrap** (hard_wrap turned authors' wrapped lines into
  <br> shreds — a real regression; don't re-add).
- Non-owners see the first ~24 SOURCE lines (preview_markdown cuts the source
  — hidden content never reaches the DOM), fading into a purchase CTA.
  Owners/admins (@full_story via can_download_full_presentation?) read all.
- The reading UI: .prose-deck with drop cap + the amber thread progress bar.

## Slides on the deck page
One "The slides" section: slide_images (order(:id) — NOT :filename, no such
column) rendered as pages; non-owners see first 3 + "N more" CTA; falls back
to the text outline rows when no renders exist. There is deliberately no
separate preview-images section anymore.

## Present mode (/presentations/:id/present)
Full-screen slide player (layout: false, black surround, arrows/space/click,
f fullscreen, esc exits, n/N counter). Owners+admins with slide_images only;
others bounce to the deck page. This is the product's "venue" feature —
protect it.

## Authoring form specifics
- Category: free-text + datalist (existing categories + defaults) — never a
  fixed select.
- Tags: comma-separated tag_names virtual attr (lowercased, max 10,
  find_or_create Tag category 'deck'); chips on cards; popular-tags filter
  row on the library.
- Story field: EasyMDE (importmap CDN pin) with SERVER-side preview (POST
  /admin/presentations/preview runs the real render_markdown) — preview must
  always equal the buyer-facing render.
- Structured editors (Stimulus): what-youll-learn, whiskey-recommendations,
  slides-preview (rows serialize to legacy pipe/dash text formats — no
  migrations). Slide numbers derive from row order.

## Files
pdf_file (buyer download; pptx/ppt/pdf allowed) · sneak_peek_file (public) ·
speaker_notes/outline_file/recommendations_sheet (owner downloads) ·
supplemental_materials (owner "Extras") · featured_image (cover) ·
preview_images (≤3) · slide_images (rendered pages). Downloads box renders
ONLY when files exist; otherwise an honest "being prepared" note.

## Slide rendering: fonts and the publish gate

Rendered slides looked mangled ("Bar dst own") whenever a deck used a font the
container lacked — LibreOffice substitutes with wrong metrics. Both images now
install metric-compatible substitutes: Carlito (Calibri), Caladea (Cambria),
Gelasio (Georgia, shipped in `docker/fonts/`), Gillius ADF (Gill Sans), plus
DejaVu/Noto. `docker/fonts/60-wss-substitutes.conf` maps Georgia/Gill Sans by
name. If a new deck renders with broken spacing, check its fonts
(`grep -ohE 'typeface="[^"]+"' ppt/slides/*.xml | sort | uniq -c` on the
unzipped pptx) and add a substitute + mapping the same way.

Two traps encountered here:
- Tailwind v4's precompile scanner crashes (`RangeError ... code points`) on
  binary files it can't skip. `docker/` is excluded via `@source not` in
  `app/assets/tailwind/application.css`, and `storage/*` is in `.dockerignore`
  (Active Storage blobs are extensionless, so the scanner can't skip them by
  extension — and dev blobs never belong in an image anyway).
- `docker compose build web` does NOT rebuild the `jobs` image even though both
  use Dockerfile.dev — each service tags its own image. Build both:
  `docker compose build web jobs`.

Publishing requires the deck file AND rendered slide previews
(`Presentation#ready_to_publish`): `slides_rendered?` = slide_images attached;
`slide_render_pending?` = an unfinished, non-failed DeckSlideRenderJob for this
deck in Solid Queue. Renders enqueue automatically on import, on create with a
deck file, and on update that replaces the deck file; admins can also force one
via the "Re-render slide previews" button (POST render_slides). The admin show
page's Actions panel walks the states: no file → rendering → ready to publish →
published.
