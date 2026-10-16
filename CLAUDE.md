# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Cyberpunk 2077 (patch 2.31) UI mods for the inventory and wardrobe screens, written in redscript, plus measurement tooling. The game runs on Linux through Steam/Proton, heavily modded (about 890 archive mods; redscript, Codeware, ArchiveXL, TweakXL, CET, Equipment-EX, VFocus and Virtual Atelier are all installed).

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

Adds body-area tabs (HEAD, BODY, ARMS, LEGS, FEET) to the Equipment-EX wardrobe. Two compiler constraints dictate its shape:

- `@wrapMethod` and `@addMethod` cannot target classes defined in scripts (any other mod's classes); only `@addField` can. Fully qualified names in annotations are rejected.
- Equipment-EX's grid classes are module-private, so the file declares `module EquipmentEx` to join that module.

So all behaviour is attached to the vanilla base class `inkPreviewGameController` and casts `this` to `WardrobeScreenController`. Filtering is done by replacing the grid's `ScriptableDataSource` contents with the active tab's entries, since Equipment-EX's `FilterItem` cannot be hooked. Equipment-EX rebuilds that source at moments no vanilla method observes, so a looping ink animation polls for it; untagged slot data (`m_wtTab == 0`) marks a fresh rebuild.

### PreviewPoses

Photo mode body poses on the inventory and wardrobe preview. Three parts that must agree:

- `PreviewPoses.archive` replaces `base\gameplay\anim_graphs\player_paperdoll.animgraph` with a copy that has an extra Switch between the Output node and the vanilla tree. Input 0 is vanilla; inputs 1..N are SkAnim nodes, one per line of `tools/poses_female.txt`. The switch index comes from a FloatInput reading anim feature `WardrobePose`, field `pose`.
- `PreviewPoses.archive.xl` attaches photo mode's `.anims` sets to the player templates with ArchiveXL's `animations:` section. With Phantom Liberty installed the preview is built from `ep1\characters\entities\player\player_wa_tpp_ep1.ent`, not the base `player_wa_tpp.ent` (confirmed in game with Codeware's `GetTemplatePath`). A T-pose on a selected pose means its animation is not attached to the template actually in use.
- `PreviewPoses.reds` applies `AnimFeature_WardrobePose` to `GetGamePuppet()` and draws the selector in the screen's own widget tree; widgets added inside the preview panel get covered by V's render. `PreviewPosesCatalog.reds` is generated; do not edit it.

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

In this setup a static function returning an array (expression-bodied or built with `ArrayPush`) came back empty at runtime, while the same code as an instance method worked; the cause is unknown, so keep such tables as instance methods.

### Probe and sampler

`probe/InventoryOpenProbe/init.lua` is a CET mod. It times script functions with `ObserveBefore`/`ObserveAfter`, records frame times from the moment `MenuHubGameController.OnInitialize` fires until the hub closes, and touches `marker.txt` at that moment. `probe/sampler.py` runs outside the game, waits for the process, and on each marker change dumps per-thread CPU (user and kernel), disk reads, page faults and GPU memory around the open. It exits when the game does and must be restarted for each session.

The older `InventoryOpenProbe` retains optional slot-skipping and V-removal experiments, disabled by default. Its retired stage driver and quest-state writes have been removed. Prefer `InventoryTiming`, which only observes behavior and checks visibility, zoom and pose-browser ownership.

## Working conventions

- Wrap, never replace: Equipment-EX, VFocus and Virtual Atelier hook the same screens, and `@replaceMethod` would break them.
- Change the UI from script at runtime. ArchiveXL cannot patch `.inkwidget` files and archive conflicts are first-file-wins, so shipping an edited vanilla layout would clash with other mods.
- Decompiled sources show fields as `m_name` for script classes; CET exposes the same fields without the `m_` prefix.
- State what has and has not been run in-game. A clean compile check says nothing about runtime behaviour.
- The user tests by hand, and replies can cross with installs. Before reading results, confirm from `scripting.log` and the redscript log that the session being reported actually loaded the current build.
