# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Cyberpunk 2077 (patch 2.31) UI mods for the inventory and wardrobe screens, written in redscript, plus measurement tooling. The game runs on Linux through Steam/Proton, modded (about 750 archive mods; redscript, Codeware, ArchiveXL, TweakXL, CET, Equipment-EX and Virtual Atelier are installed). On 2026-10-25 every non-vanilla file was moved to `~/Games/cp2077-mods-removed-20261025/` (its README says how to restore) and only some mods came back; VFocus, PhotoModeEx, mod_settings, FastInventory and the CET probes are not installed. The mods here must not depend on other preview mods.

Scripts are compiled by the game at launch. Python/Lua tooling has regression tests; native UI behavior still needs in-game verification by the user. The working tree currently contains untracked project files.

## Commands

```bash
tools/compile-check.sh        # compile every installed script + mod/ in a throwaway staging copy
python3 -m unittest discover -s tests -v
lua tests/probe_read_only.lua
```

Run this before installing any `.reds` change. It uses the game's own `scc.exe` under Wine and writes nothing into the game folder. A compile error that reaches the game disables all script mods for that launch, so never install unchecked scripts.

Installing is a plain copy; the game recompiles on next launch:

```bash
GAME="$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077"
cp -r mod/r6/scripts/<ModName> "$GAME/r6/scripts/"
cp probe/InventoryTiming/init.lua "$GAME/bin/x64/plugins/cyber_engine_tweaks/mods/InventoryOpenProbe/"
python3 probe/sampler.py 7000   # run in background before the user launches the game
```

Where to look after a run:

- `$GAME/r6/logs/redscript_rCURRENT.log`: the game's own compile result.
- `$GAME/bin/x64/plugins/cyber_engine_tweaks/mods/InventoryOpenProbe/probe.log`: probe output, one report per hub-menu open. Copy it to `probe/probe.runN.log` to keep it.
- `$GAME/bin/x64/plugins/cyber_engine_tweaks/scripting.log`: CET log; shows when a mod was last loaded.
- `~/.local/share/Steam/steamapps/compatdata/1091500/pfx/drive_c/users/steamuser/AppData/Local/REDEngine/ReportQueue/`: crash reports.

Reference sources:

- Decompiled vanilla scripts: `git clone --depth 1 https://codeberg.org/adamsmasher/cyberpunk.git`. Check method names and signatures there before wrapping anything.
- Layout files: `WolvenKit.CLI extract <archive> -o <dir> -r "<regex>"`, then `WolvenKit.CLI convert serialize <file>` to get JSON. Vanilla `.inkwidget` files are in `basegame_1_engine.archive` and `basegame_4_gamedata.archive`; `archive --list` shows paths.

## Layout

- `mod/r6/scripts/`: the shippable mods, mirroring the game's `r6/scripts/`.
- `mod/experimental/`: shelved code, stored as `.txt` so the compile check ignores it.
- `probe/`: measurement tooling and saved logs, not part of any mod.
- `docs/research/inventory-ui-modding-feasibility.md`: sourced research on what the inventory UI allows.

## Architecture

### FastInventory (maintained in the sibling project)

The active installed version lives in `/home/pdp/cp-fast-inventory-and-map`. It owns persistent HIDE V / SHOW V state and asynchronous preview creation. The files in this project's `mod/experimental/` are retired snapshots; do not install them. `probe/InventoryTiming/init.lua` is the current installed CET timing probe.

Earlier measurements found 2–4 second inventory stalls associated with 3D preview creation and full video memory, with about 130 ms in script work. New script optimizations do not establish that the remaining native/driver stalls are resolved.

The preview is created by `SpawnLibraryItemController` on the `paperDoll` widget, which spawns library item `previewPanel` from `inventory_screen.inkwidget`. That spawn has already happened when `OnSetUserData` runs, but the puppet does not exist yet. The mod empties `paperDoll` there, then spawns a fresh `previewPanel` after a delay driven by an ink animation (menus run while the game is paused, so delay systems tied to game time are unsuitable). Closing before the delay skips the preview entirely.

Findings that constrain future work:

- A preview widget that is detached but still referenced initialises anyway and loads the puppet invisibly. Discard it; do not hold it.
- Putting such a detached preview back on screen does not display V.
- A second preview spawned while one is alive is nearly free. This is the basis of the shelved keep-alive cache in `mod/experimental/`.
- The hub ignores an `OpenMenuRequest` for the screen it is already showing, so a screen cannot be reloaded in place that way.

### WardrobeTabs

Replaces the Equipment-EX wardrobe's slot accordion with layout B from `prototype/wardrobe-mockups`: a body column left of V (one group per body area with a tile per worn item and a + tile that switches the drawer to that area) and the item panel as a drawer: its own header in the panel's header column (title, search moved from Equipment-EX, area tabs, EQUIPPED ONLY), a slot sidebar left of the grid (inside the grid container, which is widened by `GridLeft()` with its contents moved right, so the right-anchored panel grows left; PreviewZoom's wardrobe collider is translated with V so it stays off the sidebar), seven-column named cards (192 × 216 cells from the archive; the item display is scaled to 0.75 in `OnSpawned`) for the selected slot on a 50% black backdrop (colour grouping by item family exists but is switched off with `WardrobeTabsConfig.ColourGrouping()`; names were too varied to guess families), and an outfit bar over the grid's bottom edge. B replaced an earlier slot sidebar (A). Two compiler constraints dictate its shape:

- `@wrapMethod` and `@addMethod` cannot target classes defined in scripts (any other mod's classes); only `@addField` can. Fully qualified names in annotations are rejected.
- Equipment-EX's grid classes are module-private, so the file declares `module EquipmentEx` to join that module.

So all behaviour is attached to the vanilla base class `inkPreviewGameController` and casts `this` to `WardrobeScreenController`. Filtering is done by replacing the grid's `ScriptableDataSource` contents with the selected slot's item entries (no slot header; its `IsCollapsed` is cleared so the items show), since Equipment-EX's `FilterItem` cannot be hooked. The mod keeps strong refs to the slot data, because the items' `Parent` is a weak ref. Equipment-EX rebuilds that source at moments no vanilla method observes, so a looping ink animation polls for it; untagged slot data (`m_wtTab == 0`) marks a fresh rebuild. The same tick polls the search text and the equipped filter (sidebar match counts) and `OutfitSystem` (equipped items), since Equipment-EX's own handlers cannot be wrapped either.

The body column is a canvas inserted as the first child of `wrapper` (`Reparent(wrapper, 0)`). Both `wrapper` canvases and `inventoryContainer` use `childOrder = Backward`, so the first child draws on top and gets input first; appended last, A's sidebar was hidden under the item panel and the preview took its clicks. Everything on the drawer is placed in Equipment-EX's own layout rather than at measured screen positions: the header is the first child of `vendorHeader` (Equipment-EX's header rows collapse), the outfit bar is the first child of `inventoryContainer` (moved to the outfit list's host in OUTFITS) and the backdrop its last. An overlay placed at measured coordinates ended up 67 units off once Equipment-EX's header changed height.

The search box (`m_searchInput`) and item-source button are reparented into the drawer header. The search box's `OnInput` callback to Equipment-EX's `OnSearchFieldInput` is unregistered: the watcher applies the text once it has been unchanged for `SearchSettleTicks()` ticks, through the data view's `SetSearchQuery`/`UpdateView`, and only refills the grid when the selected slot changes. Items' lower-cased names are cached on `InventoryGridItemData` (`m_wtSearchName`) for the per-slot match counts. `UIInventoryItem.GetName()` sometimes returns an unresolved `LocKey#...` string, so names go through `GetLocalizedText`. Some mods' names never resolve and show the raw key (e.g. Veegee's `casual_pt37_boots_black_name`); `CleanName` turns those into `casual pt37 boots (black)` so they group. Some mods' translated names are key-like too (`casual_pt37_boots_black`, no `_name`); any name without spaces and with two or more `_` is treated that way. Equipment-EX lists only the selected item source, so a worn item can be in no list at all; the mod reads its record from the player's slot (`TransactionSystem.GetItemInSlot`, Equipment-EX's preview copy), finds the real equipped item among the inventory, stash and wardrobe-store items, and inserts it first in its slot's `Children` (built like `PopulateInventoryGrid` does, with `UIInventoryItem.Make(player, slotID, ...)` so `IsEquipped` asks Equipment-EX). Only if no owned copy is equipped does the column fall back to the record's name and icon. families are built from those names when a slot is shown, and each build is logged (`WardrobeTabs` in CET's `gamelog.log`). Colour dots queue `WardrobeTabsVariantEvent`, handled by an `@addMethod` callback on `inkPreviewGameController` (whether ink delivers it to the screen is unverified in game).

Card names: `VendorItemVirtualController.OnDataChanged` (vanilla) is wrapped; cells whose root is named `wardrobeCardItem` (from `tools/build_wardrobe_grid.py`) get an `inkText` under the item display, refreshed whenever the virtual grid recycles the cell.

### PreviewPoses

Photo mode body poses on the inventory and wardrobe preview. Three parts that must agree:

- `PreviewPoses.archive` replaces `base\gameplay\anim_graphs\player_paperdoll.animgraph` with a copy that has an extra Switch between the Output node and the vanilla tree. Input 0 is vanilla; inputs 1..N are SkAnim nodes, one per line of `tools/poses_female.txt`. The switch index comes from a FloatInput reading anim feature `WardrobePose`, field `pose`.
- `PreviewPoses.archive.xl` attaches photo mode's `.anims` sets to the player templates with ArchiveXL's `animations:` section. With Phantom Liberty installed the preview is built from `ep1\characters\entities\player\player_wa_tpp_ep1.ent`, not the base `player_wa_tpp.ent` (confirmed in game with Codeware's `GetTemplatePath`). A T-pose on a selected pose means its animation is not attached to the template actually in use.
- `PreviewPoses.reds` applies `AnimFeature_WardrobePose` to `GetGamePuppet()` and draws the selector in the screen's own widget tree; widgets added inside the preview panel get covered by V's render. `PreviewPosesCatalog.reds` is generated; do not edit it.

`PreviewZoom.reds` and `PreviewZoom.archive` are the parts of VFocus this project used, ported so nothing depends on it: wheel zoom over V (camera setups 12–23 added to the inventory preview; 0–11 stay vanilla's equipment-area cameras), middle-mouse drag to move V, V to reset, pad R3/L3 zoom with both together resetting, the preview surface enlarged to 4000 × 8000, and the inventory view reset after the wardrobe closes. The wardrobe shows the inventory's puppet render on its own image (`m_pzWardrobeImage`) and zooms the inventory puppet preview's camera (`PreviewPosesState.m_cameraPreview`); a collider of ours, the last root child, takes its input. The archive replaces `base\gameplay\gui\fullscreen\inventory\{target.ent,preview.dtex}` with a 2880 × 5760 render target and a 99° FOV, which the zoom steps are tuned for; `tools/build_preview_target.py` builds them from the vanilla JSON (`target.ent` from `basegame_3_nightcity.archive`, `preview.dtex` from `basegame_1_engine.archive`). Vanilla `target.ent` does not round-trip byte-identical (WolvenKit recompresses its compiled buffer) but does round-trip field-for-field. That target is 32× vanilla's pixel count, which matters for the video-memory stalls above. A mod that replaces the inventory preview after the screen opens (FastInventory) must call `PreviewZoomAttach()` afterwards.

`PreviewMove.reds` moves and turns V with modifier + wheel, using PhotoModeUIImprovements' keys (Shift X, Ctrl Y, Alt Z, Shift+Alt yaw, Ctrl+Alt pitch, Ctrl+Shift+Alt roll, Ctrl+Shift step). The wheel comes through PreviewZoom's handlers; its reset puts V back. The preview puts its puppet back every frame, so `Entity.SetWorldTransform` on it was undone at once (confirmed in game). Turns go through the preview's native `Rotate` (yaw) and `RotateVector` (pitch, roll; vanilla's item preview passes yaw in z, pitch in y); moves act on the image showing the render, like dragging with the middle mouse: X/Z shift its margin, Y scales it. The inventory image is paperDoll's `canvas/preview`; the wardrobe's is `m_pzWardrobeImage`. The first pitch/roll logs the puppet's angles before and after.

Rebuild after changing the pose list:

```bash
WolvenKit.CLI extract "$GAME/archive/pc/content/basegame_1_engine.archive" -o <dir> -r 'player_paperdoll\.animgraph$'
WolvenKit.CLI convert serialize <dir>/base/gameplay/anim_graphs/player_paperdoll.animgraph
python3 tools/build_pose_graph.py <in.json> <out-root>/base/gameplay/anim_graphs/player_paperdoll.animgraph.json   # also writes the catalog
WolvenKit.CLI convert deserialize <out .json>      # then pack <out-root> with WolvenKit.CLI pack
```

An unmodified graph round-trips byte-identical through serialize/deserialize, and the packed archive should extract to exactly the built file; check both with `cmp`. Archive conflicts can be checked quickly by hashing a path (FNV-1a 64 of the lowercase path) and searching each archive's index, which `WolvenKit.CLI archive -l` is far too slow for.

`tools/build_installed_poses.py` also lists PhotoModeUIImprovements' AMM animation packs (`r6/tweaks/PhotoModeUIImprovements/animations.yaml`, categories named `Animations: <type>`, about 12k female clips). That file is read last so a clip shared with a real pose pack stays in the pose pack; the browser shows these packs in its ANIMATIONS section. Their sets come from that mod's `.xl` and attach to the preview templates like the others. Rerun the builder and rebuild the graph after that mod regenerates its packs.

Female only: the male templates and male photo mode sets are not wired up. The current catalog includes weapon-dependent poses; this mod does not supply their required props.

In this setup a static function returning an array (expression-bodied or built with `ArrayPush`) came back empty at runtime, while the same code as an instance method worked; the cause is unknown, so keep such tables as instance methods. A related case: `ArraySize(screen.m_outfitSystem.GetUsedSlots())` written inline gave 1 while the same call stored in a local first gave 12. Store array results in a local before using them.

### Probe and sampler

`probe/InventoryOpenProbe/init.lua` is a CET mod. It times script functions with `ObserveBefore`/`ObserveAfter`, records frame times from the moment `MenuHubGameController.OnInitialize` fires until the hub closes, and touches `marker.txt` at that moment. `probe/sampler.py` runs outside the game, waits for the process, and on each marker change dumps per-thread CPU (user and kernel), disk reads, page faults and GPU memory around the open. It exits when the game does and must be restarted for each session.

The older `InventoryOpenProbe` retains optional slot-skipping and V-removal experiments, disabled by default. Its retired stage driver and quest-state writes have been removed. Prefer `InventoryTiming`, which only observes behavior and checks visibility, zoom and pose-browser ownership.

## Working conventions

- Wrap, never replace: Equipment-EX and Virtual Atelier hook the same screens, and `@replaceMethod` would break them.
- Change the UI from script at runtime. ArchiveXL cannot patch `.inkwidget` files and archive conflicts are first-file-wins, so shipping an edited vanilla layout would clash with other mods.
- Decompiled sources show fields as `m_name` for script classes; CET exposes the same fields without the `m_` prefix.
- State what has and has not been run in-game. A clean compile check says nothing about runtime behaviour.
- The user tests by hand, and replies can cross with installs. Before reading results, confirm from `scripting.log` and the redscript log that the session being reported actually loaded the current build.
