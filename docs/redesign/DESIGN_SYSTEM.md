# WSS design system (2026 redesign)

Owner-approved direction, November 2026. The homepage (`app/views/home/index.html.erb`)
is the reference implementation: when this document and the homepage disagree, the
homepage wins and this document gets fixed.

Tokens live in `app/assets/tailwind/application.css`. Rebuild CSS after editing it:
`bin/rails tailwindcss:build`.

## The idea

A product-led site. Every visual is the real product showing real data: rendered slides,
real decks, real events, real scores. No stock photography, no illustration, no invented
numbers. When the data is missing, the element does not render.

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
| `mark`, `mark-soft` | `#ff6d00`, `#ff8a33` | The logo orange. Small marks only. |
| `rsvp-yes/-maybe/-no` | unchanged | RSVP answers only |

Rules:

- Green and neutrals do all the work. **Orange is a mark, not a fill**: a step numeral, a
  rating star, a date label, an unread dot. Never a button, a band or a background, except
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

- **Primary button**: `btn btn-primary` (green, white text, 16px radius). One per view.
- **Secondary button**: `btn btn-secondary` (white, hairline).
- **Text link with arrow**: bold ink text followed by `→`.
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
  (breaks `position: sticky`); the admin `main` is `ml-60 min-w-0`, never `flex-1`;
  order `slide_images` by `:id`.

## Motion

Quiet and functional: 150ms hover lifts of 1–3px, the hero player's slide change, and
scroll-in reveals. Everything is disabled under `prefers-reduced-motion: reduce`.

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
