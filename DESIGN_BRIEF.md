# WSS — From-Scratch Visual Rethink (design brief)

The current design system (char/paper, Fraunces, amber thread) is sound.
Starting fresh, I would keep the identity and change the ARCHITECTURE of the
experience. The current site is page-templated: every page is masthead +
white cards. Starting over, I'd design around the three operations and what
each is FOR:

## 1. Choosing a story → the shelf, not the catalog
End goal: the feeling of scanning a whiskey shelf, not filtering a SaaS grid.
- Library becomes cover-forward: tall deck "spines"/covers at varying visual
  weight (featured deck oversized), category as small stamped labels.
- Kill the uniform 3-col card grid; use an editorial mosaic. Search/filters
  collapse into one quiet bar.

## 2. Reading/presenting → the site IS the venue (better end goal)
Today the deck page sells a FILE. But we already render every slide
(slide_images). The better end goal: WSS is where you PRESENT.
- **Present mode**: owner clicks Present → full-screen, keyboard/tap-driven
  slide player (black surround, slide centered, n/N counter, Esc exits).
  No PowerPoint needed at the tasting — a laptop + browser is the venue.
- The deck page becomes a two-act page: Act 1 sell (cover, teaser, slides
  peek), Act 2 own (Present button, story, downloads). Fewer boxes: the
  sidebar card dissolves into a single action bar under the hero.

## 3. Gathering people → clubhouse, not info panel
End goal: "when's the next tasting and who's coming" in one glance.
- Society page leads with the next event as a big dated "ticket" (tear-off
  aesthetic), members as a face row, admin tools tucked into a drawer.
- The thread motif becomes the society's timeline: past tastings as knots on
  a vertical thread (event history = the society's story).

## De-carding principle (applies everywhere)
White rounded cards are doing all the separation work. Replace with:
editorial rules (.rule-double), whitespace, and max 1 elevated surface per
view. Boxes only for genuinely interactive clusters.

## Build order for a fresh session
1. Present mode (below — built) → 2. Library shelf → 3. Deck page two-act
restructure → 4. Society ticket/timeline → 5. De-card pass site-wide.
