# Wardrobe mockups (prototype, delete when decided)

Question: which wardrobe layout is easier to use and more striking than today's Equipment-EX
accordion (with WardrobeTabs)?

Run `python3 -m http.server 8766 --bind 127.0.0.1 -d prototype/wardrobe-mockups`, then open
http://127.0.0.1:8766/. Variants: `now` (2026-10-14 screenshot), A slot sidebar, B body column +
drawer, C try-on dock. `?group=1` folds colour variants into one tile; Backdrop and Blur set how
much of the world shows behind the menu (defaults match the inventory choice: 25%, 20 px).

`build_assets.py` regenerates `assets/` from the wardrobe screenshot and copies the stand-in
icons and city from `../inventory-mockups/assets`.

Only V, the crown and the 17 glasses are real. Every other icon, name, colour, source and slot
count (beyond Head, Balaclava, Mask, Glasses) is a placeholder.

## Verdict

2026-10-16: user picked **A (slot sidebar)** to build first; B (body column + drawer) may come later as an option.
