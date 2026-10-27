# Cyberpunk 2077 wardrobe UI

WardrobeTabs, a redesign of the Equipment-EX wardrobe screen for Cyberpunk 2077 (patch 2.5),
written in redscript.

- Body column left of V: one group per body area, a tile per worn item and a + tile.
- Drawer on the right: title, search, HEAD / BODY / ARMS / LEGS / FEET tabs and EQUIPPED ONLY
  on top; the selected area's slots as a sidebar left of the grid; the slot's items as
  named cards, 4 to 7 per row (7 by default); an outfit bar with the current look and OUTFITS / BACK.
- Outfits view: SAVE OUTFIT, NO OUTFIT and search on top; saved outfits as a three-column grid
  with a favourite star on each cell, favourites first.

See `mod/r6/scripts/WardrobeTabs/README.md` for details and `CLAUDE.md` for how it is built.

## Requirements

redscript, Codeware, ArchiveXL and Equipment-EX.

## Checking and installing

```bash
tools/compile-check.sh      # compile every installed script + mod/ in a throwaway copy
GAME="$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077"
cp -r mod/r6/scripts/WardrobeTabs "$GAME/r6/scripts/"
cp mod/archive/pc/mod/WardrobeTabs.archive "$GAME/archive/pc/mod/"
```

Run the compile check before installing any `.reds` change: a compile error that reaches the
game disables every script mod for that launch. The game recompiles scripts on the next launch.

## Other folders

- `tools/`: the compile check and `build_wardrobe_grid.py`, which builds the card grid layout.
- `prototype/wardrobe-mockups/`: HTML mockups of the wardrobe layouts.
