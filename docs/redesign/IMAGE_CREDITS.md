# Photograph credits

The site uses photographs only through `shared/_duotone`, printed in green and cream.
The two Wikimedia files are greyscale copies of public-domain images; the tasting-night
image is owner-supplied; the three stock files (Pexels, Unsplash) are interim, approved by
the owner one by one, and printed in the heavy duotone (`duotone--heavy`, light in orange,
shadows in ink, with a 1.5px blur) so no face is recognisable.

| File | Subject | Source | Rights |
|---|---|---|---|
| `app/assets/images/photos/saloon-1897.jpg` | A saloon in Black Hawk, Colorado, 1897 | Commons: "1897 Saloon Blackhawk.jpg" (Library of Congress) | Public domain in the US (published before 1929) |
| `app/assets/images/photos/rickhouse.jpg` | Barrels at Woodford Reserve, Kentucky, 2013 | Commons: "Woodford Reserve Distillery-27527-6.jpg", Ken Thomas | Released to the public domain by the photographer |
| `app/assets/images/photos/tasting-night-living-room.jpg` | Friends at a tasting in a living room, one presenting by the TV | Owner-supplied, AI-generated (November 2026). Greyscale, cropped above the table, shadows lifted for the tint | No photographer, model release or licence involved |
| `app/assets/images/photos/signin-sofa-lamp.jpg` | Four friends on a sofa and rug under an arc lamp, glasses in hand | Pexels, https://www.pexels.com/photo/people-sitting-in-the-living-room-8556115/, Polina Tankilevitch. Greyscale, cropped to 4:5, 640px wide so faces stay soft (2026-11-22) | Pexels License (free to use, no attribution required; credited here). Interim stock photo, owner-approved, to be replaced by generated images |
| `app/assets/images/photos/reviews-glass-book.jpg` | A whisky tumbler held over an open book by the fire | Unsplash, https://unsplash.com/photos/a-person-reading-a-book-and-drinking-a-glass-of-whiskey-kJMgr2LT4RQ, OurWhisky Foundation. Greyscale, cropped to 4:3 (2026-11-22) | Unsplash License (free to use; credited here). Interim stock photo, owner-approved, to be replaced by generated images |
| `app/assets/images/photos/deck-pour-decanter.jpg` | A hand pouring from a cut-glass decanter in a lamp-lit sitting room | Pexels, https://www.pexels.com/photo/a-person-pouring-brown-liquid-in-the-glass-4457112/, Taryn Elliott. Greyscale, cropped to 3:1 (2026-11-22) | Pexels License (free to use, no attribution required; credited here). Interim stock photo, owner-approved, to be replaced by generated images |

Used on: `/societies` signed out (saloon), `/membership` (rickhouse), the homepage's third
slide (tasting night). The homepage prints it in that slide's own two inks, light in orange
and shadows in ink, through `shared/_duotone` with a page-scoped class (`.invite-photo`).
The stock photographs: `/auth` beside the form on wide screens (sofa and lamp), the
signed-in `/reviews` rail on wide screens (glass and book), and the deck page as a band
after the story (decanter).
