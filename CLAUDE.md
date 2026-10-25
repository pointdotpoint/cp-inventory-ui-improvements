# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

WardrobeTabs: a redesign of the Equipment-EX wardrobe screen for Cyberpunk 2077 (patch 2.31), written in redscript. The project covers the wardrobe UI only; the earlier inventory work (PreviewPoses, PreviewZoom, FastInventory snapshots, inventory prototypes, timing probes and research) was removed on 2026-10-25 and is in git history at commit `5f1dda9`. The game runs on Linux through Steam/Proton with redscript, Codeware, ArchiveXL, TweakXL, CET, Equipment-EX and Virtual Atelier installed. On 2026-10-25 every non-vanilla file was moved to `~/Games/cp2077-mods-removed-20261025/` (its README says how to restore) and only some mods came back.

Scripts are compiled by the game at launch. Native UI behaviour needs in-game verification by the user.

## Commands

```bash
tools/compile-check.sh        # compile every installed script + mod/ in a throwaway staging copy
```

Run this before installing any `.reds` change. It uses the game's own `scc.exe` under Wine and writes nothing into the game folder. A compile error that reaches the game disables all script mods for that launch, so never install unchecked scripts.

Installing is a plain copy; the game recompiles on next launch:

```bash
GAME="$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077"
cp -r mod/r6/scripts/WardrobeTabs "$GAME/r6/scripts/"
cp mod/archive/pc/mod/WardrobeTabs.archive "$GAME/archive/pc/mod/"
```

`WardrobeTabs.archive` holds `wardrobe_tabs\gui\grid.inkwidget`, the card grid. Rebuild it from Equipment-EX's layout: extract and serialize `equipment_ex\gui\wardrobe.inkwidget` from `EquipmentEx.archive`, run `tools/build_wardrobe_grid.py <wardrobe.inkwidget.json> <grid.inkwidget.json>`, deserialize the output and pack it at `wardrobe_tabs/gui/grid.inkwidget`.

Where to look after a run:

- `$GAME/r6/logs/redscript_rCURRENT.log`: the game's own compile result.
- `$GAME/bin/x64/plugins/cyber_engine_tweaks/gamelog.log`: the mod's `WardrobeTabs` log lines.
- `~/.local/share/Steam/steamapps/compatdata/1091500/pfx/drive_c/users/steamuser/AppData/Local/REDEngine/ReportQueue/`: crash reports.

Reference sources:

- Decompiled vanilla scripts: `git clone --depth 1 https://codeberg.org/adamsmasher/cyberpunk.git`. Check method names and signatures there before wrapping anything.
- Equipment-EX's scripts are installed at `$GAME/r6/scripts/EquipmentEx/`.
- Layout files: `WolvenKit.CLI extract <archive> -o <dir> -r "<regex>"`, then `WolvenKit.CLI convert serialize <file>` to get JSON. Equipment-EX's wardrobe layout is `equipment_ex\gui\wardrobe.inkwidget` in `EquipmentEx.archive`. Library item handles are numbered per package, so resolve `HandleRefId`s within one library item.

## Layout

- `mod/`: the shippable files, mirroring the game folder (`r6/scripts/WardrobeTabs`, `archive/pc/mod/WardrobeTabs.archive`).
- `tools/`: the compile check and the card grid builder.
- `prototype/wardrobe-mockups/`: the HTML mockups layout B comes from.

## Architecture

### WardrobeTabs

Replaces the Equipment-EX wardrobe's slot accordion with layout B from `prototype/wardrobe-mockups`: a body column left of V (one group per body area with a tile per worn item and a + tile that switches the drawer to that area) and the item panel as a drawer: its own header in the panel's header column (title, search moved from Equipment-EX, area tabs, EQUIPPED ONLY), a slot sidebar left of the grid (inside the grid container, which is widened by `GridLeft()` with its contents moved right, so the right-anchored panel grows left), seven-column named cards (192 × 216 cells from the archive; the item display is scaled to 0.75 in `OnSpawned`) for the selected slot on a 50% black backdrop (colour grouping by item family exists but is switched off with `WardrobeTabsConfig.ColourGrouping()`; names were too varied to guess families), and an outfit bar over the grid's bottom edge. B replaced an earlier slot sidebar (A). Two compiler constraints dictate its shape:

- `@wrapMethod` and `@addMethod` cannot target classes defined in scripts (any other mod's classes); only `@addField` can. Fully qualified names in annotations are rejected.
- Equipment-EX's grid classes are module-private, so the file declares `module EquipmentEx` to join that module.

So all behaviour is attached to the vanilla base class `inkPreviewGameController` and casts `this` to `WardrobeScreenController`. Filtering is done by replacing the grid's `ScriptableDataSource` contents with the selected slot's item entries (no slot header; its `IsCollapsed` is cleared so the items show), since Equipment-EX's `FilterItem` cannot be hooked. The mod keeps strong refs to the slot data, because the items' `Parent` is a weak ref. Equipment-EX rebuilds that source at moments no vanilla method observes, so a looping ink animation polls for it; untagged slot data (`m_wtTab == 0`) marks a fresh rebuild. The same tick polls the search text and the equipped filter (sidebar match counts) and `OutfitSystem` (equipped items), since Equipment-EX's own handlers cannot be wrapped either.

The body column is a canvas inserted as the first child of `wrapper` (`Reparent(wrapper, 0)`). Both `wrapper` canvases and `inventoryContainer` use `childOrder = Backward`, so the first child draws on top and gets input first; appended last, A's sidebar was hidden under the item panel and the preview took its clicks. Everything on the drawer is placed in Equipment-EX's own layout rather than at measured screen positions: the header is the first child of `vendorHeader` (Equipment-EX's header rows collapse), the outfit bar is the first child of `inventoryContainer` (moved to the outfit list's host in OUTFITS) and the backdrop its last. An overlay placed at measured coordinates ended up 67 units off once Equipment-EX's header changed height.

The search box (`m_searchInput`) and item-source button are reparented into the drawer header. The search box's `OnInput` callback to Equipment-EX's `OnSearchFieldInput` is unregistered: the watcher applies the text once it has been unchanged for `SearchSettleTicks()` ticks, through the data view's `SetSearchQuery`/`UpdateView`, and only refills the grid when the selected slot changes. Items' lower-cased names are cached on `InventoryGridItemData` (`m_wtSearchName`) for the per-slot match counts. `UIInventoryItem.GetName()` sometimes returns an unresolved `LocKey#...` string, so names go through `GetLocalizedText`. Some mods' names never resolve and show the raw key (e.g. Veegee's `casual_pt37_boots_black_name`); `CleanName` turns those into `casual pt37 boots (black)` so they group. Some mods' translated names are key-like too (`casual_pt37_boots_black`, no `_name`); any name without spaces and with two or more `_` is treated that way. Equipment-EX lists only the selected item source, so a worn item can be in no list at all; the mod reads its record from the player's slot (`TransactionSystem.GetItemInSlot`, Equipment-EX's preview copy), finds the real equipped item among the inventory, stash and wardrobe-store items, and inserts it first in its slot's `Children` (built like `PopulateInventoryGrid` does, with `UIInventoryItem.Make(player, slotID, ...)` so `IsEquipped` asks Equipment-EX). Only if no owned copy is equipped does the column fall back to the record's name and icon. families are built from those names when a slot is shown, and each build is logged (`WardrobeTabs` in CET's `gamelog.log`). Colour dots queue `WardrobeTabsVariantEvent`, handled by an `@addMethod` callback on `inkPreviewGameController` (whether ink delivers it to the screen is unverified in game).

Card names: `VendorItemVirtualController.OnDataChanged` (vanilla) is wrapped; cells whose root is named `wardrobeCardItem` (from `tools/build_wardrobe_grid.py`) get an `inkText` under the item display, refreshed whenever the virtual grid recycles the cell.

In this setup a static function returning an array (expression-bodied or built with `ArrayPush`) came back empty at runtime, while the same code as an instance method worked; the cause is unknown, so keep such tables as instance methods. A related case: `ArraySize(screen.m_outfitSystem.GetUsedSlots())` written inline gave 1 while the same call stored in a local first gave 12. Store array results in a local before using them.

## Working conventions

- Wrap, never replace: Equipment-EX and Virtual Atelier hook the same screen, and `@replaceMethod` would break them.
- Change the UI from script at runtime. ArchiveXL cannot patch `.inkwidget` files and archive conflicts are first-file-wins, so shipping an edited vanilla layout would clash with other mods.
- Decompiled sources show fields as `m_name` for script classes; CET exposes the same fields without the `m_` prefix.
- State what has and has not been run in-game. A clean compile check says nothing about runtime behaviour.
- The user tests by hand, and replies can cross with installs. Before reading results, confirm from `scripting.log` and the redscript log that the session being reported actually loaded the current build.
