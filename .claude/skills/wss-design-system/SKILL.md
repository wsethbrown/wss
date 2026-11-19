---
name: wss-design-system
description: WSS visual identity, tokens, layout rules, CSS traps (sticky/overflow), and REJECTED design directions. Use for any UI change, new page, or layout bug.
---

# WSS Design System

**The 2026 redesign replaced the char/amber/Fraunces system.** Source of truth:
`docs/redesign/DESIGN_SYSTEM.md` (rules, tokens, components, rejected directions) and
`app/assets/tailwind/application.css` (tokens). Reference implementation: the homepage,
`app/views/home/index.html.erb`. Read the design-system doc before any UI change.

## In one paragraph
Warm paper ground; white rounded cards with a hairline edge and no shadow; bottle green
(`char`/`ink`) for headings, primary buttons, the floating nav, the footer and at most one
solid panel per view; the logo orange (`mark`) only as a small mark. Instrument Sans for
headings and UI, Source Serif 4 for long reads and one italic turning phrase per page
heading. Every visual is real product data. Sentence case, no small-caps eyebrows.

## Traps (each cost hours)
1. **`whiskey-*` is green now.** The scale kept its name; 50-200 are paper and hairlines,
   500-950 are greens. `bg-whiskey-600` on a `bg-char` surface is invisible.
2. **position: sticky dies if any ancestor is a scroll container.** Never `height: 100%`
   or `overflow-x: hidden` on body/main; body uses `overflow-x: clip`. The homepage's
   pinned presentation depends on this.
3. **The nav floats** 12px from the top, so pages start at `pt-24`. Full-bleed pages
   (see the `full_bleed` list in `layouts/application.html.erb`) clear it themselves.
4. **Admin layout**: fixed sidebar + `main.ml-60.min-w-0`. Never `flex-1` on main.
5. **Attachments have no filename column**: order `slide_images` by `:id`.
6. **Tailwind can't see dynamic classes** (`bg-<%= color %>-50`). Never interpolate.
7. **A global `.btn` exists.** Don't reuse that class name for a page-scoped style.
8. **Rebuild CSS** after touching `application.css`: `bin/rails tailwindcss:build`
   (the dev Procfile watcher does it; a bare `rails server` does not).

## Copy
User-facing copy is proposed, never just edited. Redesign work reuses existing words and
lists anything new for owner approval. No fabricated content.

## REJECTED directions — do not re-propose
Brown/amber palette; any yellow or mustard; flat full-bleed colour-block sections with
oversized type; letterspaced small-caps eyebrows; display-serif headings; glassmorphism,
gradient text, blur blobs; skeuomorphism (shelves, spines, plaques); hard offset sticker
shadows; title-on-a-box deck covers.

## Design studies kept for reference
`/?design=next` and `/?design=next2` render two earlier homepage studies (admin-only in
production). The owner asked to keep them; do not delete without asking.
