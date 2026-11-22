# Across the River: proposed changes for the owner

This deck was remade from the older builder's package (`tmp/deck-packages/Across-the-River/`) with
its words kept as they were. Only mechanical fixes were made (listed at the end). Everything below
is a proposal and is **not** in the deck yet. Sources: the independent review
(`tmp/review/decks/Across-the-River.md`, "R" plus its item number, "R minor" for its minor list)
and my own read of the script against the slides and the outline ("found").

Each item: where, current text, proposed text, why.

## A. Facts and hedges

1. **Slide 10 (slide row), found.** The slide contradicts the outline's own trap.
   Current: "1930 · Canada amends its Export Act and stops clearing liquor shipments to the US."
   Proposed: "1930 · Canada amends its Export Act and stops clearing liquor shipments to countries that ban it."
   Why: outline Module 5, Traps: "Canada's 1930 law did not name the US; say "countries that banned import"." The script already says it "was written in general terms".

2. **Slide 11 (slide card and script). Aged stocks at Repeal.**
   Current, slide: "1933 · Repeal. Seagram has aged stock to sell." Script: "At Repeal, American distillers had been largely shut for thirteen years and had little aged whiskey. Canadian distillers had been required to age theirs, and they had stock to sell."
   Proposed, slide: "1933 · Repeal. Seagram is ready to sell in the US." Script: "The usual account is that at Repeal American distillers, shut for most of thirteen years apart from a few licensed for medicinal whiskey, had little aged whiskey, while Canadian distillers, required to age theirs, had stock to sell."
   Why: outline Module 6 trap says the comparison "is often asserted without figures"; "largely shut" skips the medicinal licences (R should-fix 5). Or find the 1933 Internal Revenue warehouse figures and keep the wording.

3. **Slide 15 (slide card and script). Interpretation stated as fact.**
   Current, slide (green card): "All-rye and high-rye bottlings, a small share of exports until recently." Script: "especially from the 1950s to the 1970s, the Canadian whiskies that sold in huge volumes in the US were the big blends" and "Since the 2000s more of them have been bottled on their own, like the Lot No. 40, and the range of what's sold in the US is a lot wider than it was."
   Proposed, slide: "All-rye and high-rye bottlings, by most accounts a small share of exports until recently." Script: "By most accounts, especially from the 1950s to the 1970s, ..." and "It looks as if, since the 2000s, more of them have been bottled on their own ..."
   Why: Module 8 says "Nothing in this module was independently confirmed"; "Since the 2000s more all-rye bottlings" is on the Not confirmed list (R should-fix 6).

4. **Slide 10 (script). Claims not in the outline.**
   Current: "Canada's temperance laws were mostly provincial and about selling drink to Canadians. Making and exporting whisky was federal, and stayed legal." / "The papers for a shipment would name a destination like Cuba or Mexico, and a fast boat could reach the Michigan shore in minutes. The Detroit River is narrow, with islands in it, and in winter it freezes."
   Proposed: add sources to Module 5 (the Royal Commission report, a history of Ontario temperance), or hedge: "The usual paperwork named a destination like Cuba or Mexico ..." and cut "and in winter it freezes" (the outline warns against frozen-river stories). Consider "Federal wartime prohibition stopped manufacture briefly in 1918 and 1919" if sourced.
   Why: R should-fix 7.

5. **Slide 10 (script). The three-quarters figure.**
   Current: "You'll read that three quarters of the liquor smuggled into the US came across it; I haven't found where that figure comes from, so I wouldn't repeat it."
   Proposed: cut the sentence.
   Why: it repeats the figure while saying not to (R should-fix 9).

6. **Slide 2 (script). The millers opening.**
   Current: "These are names you still see on Canadian bottles, and almost all of them started as millers. Upper Canada grew far more wheat than it could sell, and turning surplus grain into spirit was the usual thing for a mill to do with it."
   Proposed: "These are names you still see on Canadian bottles, and most of them had mills." Cut the wheat sentence or add a source to Module 1.
   Why: the wheat surplus is not in the outline, and by the outline's own facts Wiser came to run a distillery and Walker was a grain merchant (R should-fix 8).

7. **Slides 7 and 8 (script and slides). The method has no sources.**
   Current: Module 4 has one "Nailed down" line and no Sources list.
   Proposed: add sources to Module 4 (de Kergommeaux's book, canadianwhisky.org, the Hiram Walker, Gimli and Forty Creek pages, 27 CFR Part 5 for US blended whiskey) for: grains mashed and distilled separately; base whisky from corn, column-distilled close to neutral, aged in used barrels; flavouring whisky from rye at lower strength, sometimes in a pot still; American blended whiskey may contain neutral spirit.
   Why: R should-fix 4. The claims are standard; no wording change proposed.

8. **Script hedges in the first person** (R should-fix 9). Proposed neutral hedges:
   - Slide 2: "I haven't seen that measured, so I'd say "one of the largest"" → "nobody measured it, so call it "one of the largest"."
   - Slide 3: "I've never seen the rule pinned down, so treat that as the company's version." → "That is the company's version; the rule itself has not been found."
   - Slide 4: "You'll often read that the two-dollar tax was several times what the whiskey cost to make; I haven't found a production-cost figure to check that against." → cut the sentence.
   - Slide 6: "Canadian writers say it was the first country to require this. I can't confirm that, but it was well ahead of the United States" → "Canadian writers say it was the first country to require this; nobody has shown it. It was certainly well ahead of the United States".
   - Slide 13: "It's often linked to German and Dutch settlers; I haven't seen the evidence for that part." → "It's often linked to German and Dutch settlers, with little evidence."

9. **Slide 2 (slide card).** Current: "1859 · Henry Corby · Corbyville". Proposed: "Belleville (later Corbyville)", or "Hayden's Corners". Why: the village was renamed in 1882 (R minor 10).

10. **Slide 13 (script).** Current: "American law is different: an American straight rye must be at least 51 percent rye." Proposed: "American law is different: an American rye whisky must be at least 51 percent rye." Why: any American rye must be, not only straight rye (R minor 11).

11. **Slide 9 (script).** Current: "made by Corby at the same Hiram Walker distillery in Windsor; the two companies share the site now." Proposed: "made for Corby at the same Hiram Walker distillery in Windsor, which Pernod Ricard runs." Why: loose as worded (R minor 12).

12. **Slide 16 (slide, deck.json, setup list). Forty Creek's name.**
    Current: "Forty Creek Copper Pot Reserve" everywhere but the script. Proposed: check the current US label; if new stock says Copper Bold, use "Forty Creek Copper Bold (formerly Copper Pot Reserve)" on the slide and in deck.json `pours[3].name`. Why: R should-fix 12. Not checked here.

13. **Slide 7 (slide).** The "barrel, years" column repeats four times; corn is shown only as base though slide 8's script says corn is sometimes flavouring; "Blended after ageing" sits beside slide 5's point that Canadian Club blends before ageing. Proposed: drop the barrel column, and change the green card to "Usually blended after ageing". Why: R minor 9.

14. **Slide 17 (script), found.** Current: "And caramel and flavouring are allowed, a bottle sold here may hold up to 9.09 percent of other spirits or wine, and you usually won't be told." Proposed: "And caramel and flavouring are allowed. A bottle sold in the US may hold up to 9.09 percent of other spirits or wine, and you usually won't be told." Why: a comma splice, and "here" is ambiguous in a deck about two countries.

## B. The host's kit (speaker notes, Part One) and the close

These are genuinely missing host content. Nothing was invented for them.

15. **READ THIS FIRST line (missing).** Proposed, from the notes' own words: "_READ THIS FIRST. Put water and a little soda water out for the first pour; two of the four are 43%._" (R should-fix 10)
16. **Bottle ideas by role, with swap-ins and dated prices (missing).** Roles: the light Canadian blend (pour 1), an all-rye flavouring-style whisky (pour 2), a second big blend from another company (pour 3), a craft blend made by the separate-grain method (pour 4). Needs research and a dated US price check; not done here. The outline says "Prices vary too much by region to quote" (R should-fix 10).
17. **Pour cues (missing).** Proposed stage directions at the top of slides 5, 9, 12 and 16: "_Pour glass 1 now._" (2, 3, 4).
18. **The first pour comes at slide 5, about 8 minutes in** (R minor 13). Proposed: a stage direction at slide 1, "_Pour glass 1 now._", leaving the slide 5 introduction where it is. A structural choice for the owner.
19. **Running order adds up to 48 minutes; the notes and deck.json say 45.** Proposed: trim slides 1 to 4 to 6 minutes, or change `duration` to "50 min" and the notes' first line to "about 50 minutes".
20. **Slide 18 (slide) has no closing thought; the script is one line.** Current script: "Thanks for listening, and to whoever brought the bottles. Sláinte." Proposed toast for the slide and the script: "To the river, and to the whisky that crossed it." (R should-fix 11)

## C. Headings and slide wording

21. **Slide 1 (hook) and deck.json `description`.** Current hook: "How Canadian whisky is made, and how it came to supply the United States." Proposed: "For a century, a lot of America's whiskey was made within sight of Detroit." (R should-fix 3)
22. **Slide 8.** The old slide had no heading; its two card titles serve as one, and the script heading "Base whisky and flavouring whisky" names both (Grocers and Grain precedent; no heading added). Proposed heading: "Two kinds of whisky go into every blend" (R minor 5).
23. **Slide 17 heading and slide 2 heading** are labels (R minor 5). Proposed: slide 17 "What a Canadian label does and doesn't tell you"; slide 2 "Five Ontario mills became whisky names, 1837 to 1864".
24. **Script lines that drift toward stock phrasing** (R minor 15), proposed rewrites:
    - Slide 1: "which most of us have drunk and few of us have thought about" → "which most of us have drunk".
    - Slide 10: "It was written in general terms, but everyone knew which country it meant." → "It was written in general terms; its target was the United States." (the outline's words)
    - Slide 11: "People have argued about how much they knew ever since." → cut, or "The two accounts have never been reconciled."
25. **Captions without a licence** (slides 1, 2, 10, 11). The outline records each as public domain. Proposed: add "Public domain." to each caption, as slide 3 already gives "CC0".

## D. deck.json

26. **`description`**: current "How Canadian whisky is made, grain by grain, and how distillers in Ontario and Quebec came to supply the United States. Four pours." Proposed: "For a century, a lot of America's whiskey was made in Ontario, within sight of Detroit. How Canadian whisky is made, grain by grain, and how a war tax and Prohibition sent Americans north for it." (R minor 16)
27. **`tags`**: add "rye, crown royal, canadian club, seagram, bronfman" (R minor 16).
28. **`duration`**: see item 19.
29. **`takeaways`** (not in deck.json; proposed, drawn only from the outline and script):
    - "Why Canadian whisky crossed the border" / "A Civil War excise tax that reached $2 a proof gallon, and then Prohibition, twice turned American demand towards distillers in Ontario and Quebec."
    - "How Canadian whisky is made" / "Most Canadian distillers mash, distil and age each grain on its own and blend at the end: a light base whisky, usually corn, and a fuller flavouring whisky, usually rye."
    - "What \"rye\" means on a Canadian label" / "Canadian whisky, Canadian rye whisky and rye whisky are the same legal product, with no minimum rye content; look for a stated percentage."
    - "Where Crown Royal came from" / "Sam Bronfman's Seagram made it for the 1939 royal tour; it was sold only in Canada until 1964."
30. **`sections`** (not in deck.json; proposed):
    - "The glasses, in order": "Glass 1: Canadian Club 1858, 40%", "Glass 2: Lot No. 40, 43%", "Glass 3: Crown Royal Fine Deluxe, 40%", "Glass 4: Forty Creek Copper Pot Reserve, 43%".
    - "What you'll need": "Four glasses each", "Water and a little soda water on the table".

## E. Research outline (owner download)

31. Section labels: "Nailed down" → "What's established"; "Primary documents" → "Go to the source" (house names) (R minor 17).
32. Missing house sections: "The spine of the story" callout, "How to use this", "Threads worth pulling", "Claims that don't hold up", "The short shelf", bottle facts with swap-ins and dated prices, and a read-in-full / read-in-part / not-read mark on every source. These need the research to be revisited; not invented here (R minor 17).
33. Notes about the talk inside the outline ("The talk says so and the slide no longer claims it.", "The talk no longer says Canadian Club and Crown Royal are among the best-selling whiskies in the US.") are kept word for word. Proposed: cut them; they describe an earlier draft.
34. "The four pours" was a table in the old PDF; it is now four bullets with the same words (Maker, Style, ABV, "Why it is in the flight").

## Images

All five photographs are reused from the old deck, cropped from its slide images (the old pptx held only full-slide pictures). Every image has a recorded source and licence in the outline's "Image credits" (public domain or CC0); the on-slide captions are kept word for word. None is missing a credit.

- Four captions (slides 1, 2, 10, 11) do not state the licence on the slide (item 25).
- Slide 1: the crop now starts below most of the empty sky (y 380 of the old panel), which the review asked for (R minor 6). The picture is the same photograph; it is soft (upscaled in the old deck).
- Slide 11: low resolution, and the left-hand figures' heads are cut at the top, as in the old deck (R minor 7). Slide 10's photograph shows a brewery raid, beer rather than whisky (R minor 8); a replacement would be a new image for the owner to choose.
- Resolution is what the old slide images allowed: 1,104 × 874 (slide 1), 960 × 1,284 (slide 3), 1,056 × 1,254 (slide 10), 2,060 × 419 (slides 2 and 11). A fresh download from Wikimedia Commons would be sharper.

## Mechanical fixes already made (no approval needed, listed for the record)

- Em-dashes removed: the notes title ("Across the River [em-dash] Speaker Notes", now the house title block) and the four pour headings ("Pour one [em-dash] Canadian Club 1858" and so on, now "Pour 1 of 4: Canadian Club 1858" as on the slides); in the outline, the title and the eight module headings ("Module 1 [em-dash] The Ontario millers", now "Module 1. The Ontario millers"). None are left in any source file.
- Jameson (standing house rule, applied now): checked the script, outline and deck.json; the name appears nowhere, so nothing needed removing.
- Script headings now match the slides: 2 "Five Ontario distillers, 1837 to 1864" (was "Five Ontario distillers"); 3 "1858: Hiram Walker, a Detroit grain merchant, starts distilling across the river" (was "Hiram Walker, 1858"); 4 "The US whiskey tax, raised to pay for the Civil War" (was "The US whiskey tax and the Civil War"); 5, 9, 12, 16 "Pour n of 4: <name>"; 6 "1890: Canada requires two years in wood" (was "Two years in wood, from 1890"); 7 "Each grain is distilled and aged on its own" (was "Each grain on its own"); 10 "The US goes dry. Canadian distilleries keep making whisky for export" (was "Prohibition"); 11 "Sam Bronfman builds Seagram, 1924 to 1939" (was "Sam Bronfman and Seagram"); 13 "Three names for one product in Canadian law" (was "Three names for one product"); 14 "9.09%: Other spirits or wine in Canadian whisky sold in the US" (was "The 9.09% rule").
- Structure the pipeline needs: the house title block and the "## Part One: before the night" and "## Part Two: the script" headings around the existing text; the outline in the house markdown dialect (title block, "Module n. Title" headings, `###` labels kept as worded, the pours table as bullets, the Sources lists one link per bullet, book titles in italics as in the PDF, image credits in slide order).
- Words lost to line-break hyphens in the old PDF text were restored from the PDF's own links and layout ("production-cost", "separate-grain", "PD-Canada", "PD-USGov" and every wrapped URL); all 53 link annotations are present in the new outline.
- Typos: none found on the slides, in the script or in the outline.
- Design, not wording: the four pour slides are no longer full-bleed orange; slides 6, 10, 14 and 17 move from green to paper, leaving slide 3 (1858) as the deck's one green story slide; the orange "Blended after ageing" panel (slide 7) and "Canadian rye whisky" cell (slide 13) become a raised green card and a white card with a short orange rule; the old greyed "Caramel, flavouring, 9.09%" row on slide 17 is drawn like the others (R should-fix 13); slide 17's long row labels are broken over lines at their commas ("Canadian whisky, / Canadian rye whisky, / rye whisky").
