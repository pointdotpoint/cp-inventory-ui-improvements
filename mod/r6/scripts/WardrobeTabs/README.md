# WardrobeTabs

Requires Equipment-EX and Codeware. Install both `r6/scripts/WardrobeTabs/` and
`archive/pc/mod/WardrobeTabs.archive`, then restart the game.

Layout B from `prototype/wardrobe-mockups`: a body column beside V and the item
panel as a drawer of named cards. Pending in-game verification.

## Body column

Left of V, under WEARING: one group per body area, HEAD / BODY / ARMS / LEGS / FEET
(OTHER only when something is worn in a slot outside those areas). Head, glasses,
wreath, ears and neckwear are all under HEAD, and so on. Each group shows how many
items are worn and a tile per worn item, head to toe, then a + tile. Hovering a
tile names its slot and item under the group heading; clicking it shows that slot
in the drawer (switching back from OUTFITS if needed); middle-clicking it (vanilla's
`unequip_item`) unequips the item. The + tile and the group
heading switch the drawer to that area, which is how to fill an empty slot.

## Drawer

Header (in place of the item panel's own header rows): the selected slot's
name, a subtitle ("154 ITEMS | WEARING …", with the match count while
searching or filtering), Equipment-EX's search box and item-source button, the
HEAD / BODY / ARMS / LEGS / FEET tabs (OTHER when it has slots) and the EQUIPPED
ONLY toggle. The header spans the whole drawer.

Slot sidebar, left of the grid: the selected area's slots, one per row with
their item counts, sixteen per page with PREVIOUS / NEXT below. It sits in the
grid container, which is widened by `GridLeft()` (Equipment-EX's panel is
anchored right, so the drawer grows to the left and V moves left to stay
centred). Worn slots' chips are cyan. If the selected slot has no match for a search, the
first slot with one is selected.

Each item is its own card; a WEARING tag marks worn cards.

Colour grouping is off (`WardrobeTabsConfig.ColourGrouping()`): item names follow too
many patterns to guess families reliably. When on, GROUP COLOURS shows one card per item family, guessed from names:
a trailing "(…)" or a short " - …" tail is the colour, so "NIKE AIR JORDAN 4
(BLACK - BLUE)" groups under "NIKE AIR JORDAN 4". The card shows the worn colour,
else the first matching one, with a dot per colour (named colour words are
coloured, others grey; a ring marks the worn one). Clicking a dot equips that
colour; hovering it shows its name. A WEARING tag marks worn cards.

The outfit bar along the bottom shows CURRENT LOOK ("SAVED AS …" when the worn
items match a saved outfit), OUTFITS (n), which swaps the grid for the outfit
list, and SAVE AS OUTFIT, which opens Equipment-EX's own dialog. There is no undo.
The bar covers the bottom of the grid; the grid gets as much extra scroll room.
The grid sits on a 50% black backdrop.
The selected slot, area and grouping last until the game is closed. Mouse only.

V is shifted so she sits between the body column and the drawer.

## Card grid

The card resource keeps the existing 1344-unit grid width and changes item cells
from 224×202 to 192×216, seven to a row: the item display scaled to 0.75 on top, the name below
(added to each cell at runtime and updated when the grid recycles the cell). A new
grid is spawned inside the existing scroll area during the base screen
initialization, before Equipment-EX captures its controller and binds its source.
Filtering, selection, tooltips and outfit updates continue through Equipment-EX's
controllers.

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

Script compilation and binary serialization checks pass. The packed archive
extracts byte-identically to the generated binary.

Pending in-game: seven cards per row with readable names; body column rows and
icons; clicking rows and picker chips; search and the equipped filter; SAVE AS
OUTFIT and OUTFITS; equip and unequip updating the column; reopening.

Previous attempts resized the live scroll/grid hierarchy and blanked the grid;
those changes remain removed.

To return to Equipment-EX's own grid, remove only `archive/pc/mod/WardrobeTabs.archive`
and restart. The script keeps the original grid; its cells get no names.
