# Inventory redesign prototype

Question: does the reference image's centered character, red equipment panels, and compact header work with the installed equipment and preview mods?

Version 5 replaces the stock angled tile artwork with flat burgundy surfaces and thin red borders, using the original live icon and indicator widgets. The first two weapon slots form a square-tile row above a wide third slot; weapon and clothing tiles are approximately 20% smaller than v4. Weapons, cyberware and quick access sit on the left; clothing, outfit, stats and menu links sit on the right. All positions are relative to the screen center in the game's 3840×2160 design units. The shared hub header is vanilla. Category trees and slot roots are retained. Within each slot, live icons and indicators move into the replacement surface; the native controller's wrapper reference points to that surface for input and lock updates. Stock tile artwork becomes transparent.

VFocus controls and saved PreviewView framing remain active. Existing item selection and Equipment-EX wardrobe transitions retain their original controllers. The POSES button moves below the left equipment column. There is no prototype overlay across the rest of the screen. The reference's illustrated background art, character lighting and camera presets are not reproduced.

## Run

From the project root, compile and install before starting the game:

```sh
tools/compile-check.sh && cp -r mod/r6/scripts/InventoryRedesignPrototype "$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077/r6/scripts/"
```

Open Inventory after restarting the game. Compilation alone does not verify runtime behavior.

## In-game acceptance

- At 3440×1440 and 1920×1080, labels and slots are readable and do not overlap the preview or button hints.
- Hover, tooltips, selection, equip and unequip work for every weapon, clothing, cyberware and quick-access slot, including empty/locked slots.
- Opening item selection and returning preserves the layout; entering and exiting the Equipment-EX wardrobe works.
- Zoom, pan, rotation, saved framing, POSES and the pose browser still work.
- Reopening Inventory adds no duplicate outlines or controls.
- The hub header looks and behaves like vanilla across hub tabs.

Runtime diagnostics appear under `InventoryRedesignPrototype` in `bin/x64/plugins/cyber_engine_tweaks/gamelog.log`; the script compiler writes `r6/logs/redscript_rCURRENT.log`. Missing layout sections retain their existing positions and are logged.

## Rollback

Remove only the installed `r6/scripts/InventoryRedesignPrototype` folder, then restart the game. The prototype adds no save-game state and modifies no archives or other installed scripts.

## Verdict

Version 1 loaded in-game on 2026-10-06, but its coordinates and stock tile shapes were too close to vanilla; the user rejected its visual resemblance. Runtime logs confirmed that the layout callback executed, ruling out the suspected delayed-callback failure. Version 2 compiled but crashed on opening Inventory on 2026-10-06. The installed build was quarantined at `/tmp/InventoryRedesignPrototype-crashed-v2-20261006` before further work.

The crash dump in `Cyberpunk2077-20261006-144440-368-508` records a read at `0x50`, with instruction pointer at `Cyberpunk2077.exe+0x2f098b`. Its calling stack contains the CName hash `0x43034e53be47da53` (`tintColor`). Disassembly shows the widget operation loading its manager pointer from offset `0x40`, then accessing that manager's lock at offset `0x50`; the manager is null. The shared tint helper called `UnbindProperty` after checking only that the widget existed. Version 3 also checks the Codeware-exposed `widget.propertyManager` before unbinding either tint or opacity. It checks the optional menu underline before changing visibility; the vanilla `menu_label_content` resource has no line reference.

Runtime regression checks require the real game: restart, open Inventory with I, hover occupied and empty tiles, close and reopen, then switch hub tabs. Confirm both v3 header and inventory markers in `gamelog.log` and no new crash report. Compilation cannot exercise native ink initialization; these runtime checks and the visual, click and wardrobe checks remain pending user testing.


Version 3 loaded successfully in the user's 2026-10-06 14:56 session; both runtime markers are present. Its screenshot shows oversized, overlapping weapon surfaces and overall dimming. Version 4 fixes each presentation canvas to its requested dimensions rather than filling the uniform grid's widest cell, reduces weapon/clothing dimensions by about 20%, and tightens section spacing. It removes the 85%-opaque full-screen atmosphere and tints only leaf widgets to avoid multiplying tint through every parent. The property-manager crash guard remains. Restart and check that both top weapons have equal widths, the third spans the row below without overlap, and the character/text stay bright; hover, reopen and wardrobe checks still require the game.

Version 5 reduces weapon and clothing dimensions another 20% from v4, adjusts weapon row offsets and clothing column spacing, and sets the inventory preview surface scale to 1.5 around its center. The scale is absolute, so repeated application does not compound it. VFocus camera steps and saved pan remain unchanged. Compile and weapon geometry checks pass; model framing and input remain pending in-game verification.

PreviewView also remembers inventory rotation, alongside the existing pan and camera zoom. It samples the puppet's yaw relative to its initial orientation, then uses the saved yaw as the next preview's starting rotation. A separate validity flag preserves the front-facing default for older saves. Inventory captures the final view before releasing its controls. Runtime check: adjust pan/zoom/rotation, immediately close and reopen, then save and reload to verify persistence. Repeat near the +/-180-degree yaw boundary; check that opening wardrobe does not overwrite the inventory view. Look for `saved inventory view` and `inventory rotation initialized` in the PreviewPoses log. Native preview rotation and teardown cannot be exercised by the compiler, so these checks are pending in-game validation.

Entering Wardrobe inherits Inventory's live VFocus zoom step and preview display scale after VFocus finishes initialization. The saved Wardrobe pan is still restored; its old zoom no longer overrides the incoming Inventory zoom. Runtime check: enter Wardrobe at zoom steps 0, 5 and 11, adjust Wardrobe zoom, return and re-enter at a different Inventory zoom, and repeat with V hidden and with SHOW V still loading. Verify the visible size and wheel/gamepad zoom continuity. The timing probe checks zoom and scale after restoration; native transitions remain pending in-game verification.

Inventory zoom is saved directly on mouse-wheel/gamepad input, including Reset view. Polling only captures pan and rotation, so VFocus's automatic resets cannot overwrite the last zoom. Restore runs after opening, default-mode transitions, preview creation, and Wardrobe's automatic return reset. Install `zzPreviewView` alongside `PreviewPoses`: its name makes the compiler process VFocus's added methods before their wrappers. Runtime check: zoom and immediately close/reopen, repeat with gamepad hold/repeat, enter/leave Wardrobe and equipment details, explicitly reset then reopen, and save/reload. The timing probe records the last zoom input and asserts it survives restoration; visible camera behavior still needs an in-game check.

WardrobeTabs now installs a separate eight-column grid resource before Equipment-EX binds its data source. It keeps the working scroll area and 1344-unit grid width, uses 168×151.5 item cells, and scales their separately spawned artwork to 75%. Slot headers keep their original full-width template. Earlier live-resizing attempts that blanked the grid remain removed. Install WardrobeTabs.archive together with its script; missing archives retain the original six-column grid. Compilation and resource round-trip checks pass; visible rendering, eight-column layout and input remain pending in-game confirmation. See [WardrobeTabs](../WardrobeTabs/README.md) for rebuild, acceptance and rollback instructions.

The pose browser now displays collapsible pose-pack headers with counts and three-column grids of labeled pose buttons. Only the selected pack starts expanded; search opens matching packs and matches either pack or pose names. Header clicks remain available while searching. The selected pose is highlighted, and wheel scrolling advances whole grid rows. The default pose has its own category. The panel sits below the hub header with an opaque burgundy background, and temporarily hides the inventory's head, chest, legs, outfit and related-link containers; close and screen teardown restore their original visibility. Switching to wardrobe first releases any covered inventory sections.

Runtime acceptance: expand/collapse several packs independently, select buttons from each grid column before and after scrolling, search by pack and pose names, check empty results, clear search, close/reopen, and switch inventory/wardrobe. Clothing and related controls must be hidden and unavailable behind the open panel and restored on close. Verify the selected animation and saved view still apply. Compiler validation passes; native draw order, pointer routing and accordion interaction require in-game validation. No pose thumbnails are generated; the grid uses pose names.

FastInventory in the sibling `cp-fast-inventory-and-map` project owns the HIDE V / SHOW V button. Its persistent FastInventoryState remembers the last click. Reopening while hidden skips preview creation; reopening while shown queues the existing asynchronous spawn. New saves start hidden; saving preserves the choice across game restarts. PreviewPoses does not create a competing toggle. The old m_invPreviewHidden field is retained for save compatibility.

Toggle acceptance: show V, close/reopen and verify automatic restoration; hide V, close/reopen and verify no preview spawns. Click SHOW V then immediately close/reopen and verify the choice survives cancellation. Save/reload in both states, test rapid clicks while loading, and verify pose, framing and wardrobe transitions. Compilation passes; native visibility and asynchronous restoration require in-game testing.

Inventory opening with the default pose avoids pose-name lookup and constructs the browser only on POSES click. The first non-default label now indexes catalog animations and scans photo-mode records once, caching matching localized names. Search no longer scans all records separately for each of the 2,717 poses. Pack membership is also cached: filtering visits 2,718 poses (including DEFAULT), instead of 173,952 pack/pose combinations. These are operation counts from the current catalog, not measured frame-time improvements. The wardrobe watcher now checks only its first source entry on each tick, copying the full source only after Equipment-EX rebuilds it.

For current timings, install `probe/InventoryTiming/init.lua` into the game's CET `mods/InventoryOpenProbe/` folder and run `python3 probe/sampler.py 7000` before launching. The probe only observes methods, records frame durations and checks saved visibility against the button. It does not modify quests, slots or previews. Read `mods/InventoryOpenProbe/probe.log` and `probe/sampler.log` after closing Inventory. Open hidden twice, show V and reopen twice, then hide and reopen. Compare first/repeated opens and shown/hidden states. Check POSES, pack expansion, search, localized labels and wardrobe after the lazy browser change. CPU timings are inclusive; use frame durations to detect native/driver waits. Hooks unavailable through CET are logged. No post-change runtime measurements have been collected yet.


The 2026-10-14 review fixed pose-browser ownership across Inventory → Wardrobe → Inventory: changing owners removes the old browser, keeps one selector button per screen, and returning restores the inventory preview reference. Queued preview-restoration events are invalidated on teardown or reinitialization so they cannot restart an obsolete polling loop. The timing probe checks browser ownership and ignores obsolete restore events.

Regression acceptance: open POSES in Inventory, enter Wardrobe, open POSES there, return, and open POSES again. Repeat while V is hidden and while it is loading; select poses on both screens. Rapidly close/reopen the menu while V initializes. Check the probe for `CHECK FAILED` and verify no duplicate buttons or orphan browser panels. Compilation passes; these native UI checks remain pending. Tooling regression tests run with `python3 -m unittest discover -s tests -v` and `lua tests/probe_read_only.lua`.

On 2026-10-15 all hub header changes were removed: the burgundy strip, repositioned and scaled progression/money/capacity holders, centered divider, pink/red tints, and the selected-only tab underline. `SubMenuPanelLogicController`, `hubStaticSelectorController` and `HubMenuLabelContentContainer` are no longer wrapped. The pose browser's position below the header is unaffected.

## Version 6: layout B (body column)

Chosen on 2026-10-15 from the HTML mockups in `prototype/inventory-mockups/` (variant B). Changes from v5:

- Clothing is one column at x = 680, head to toe: the head, chest, legs and outfit containers are stacked 344 units apart. Each container already holds its two slots vertically, so no slot leaves its native container. Tiles are 180×156 with 16-unit gaps.
- A "Clothing" title replaces the Head, Upper Body and Lower Body labels; each clothing slot is named beside its tile (Head, Face, Outer torso, Inner torso, Legs, Feet). Outfit keeps its own label.
- Weapons, cyberware and quick access move out to x = -1560 so they clear V. Cyberware and quick-access tiles are 200×200, and cyberware now gets the same tile style (its slots spawn asynchronously; `OnSlotSpawned` restyles them).
- Tiles have no border at rest; hover shows a red border. Clothing icons are scaled 1.6× and cyberware/quick-access icons 1.3×, because their art carries more padding than weapon art.
- Equipment-EX's Wardrobe button moves under the clothing column at 85% size. Backpack, Crafting and Stats become a plain text bar at the bottom (frames, icons and minimum widths hidden; hover brightens the label). The empty Related panel is hidden.
- FastInventory's HIDE V / SHOW V and the POSES button sit at the bottom left, at 90%.
- The screen backdrop is unchanged: it is drawn by the engine in hub-menu mode, not by any inventory or hub widget.

Compile check passes; nothing below has been seen in game. Positions were converted from the mockup using the v5 screenshot (default_wrapper starts ~265 units below the screen top), so expect small offsets.

In-game acceptance:

- The clothing column reads head to toe with even gaps; slot names sit beside their tiles and do not overlap V.
- Cyberware tiles match the others after opening, after equipping cyberware, and after returning from item selection.
- Hover shows the red border on every tile; equip, unequip and tooltips work on all slots.
- Wardrobe opens from its new button and returning keeps the layout; Backpack, Crafting and Stats open from the bottom bar with mouse and gamepad.
- HIDE V / SHOW V and POSES are readable and do not overlap the link bar, including while "LOADING V..." shows.
- Gamepad navigation reaches every slot and link; report any slot it skips.
