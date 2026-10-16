# WardrobeTabs

Requires Equipment-EX and Codeware. Install both `r6/scripts/WardrobeTabs/` and
`archive/pc/mod/WardrobeTabs.archive`, then restart the game.

The eight-column resource keeps the existing 1344-unit grid width and changes
item cells from 224×202 to 168×151.5. Item artwork scales to 75% when it spawns.
Slot headers retain their original template and full width. A new grid is spawned
inside the existing scroll area during the base screen initialization, before
Equipment-EX captures its controller and binds its source. Filtering, selection,
tooltips and outfit updates continue through Equipment-EX's controllers.

The archive contains only `wardrobe_tabs/gui/grid.inkwidget`; it does not override
Equipment-EX or vanilla resources. Missing resources or a failed grid spawn leave
the original grid in place. `WardrobeTabs` entries in CET's `gamelog.log` identify
which grid was installed. This confirms initialization, not visible rendering.

## Rebuild

Extract `equipment_ex/gui/wardrobe.inkwidget` from the installed EquipmentEx.archive
with WolvenKit and serialize it to JSON. Then run:

```sh
python3 tools/build_wardrobe_grid.py <wardrobe.inkwidget.json> <build>/WardrobeTabs/wardrobe_tabs/gui/grid.inkwidget.json
WolvenKit.CLI convert deserialize <build>/WardrobeTabs/wardrobe_tabs/gui/grid.inkwidget.json
```

Pack a directory named `WardrobeTabs` containing only the generated binary at
`wardrobe_tabs/gui/grid.inkwidget` into `mod/archive/pc/mod/`. The builder checks
the input template names and sizes so an incompatible Equipment-EX update fails
instead of silently producing an incorrect resource. Run `tools/compile-check.sh`
before installing scripts.

## Validation

Script compilation and binary serialization checks pass. Both the editor and
cooked widget packages preserve the generated grid and cell definitions. The
packed archive extracts byte-identically to the generated binary.

Pending in-game: open the wardrobe, expand a category containing at least nine
items, count eight cards in a complete row, and select cards in columns seven and
eight. Scroll, switch body tabs, search, collapse/expand categories, toggle
OUTFITS, and reopen. Check icons, headers, hover tooltips and equip actions.

Previous attempts resized the live scroll/grid hierarchy and blanked the grid;
those changes remain removed. The last user-confirmed layout had six columns.

To return to that layout, remove only `archive/pc/mod/WardrobeTabs.archive` and
restart. The script will retain the original grid and its unscaled item artwork.
