# Inventory mockups (prototype, delete when decided)

Question: which inventory layout is clearer and more striking than v5?

Run `python3 -m http.server 8765 --bind 127.0.0.1 -d prototype/inventory-mockups`, then open
http://127.0.0.1:8765/. Variants: `now` (v5 screenshot), A quiet tiles, B body column,
C callouts, D bottom dock. `?aspect=21:9` widens the canvas to 3440×1440.

`build_assets.py` regenerates `assets/` from the 2026-10-14 screenshot.

## Verdict

2026-10-15: user picked **B (body column)**, and asked to see more of the game behind the inventory: a more transparent screen backdrop (Backdrop, Blur and Edge shade controls). Tile fills stay at 88%.
Chosen settings: backdrop 25%, blur 20 px, edge shade on (now the page defaults).
