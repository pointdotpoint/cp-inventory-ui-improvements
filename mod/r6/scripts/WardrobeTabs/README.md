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

A WEARING tag marks worn cards.
Resting the cursor on a card for 0.45 s tries the item on: it
goes on the preview only, nothing is equipped, and the bar reads "TRYING ON: …"
in cyan. Moving to another card swaps it after the same pause; moving off the
cards, OUTFITS, a scrolled or refilled grid and closing the wardrobe put the real
look back. Clicking equips the item as before.
A yellow NEW tag marks clothing V did not own the last time the wardrobe opened
(inventory, stash or wardrobe store, whatever the item source); slot rows and
area tabs holding one get a yellow dot. The tag goes once the card is hovered
long enough to try the item on, or the item is equipped. The first opening with
this build only records what V owns, so nothing is tagged until later. Both
lists are saved with the game.
Mod packs: each card names the mod pack its item comes from, in small text at
the bottom of the item art (base-game items show none). PACK: ALL in the header
opens a list of ALL, BASE GAME and every pack V owns items from, with counts;
picking one filters the grid, the slot counts and the NEW dots, until the game
is quit. Typing a pack name in the search box matches its items too. Packs are
detected in game, with nothing to run: an item whose name is a numeric game key
is base game, any other is a mod item, grouped by the prefix of its item ID
(Items.yv_long_coat -> YV). Known prefixes get a readable name (YV -> VOID) from
`WardrobeTabsPackNames.reds`; unknown ones show the prefix in capitals.
The camera follows the area: picking HEAD, BODY, ARMS, LEGS or FEET (tab, body
column header or + tile, or a row in another area) moves it to that area's own
camera setup: HEAD and BODY aim at the upper body (HEAD from farther back so the
whole head fits), ARMS and LEGS at the middle of V, FEET at V's feet.
V takes the pose of the matching vanilla inventory camera.
Slots within the framed area leave it alone. The wardrobe opens full
body, OUTFITS shows full body and BACK returns to the area framed before. The
mouse wheel is still Equipment-EX's zoom; picking an area again re-frames it.

The outfit bar along the bottom shows CURRENT LOOK ("SAVED AS …" when the worn
items match a saved outfit) and OUTFITS (n), which swaps the grid for the outfits
view; there the button reads BACK. There is no undo.
The mod remembers the outfit the look came from (saved with the game). After a
change the bar reads "TEST1 | EDITED | 2 CHANGES" (a change is a slot whose item
is different, added or removed) with UPDATE (save the look over that outfit, no
dialog) and REVERT (wear it as saved); its cell in the outfits view says EDITED.
NO OUTFIT or deleting the outfit drops the link; wearing another outfit links it.
The bar covers the bottom of the grid; the grid gets as much extra scroll room.

The outfits view has SAVE OUTFIT (Equipment-EX's own dialog), NO OUTFIT (lit
while no outfit is worn) and its own search box in the drawer header, and the
saved outfits as a three-column grid: name, item count, a row of item icons (head
to toe, up to seven, the last reading +N), a cyan bar and WEARING on
the worn one. Clicking a cell wears the outfit; Equipment-EX's delete key asks to
delete it. The star at the top right of each cell marks a favourite; favourites come
first, each group in alphabetical order. Favourites are saved with the game.
The cells replace Equipment-EX's one-column list and scroll with the mouse wheel.
Saving an outfit that the search would hide clears the search.
The grid sits on a 50% black backdrop.
The selected slot, area and grouping last until the game is closed. Mouse only.

V is shifted so she sits between the body column and the drawer.

## Card grid

The card resource keeps the existing 1344-unit grid width and changes item cells
from 224×202 to 192×216 at seven to a row (one grid per column count, 4 to 7, cells growing to 336×378 at four): the item display scaled to 0.75 on top, the name below
(added to each cell at runtime and updated when the grid recycles the cell). A new
grid is spawned inside the existing scroll area during the base screen
initialization, before Equipment-EX captures its controller and binds its source.
Filtering, selection, tooltips and outfit updates continue through Equipment-EX's
controllers.

The archive contains only `wardrobe_tabs/gui/grid.inkwidget`; it does not override
Equipment-EX or vanilla resources. Missing resources or a failed grid spawn leave
the original grid in place. `WardrobeTabs` entries in CET's `gamelog.log` identify
which grid was installed. This confirms initialization, not visible rendering.

## Search

An X at the right end of the search box (item search in the wardrobe, outfit search
in OUTFITS) clears it; it shows only while the box holds text.
While a search, EQUIPPED ONLY or a pack filter is active, each area tab shows how
many items in that area match, e.g. LEGS (8); areas with no match dim.

## Columns

The 4 5 6 7 buttons in the drawer header, left of PACK, set how many cards a row
holds; fewer columns make bigger cards (item art, name and tags grow with them).
The grid switches at once and the choice is saved with the game.

## Settings

With Mod Settings installed, Settings > Mods > Wardrobe Tabs has two switches, both
on by default: "Preview items on hover" (off: resting on a card still clears its NEW
tag but tries nothing on) and "Move camera to the selected area" (off: the camera
only moves with Equipment-EX's wheel zoom). Changes apply the next time the
wardrobe opens. Without Mod Settings both stay on.

## Rebuild

To add readable names for newly met packs, regenerate the known pack names from
the game's `r6/tweaks` (names come from folder names, overridden in
`tools/pack_names.txt`), then compile and install as usual:

```sh
python3 tools/build_pack_index.py
```

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

Pending in-game: the per-area camera (how each setup frames V in the wardrobe, V's pose per setup); seven cards per row with readable names; body column rows and
icons; clicking rows and picker chips; search and the equipped filter; OUTFITS /
BACK; the outfits view (scrolling, search, SAVE OUTFIT, NO OUTFIT, delete,
favourites surviving a save and reload); edited outfits (change count, UPDATE,
REVERT, the link surviving a reload); equip and unequip updating the column;
reopening.

Previous attempts resized the live scroll/grid hierarchy and blanked the grid;
those changes remain removed.

To return to Equipment-EX's own grid, remove only `archive/pc/mod/WardrobeTabs.archive`
and restart. The script keeps the original grid; its cells get no names.
