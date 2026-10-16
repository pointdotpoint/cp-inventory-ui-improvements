# Cyberpunk 2077 inventory UI improvements

Redscript mods for the inventory and wardrobe screens of Cyberpunk 2077 (patch 2.31), plus the
tooling used to build and measure them.

## Mods

| Mod | What it does |
|---|---|
| `PreviewPoses` | Photo mode body poses on V's inventory and wardrobe preview. A POSES button opens a browser with pose packs and animation packs in a sidebar and the selected pack's poses in a paged grid, with search. `PreviewView.reds` also remembers how V is framed (zoom, position, facing) on each screen. |
| `WardrobeTabs` | Body-area tabs (HEAD, BODY, ARMS, LEGS, FEET) for the Equipment-EX wardrobe. |
| `zzPreviewView` | Wrappers on VFocus's zoom and view-reset methods that keep the saved framing in step. Its folder name makes it sort after VFocus, which redscript requires. |
| `InventoryRedesignPrototype`, `HubWorldBackdropTest` | Experiments with the inventory layout and the world showing behind the menu. |

The shippable files live under `mod/`, mirroring the game folder (`r6/scripts`, `r6/tweaks`,
`archive/pc/mod`). `mod/experimental/` holds shelved code stored as `.txt`, which the compile check
ignores.

## Requirements

redscript, Codeware, TweakXL and ArchiveXL. `WardrobeTabs` also needs Equipment-EX.
`PreviewPoses` reads the installed photo mode pose packs. It also reads the AMM animation packs
that PhotoModeUIImprovements generates, when that mod is installed.

## Building and checking

```bash
tools/compile-check.sh                      # compile every installed script + mod/ in a throwaway copy
python3 -m unittest discover -s tests -v
lua tests/probe_read_only.lua
```

Run the compile check before installing any `.reds` change. A compile error that reaches the game
disables every script mod for that launch.

PreviewPoses' pose list and animation graph are generated from the current install:

```bash
python3 tools/build_installed_poses.py      # tools/poses_female.txt, poses.yaml, PreviewPoses.archive.xl
python3 tools/build_pose_graph.py <in.json> <out.json>   # patch player_paperdoll.animgraph
```

`CLAUDE.md` lists the full graph rebuild steps (WolvenKit extract, serialize, deserialize, pack).

## Installing

Copy the contents of `mod/` into the game folder. The game recompiles scripts on the next launch.

```bash
GAME="$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077"
cp -r mod/r6/scripts/<ModName> "$GAME/r6/scripts/"
```

## Other folders

- `probe/`: CET timing probe, an outside-the-game sampler, and saved logs from inventory-open measurements.
- `prototype/`: HTML mockups of an inventory redesign.
- `docs/research/`: sourced notes on what the inventory UI allows.
- `CLAUDE.md`: architecture notes and constraints found while building these mods.
