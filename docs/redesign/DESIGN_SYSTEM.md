# WSS design system (2026 redesign)

Owner-approved direction, November 2026. The homepage (`app/views/home/index.html.erb`)
is the reference implementation: when this document and the homepage disagree, the
homepage wins and this document gets fixed.

Tokens live in `app/assets/tailwind/application.css`. Rebuild CSS after editing it:
`bin/rails tailwindcss:build`.

## The idea

A product-led site. Every visual is the real product showing real data: rendered slides,
real decks, real events, real scores. No colour stock photography, no illustration, no invented
numbers. The one exception is a photograph printed in the site's two inks (see Components). When the data is missing, the element does not render.

## Surfaces

| Surface | Class | Use |
|---|---|---|
| Paper | `bg-paper` (= `bg-whiskey-50`, `#f6f4ee`) | The page ground, everywhere. The `<body>` already has it. |
| Card | `.card` (white, 26px radius, hairline border, no shadow) | Anything grouped: a form, a list, a tile. |
| Inset | `.inset` (paper, 18px radius) | A short list of real data inside a card. |
| Green panel | `.panel-ink` (`bg-char`, 30px radius, cream text) | The one solid object on a view. At most one per view, plus the nav and footer. |

Rules:

- Flat white surfaces with a **hairline edge** (`border-hairline`). No drop shadows on
  cards. Shadows are reserved for objects that float: the nav, the deck player, menus.
- **Radii**: 26px cards, 30px green panels, 18px insets and media, 16px (`rounded-2xl`)
  buttons and inputs, 12px chips. Never sharp corners, never fully round pills for buttons.
- **No full-bleed dark mastheads.** Page headers sit on paper: a heading, one line of
  supporting text, the page's main action. The old `bg-char` hero bands are retired.
  A page that needs weight uses one `.panel-ink`.
- No gradients, no glass or blur, no glow, no decorative background shapes.

## Colour

| Token | Value | Use |
|---|---|---|
| `paper` / `whiskey-50` | `#f6f4ee` | Page ground |
| `whiskey-100`, `-200` | `#ecebe3`, `#dedccf` | Hover grounds, hairlines on paper |
| `hairline` | `#dfe3dc` | Card borders, dividers |
| `mute` | `#5f6b64` | Secondary text |
| `ink` / `char` / `whiskey-600` | `#16332a` | Headings, primary buttons, green surfaces |
| `whiskey-700` | `#10261f` | Primary button hover |
| `oak`, `oak-edge` | `#1d4034`, `#2f5546` | Raised surface and hairline on green |
| `cream` | `#f6f4ee` | Text on green |
| `mark`, `mark-soft` | `#ff6d00`, `#ff8a33` | The logo orange, for marks on green surfaces and the logo. 4.83:1 on green, but only 2.82:1 on white and 2.57:1 on paper, so never on a light surface. |
| `mark-deep` | `#e65c00` | Orange graphics on white or paper: stars, score bars, unread and live dots, focus outlines. 3.56:1 on white, 3.24:1 on paper (passes 3:1 for graphics). |
| `rsvp-yes/-maybe/-no` | unchanged | RSVP answers only |

Rules:

- Green and neutrals do all the work. **Orange is a mark, not a fill**: a step numeral, a
  rating star, an unread dot. On white or paper use `mark-deep`; use `mark` only on green
  and for the logo. **Orange is never text on a light surface** (neither token reaches 4.5:1
  there): date labels and required-field asterisks are ink. Never a button, a band or a background, except
  the HTML "pour" slide on the homepage, which mirrors the deck template.
- **No yellow, amber or mustard anywhere.** No blue, purple, emerald or red one-offs.
  Errors use Tailwind `red-700` text on `red-50`; success uses green ink on `whiskey-100`.
- The `whiskey-*` scale keeps its name but is now the green-neutral scale. Existing
  utilities keep working; prefer the named tokens (`paper`, `ink`, `mute`, `hairline`,
  `mark`) in new markup.
- Never interpolate class fragments (`bg-<%= x %>-50`): Tailwind cannot see them.
- Body text on paper is `text-gray-900`; secondary is `text-mute`. Minimum contrast 4.5:1.

## Type

- **Instrument Sans** for headings and UI: `font-display` (tight tracking is applied
  automatically) and `font-sans`.
- **Source Serif 4** (`font-reading`) for long reads (`.prose-deck`) and for the single
  italic *turning phrase* in a page heading, e.g. `Pick <em>a deck</em>`. One per heading
  at most, and only on page-level headings.
- Sizes: page heading `text-4xl sm:text-5xl font-semibold`; section heading
  `text-2xl sm:text-3xl font-semibold`; card heading `text-xl font-semibold`; body
  `text-base` or `text-[17px]`; meta `text-sm text-mute`.
- Sentence case everywhere. **No letterspaced small-caps labels** ("eyebrows"). The
  `.eyebrow` class survives as a plain small label; do not add new ones above headings.
  A heading that needs a label is usually a heading that should be rewritten.
- Numbers that line up use `tabular-nums`.

## Components

- **Glass**: the logo's tasting glass, flat and line-drawn, with an orange level. One shared
  partial, `shared/_glass` (a score is shown through `shared/_score`, which wraps it); it is never
  redrawn anywhere else. For a score, `level` is score / 5; for the table (RSVPs) going is 1, maybe
  0.5, unanswered 0; in a verdict the numeral is the serve order. Tones: `:ink` on paper and white,
  `:cream` on green. Minimum size 28px. It always sits beside its number or count (or carries
  sr-only text), is aria-hidden, and has no shading. Its one motion is the pour (see Motion). Replaces star rows for display;
  the half-step star control in review forms is an input and stays.
- **Photograph**: only through `shared/_duotone`, which prints a greyscale image in bottle green
  and cream. Public-domain or owner-supplied images, or free-licence stock (Unsplash, Pexels)
  credited in `IMAGE_CREDITS.md` with the owner's approval of each photo; at most one per view,
  never behind text. Photographs of people use the heavy variant (`duotone--heavy`: light in
  orange, shadows in ink, softened by a 1.5px blur), which keeps faces unrecognisable. Sources and licences are listed in `IMAGE_CREDITS.md`.
- **Primary button**: `btn btn-primary` (green, white text, 16px radius). One per view.
- **Secondary button**: `btn btn-secondary` (white, hairline).
- **Text link with arrow**: bold ink text followed by `→`. Write it as `link_to with_arrow("Words"), path` so the
  arrow is its own span (`.arrow`) and nudges on hover; the link's text is unchanged.
- **Chip**: `inline-flex min-h-9 items-center rounded-xl border border-hairline bg-white px-3.5 text-sm font-medium text-ink`.
- **Step or count marker**: 32px rounded-[11px] paper square with a bold numeral.
- **Lists of records**: rows separated by hairlines inside a `.card` or `.inset`. Title in
  bold ink on the left, meta in `text-mute`, the number or action on the right. Not a grid
  of small cards.
- **Forms**: one `.card` per form, labels above inputs in `text-sm font-medium`, inputs
  `rounded-2xl border-hairline bg-white px-4 py-3`, focus ring `ring-2 ring-ink/30`.
- **Empty states**: one sentence saying what will appear here and one action. No emoji.
- **Icons**: inline SVG, 1.8 stroke, `currentColor`. No emoji as icons.
- **Deck covers**: the deck's first rendered slide (`slide_images.order(:id).first`), else
  its `featured_image`, else a plain `bg-char` block. Never the title typed on a box.
  The deck page drops its cover column when there is no cover; the plain block is for
  library cards only.
- **Avatars**: profile image, else initials on `bg-whiskey-100 text-ink`. Not `avatar_color`.

## Layout

- Content width `max-w-6xl` (non-full-bleed pages get it from the layout) or the
  homepage's 1240px wrap. The floating nav is 12px from the top; page content starts at
  `pt-24` or lower.
- Left-aligned by default. Centre only short, self-contained things (auth card, 404).
- Two-column page pattern: heading and text in the narrow column (5/12), content in the
  wide one (7/12). Single column below `md`.
- Phone first: every page must be usable at 390px with **no horizontal scroll**
  (`document.documentElement.scrollWidth === 390`). Tap targets at least 44px.
- CSS traps, still true: no `overflow-x: hidden` or `height: 100%` on `body`/`main`
  (breaks `position: sticky`); the admin `main` is `lg:ml-60 min-w-0`, never `flex-1`;
  order `slide_images` by `:id`.

## Motion

Quiet and functional. Movement is only `transform`, `translate` or `scale`, and fades only
`opacity`; hover and press states may also change colour, background and `box-shadow` (the
homepage buttons and chips do). Never animate layout (width, height, margins). Two curves, as
tokens in `application.css`: `--motion-ease-out` (`cubic-bezier(0.23, 1, 0.32, 1)`) for things
arriving and for presses, and `--motion-ease-pour` (`cubic-bezier(0.2, 0.7, 0.2, 1)`) for the
glass and the view transitions. No animation library.

- **Press**: buttons, tappable cards, chips, the homepage buttons and pricing rows press in to
  `scale: .98` on `:active`, going in over 80ms on the strong ease-out, and step their fill a
  shade (primary to `whiskey-700`, secondary, ghost and chips to `whiskey-100`); release takes
  the element's own 150ms. This is the only feedback a phone gets (preflight hides the iOS tap
  highlight; `application.js` adds the touchstart listener iOS needs for `:active`).
- **Hover** (150ms): lifts of 1–3px; a deck cover scales to 1.02 inside its frame; an arrow
  after a link's words moves 3px (`with_arrow`, or `class="arrow"` on an arrow span; the
  homepage's `.more` arrow matches). Hand-written `:hover` rules sit inside
  `@media (hover: hover) and (pointer: fine)` so a tap never leaves them stuck; Tailwind's
  `hover:` variant is already limited to `(hover: hover)`. Focus-visible styles are never
  changed by motion; keyboard focus on the hero player pauses its reel.
- **Reveal on first view**: one system, the `appear` Stimulus controller on the public layout's
  `<main>`. Mark a card, list row, short panel or section heading with
  `data-appear-target="item"`. Out of view at load, it waits hidden and, the first time it
  comes properly into view (its top above the bottom 18% of the screen, where the eye is,
  not at the bottom edge), eases up 24px (16px on phones) and fades in over 700ms. Items that arrive in the
  same moment stagger by 0, then 60, then 110ms and so on (the gaps shrink, capped at 200ms); in
  practice that is cards side by side in a grid on a wide screen, so most reveals, and nearly
  all on a phone's single column, start at once. Rules: the hidden state is a class the
  controller adds (no JS means visible); anything on screen at load is left alone; it is
  time-based, runs once and then removes its classes; because the triggers sit inside the
  screen, something can be on screen and still waiting, but only while the page is scrolling:
  when the scroll or a resize settles (150ms) everything waiting on screen starts its motion
  (started, not snapped; only what a jump carried past is shown at once), and a one-off 1.5s
  limit does the same even if the observer never fires;
  focusing anything inside a waiting item shows it at once; print shows everything; Turbo
  snapshots and back/forward visits are never hidden.
  **Never mark anything taller than about one screen**: mark its heading (a deck section's
  heading column, a tall card's heading row) and let the content stand. Reading text never fades.
  The controller refuses to hide an item taller than 1.2 times the viewport as a safety net.
  One entrance per container: never mark an item inside another item, and mark a group of
  words that read together (a homepage beat's numeral, heading, text and link) as one item.
  Never mark the header, the footer, a form someone types in, the page heading, the homepage's
  closing beat, or anything in admin (its layout has no controller). Never scroll-scrub a
  reveal (`animation-timeline`): it stops part-faded wherever the scroll stops. Print shows
  every start state at its final picture.
- **Secondary motion**, the same controller: things inside a card that play once when seen.
  Each kind has a start-state class the controller adds (`*-wait`) and a class that plays it
  (`*-run`), both removed when it is done, so the server's markup is always the final picture.
  It starts later than a reveal, once it is well on screen (it reaches the middle 60% of the
  viewport), and lasts long enough to be watched. One inside a card starts at least 120ms after
  its card starts to show (starting the card first if it is still waiting) and is shown at once
  whenever its card is; one outside a card plays on its own trigger. On screen at load: a
  draw-in plays 300ms after a Turbo visit (a click within the site; never back or forward), so
  a review's wheel above the fold is seen to draw. Not on a full page load, where the browser
  may already have painted the finished drawing and replaying it would flash (drawn, collapsed,
  redrawn). A glass pours on load only before the first paint, as before; a face or a photo on
  screen at load is left alone. These durations are the standard, set by the owner in
  November 2026 ("too soon for us to see"): reveal 700ms, pour 1.2s, draw-ins about 1.2s,
  faces about 900ms, photo settle 1.2s.
  - **The glass pours** (1.2s; `glass`, set by `shared/_glass`). At rest, without JS and in
    admin the level is simply drawn. `appear: false` leaves a glass out (a gauge another
    controller drives).
  - **Draw-ins** (`draw`, about 1.2s: the wheel's wedges 600ms each with delays up to 440ms,
    labels at 850ms; the wave's stems 500ms, its line 1s, labels at 900ms), only on drawings that carry a value: the palate wheel's
    lit wedges grow out from under the hub one after another (from the scale that puts their
    edge at the hub, never from 0; scaled about the wheel's centre with `transform-box:
    view-box`, checked in Chrome and WebKit), the flavor wave's stems grow from the base to their
    value and its line draws left to right (`pathLength="1"` and `stroke-dashoffset`); labels
    fade in last. Gaps shrink. The wheel's wedges stay inside their links, clickable throughout.
  - **The homepage step faces perform** (`perform` on each face's screen, about 900ms; rows
    500ms each with gaps 90, 80, 70, 60, 50ms): the
    library's rows tick in one by one, the invite's guests pop in from `.7` (never from 0), the
    record's words settle while its wheel draws. CSS in `home/index`.
  - **Photographs settle** (`photo` on `shared/_duotone`): from `scale: 1.04` to 1 over 1.2s
    inside the frame, which clips it, so nothing moves around it.
- **Images fade in as they load** (`image` on deck covers, the deck page's slides, bottle photos
  and duotone photos): only an image not yet loaded when the page starts, 200ms on the strong
  ease-out. A cached image is never touched (no flash); one that fails, or sits on screen for 2s
  without loading, or is on a page Turbo caches, is shown at once.
- **The hero player** cross-fades its real preview slides, one tick per slide lit in step (a
  one-slide reel does not cycle); hovering with a pointer or focusing it pauses the reel. Only the
  hero has ticks: the step faces' bars carry just their title (ticks there read as a sideways
  carousel, when the faces change with the vertical scroll).
- **The story glass** (homepage only, `home/_story_glass`, `story_glass_controller.js`): one
  glass that fills as the reader scrolls through the story, empty when the first step's words
  are mid-screen and full when the closing beat's heading is. It follows the scroll directly
  (it is a gauge, not a reveal, so `appear: false` keeps it out of the pour). Desktop: a 96px
  gauge in the gutter between the step words and the face, sticky at the middle of the screen;
  the beats keep 28px of right padding so the words never meet it. Phones: 40px in the
  bottom-right corner, inside the 20px page gutter, shown only while the steps are on screen.
  aria-hidden, no words, `pointer-events: none`, out of the flow (no layout shift), hidden
  until its controller runs and in print. Under reduced motion it steps a third at a time as
  each step is reached instead of following the scroll.
- **Pages** cross-fade (view transitions), and a deck's cover travels from its card to the deck
  page. Turbo's progress bar is a 2px `mark-deep` line.
- **Reduced motion** (`prefers-reduced-motion: reduce`), the same everywhere: the appear
  controller does nothing, so nothing is hidden, no glass pours (the story glass steps), nothing draws in, no face
  performs, no photo settles and no image fades; the reel and ticks stand still on the first
  slide; view transitions are off; nothing travels on hover (no card lift,
  cover lean or arrow nudge). The press (fill step and `.98`) and colour changes stay: they are
  feedback, not travel.

## Copy

User-facing copy is **reused, never invented**. A redesign task moves and trims existing
words; any new sentence, label or claim must be listed in the task's hand-back under
"New copy for owner approval". Remove claims the product does not deliver. No fabricated
reviews, stats, ratings or guarantees.

## Rejected directions — do not reintroduce

Brown-and-amber "whiskey" palette · any yellow or mustard · flat full-bleed colour-block
sections with oversized type · letterspaced small-caps eyebrows · display-serif headings ·
glassmorphism, gradient text, blur blobs · skeuomorphism (shelves, book spines, plaques) ·
hard offset "sticker" shadows · title-on-a-black-box deck covers.
