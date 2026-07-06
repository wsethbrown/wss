---
name: wss-design-system
description: WSS visual identity, tokens, layout rules, CSS traps (sticky/overflow), and REJECTED design directions. Use for any UI change, new page, or layout bug.
---

# WSS Design System

Source of truth: app/assets/tailwind/application.css (@theme tokens +
components). Full direction + rejections: DESIGN_BRIEF.md.

## Identity: two surfaces, one thread
- **char** (#191009) — dark "tasting room" for narrative surfaces: nav,
  footer, heroes/mastheads, deck covers, FAQ. Elevated dark = **oak**
  (#261a10), hairlines = **oak-edge**.
- **paper** — whiskey-50/white for utility: catalogs, forms, account, admin.
- **whiskey-50..950** — the only accent scale. NEVER purple/blue/emerald
  one-offs; the old site's gradient soup was purged deliberately.
- **The thread** — thin amber line motif (.thread): hero underline, deck
  reading progress. Signature; use sparingly.

## Type
Fraunces (font-display; headings only) · Instrument Sans (font-sans; UI) ·
Source Serif 4 (font-reading; deck stories via .prose-deck). Google Fonts
loaded in both layouts.

## Reusable pieces (use these, don't reinvent)
.eyebrow (small-caps letterspaced label) · .rule-double (label masthead rule)
· .thread · .prose-deck / .prose-deck--dropcap (rendered markdown reading
styles) · .pagination (kaminari) · btn/card/badge component classes.
Every heading pattern: eyebrow → font-display heading → .rule-double.

## Layout rules & CSS traps (each cost hours — respect them)
1. **position: sticky dies if any ancestor scroll-container exists.**
   NEVER put `height: 100%` or `overflow-x: hidden` on body/main. Body uses
   `overflow-x: clip` (clip ≠ scroll container). Pinned sections use
   grid + `md:self-start md:sticky md:top-0 md:h-screen`.
2. **Full-bleed pages** (home, societies index/show, all presentations pages)
   manage their own nav clearance INSIDE their masthead (pt-16/pt-28). The
   layout adds NO top padding for them (a leftover pt-20 once rendered as a
   white strip above every masthead). See the `full_bleed` conditional in
   layouts/application.html.erb.
3. **Admin layout**: fixed sidebar + `main.ml-60.min-w-0`. NEVER flex-1 on
   main — with a fixed (out-of-flow) sidebar it takes full viewport width and
   overflows right by exactly 240px.
4. **Attachments have no filename column** — order slide_images by :id (job
   attaches in page order). `.order(:filename)` 500s.
5. **No emoji as icons.** SVG (heroicons-style inline) only. One exception:
   the 🥃 empty-state glyph on societies index.
6. **Tailwind can't see dynamic classes** (`bg-<%= color %>-50`). Never
   interpolate class fragments.

## Copy voice
Plain verbs, sentence case, specific. Whiskey-label vernacular where natural
("Est. 2019", "the pour", chapters). No hype ("world-class"), no invented
claims (guarantees, stats). CTAs say what happens: "Get this deck — $12.99".

## REJECTED directions — do not re-propose
- **Skeuomorphism** (wooden shelf planks, book spines, brass plaques):
  built, owner-rejected July 2026 as costume-not-design. Evolution must be
  editorial (type/layout weight), never literal object imitation.
- Glassmorphism, gradient-text headings, animated blur blobs: the pre-
  overhaul look. Purged; do not reintroduce.
- **De-carding principle**: prefer rules/whitespace over adding more white
  rounded boxes; max one elevated surface per view.

## Preview system for risky redesigns
`?design=next` renders `<action>_next.html.erb` variants (DesignPreview
concern; all sessions in dev, admin-only in prod). Build bold ideas as
parallel templates; promote by renaming over the original in one commit.
