# Cyberpunk 2077 Inventory screen: UI modding feasibility

Researched 2026-10-01. Target: game patch 2.3x on PC, run on Linux through Steam/Proton.
Scope: the hub-menu INVENTORY tab (weapon, cyberware, quick-access and clothing slots, the V paper doll, the Backpack/Crafting/Stats/Wardrobe links, and the hub top bar).

Evidence labels used throughout:

- **[V]** verified by reading a primary source (game script dump, mod source, tool source, or official wiki page).
- **[I]** inferred from verified facts; not stated by a source.
- **[U]** could not verify (source unreachable or no source found).

Nexus Mods pages are behind a Cloudflare challenge and could not be fetched. Anything sourced only from a Nexus page is marked [U] and comes from search-result snippets.

## 1. Verdict

| What we want to change | Feasible? | Mechanism | Difficulty |
|---|---|---|---|
| Move, resize, hide, restyle existing widgets (slots, links, fluff) | Yes [V] | redscript `@wrapMethod` on `gameuiInventoryGameController` plus widget lookups by path; or edit `inventory_screen.inkwidget` | Low (script) / Medium (inkwidget) |
| Add new buttons, labels, panels to the screen | Yes [V] | `SpawnFromLocal` / `SpawnFromExternal` with a Codeware controller override, or script-built `inkComponent` | Low to Medium |
| Add a whole new sub-screen inside the inventory | Yes [V] | Own `.inkwidget` in own archive, spawned into the inventory root (Equipment-EX does exactly this) | Medium to High |
| Change slot behaviour (click, hover, tooltips, equip rules, refresh) | Yes [V] | `@wrapMethod` / `@replaceMethod` on script controllers; all slot logic is in scripts | Medium |
| Change colors and fonts | Yes [V] | `BindProperty` and `.inkstyle` at runtime, or patch `main_colors.inkstyle` on load via Codeware `Resource/Loaded` | Low to Medium |
| Add or rename text, localized | Yes [V] | ArchiveXL `localization.onscreens` in an `.xl` file | Low |
| Replace textures and icons | Yes [V for mechanism, I for this screen] | Own `.inkatlas` + `.xbm` in an archive, referenced from script or inkwidget | Medium |
| Change the Related links (Backpack/Crafting/Stats/Wardrobe) | Yes [V] | `HubMenuUtils.SetMenuHyperlinkData` in `OnSetUserData`; extra links via `HyperlinkButton` library item | Low |
| Add a new hub-menu entry or fullscreen menu | Yes [V] | Push an `inkMenuEntry` into `menu.inkmenu` on `Resource/Ready`, add a `menu_button` in `MenuHubLogicController` | Medium |
| Change the top bar (level, street cred, weight, eddies) | Yes [V for scriptability, I for layout] | It belongs to the hub (`SubMenuPanelLogicController`), not the inventory widget; wrap that controller | Medium |
| Rotate the paper doll, switch between existing zoom presets | Yes [V] | `inkInventoryPuppetPreviewGameController.Rotate`, `gameuiPuppetPreview_SetCameraSetupEvent` | Low |
| Move or scale the paper doll on screen | Yes [V] | Translate or animate `m_paperDollWidget` (the game and Equipment-EX both do it) | Low |
| Change what the doll wears or its pose | Yes [V] | Codeware `GetInventoryPuppet()`, `OnPuppetReady` hook, `AnimFeature_Paperdoll` | Medium |
| New free camera (arbitrary zoom, pan, tilt, new framing presets) | Probably, mechanism unknown [U] | Camera setups are indexed natively; Nexus mods claim it but source not seen | High |
| Modify native controller internals (preview rendering, spawner, layer system) | Only with native code [V] | RED4ext plugin with address hooks | Very high, breaks per patch |
| Non-conflicting patch of `inventory_screen.inkwidget` by several mods | No [V] | ArchiveXL resource patching does not cover `.inkwidget`; first archive wins | Hard limit |
| Gamepad focus navigation between new widgets | Unknown [U] | No source found for how this screen handles gamepad | Unknown |
| Correct layout on ultrawide (21:9, 32:9) | Unknown [U] | Only a Nexus snippet claims an overhaul mod does it | Unknown |
| Do it with a CET/ImGui overlay | Not integrated [I] | ImGui draws its own windows in `onDraw`, separate from ink | Not recommended |
| Ship as REDmod | Not needed [V/I] | REDmod replaces whole script files, first mod wins | Not recommended |

Bottom line: everything on this screen except the 3D preview internals is script-driven and reachable. The safest design is redscript + Codeware that mutates the vanilla widget tree at runtime, with any new layouts in a mod-owned `.inkwidget`, and no replacement of the vanilla `.inkwidget`.

## 2. How the game UI is built

### 2.1 The ink system

- UI is defined in `.inkwidget` files under `base/gameplay/gui` (and `ep1/gameplay/gui` for Phantom Liberty), viewable in WolvenKit. [V] https://wiki.redmodding.org/scripting-cyberpunk/scripting/game-systems/ui-scripting/.inkwidget-files
- An `.inkwidget` holds `libraryItems`. The first, usually `Root`, is the whole screen; the rest are reusable components (buttons and so on) that can be spawned by name. Each library item carries its controller and root widget. [V] same page.
- A widget file is a tree. Key properties: `anchor`, `margin`, `parentWidget`, `effects`, `renderTransform`, `textureAtlas` (path to an `.inkatlas`), `texturePart`, `visible`. [V] https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-creators-theory/files-and-what-they-do/file-formats/inkwidgets-a-custom-interface
- `.inkanim` animations target widgets by child index path (for example `0 # 0, 1 # 5`), and the sequence count and order must match the library items. This means reordering or inserting children in an `.inkwidget` can silently retarget animations. [V for the index mechanism, I for the consequence] same page.
- Layout containers (`inkCanvas`, `inkFlex`, `inkVerticalPanel`, `inkHorizontalPanel`) derive from `inkCompoundWidget`; drawing widgets (`inkText` and others) from `inkLeafWidget`. [V] https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-creators-theory/references-lists-and-overviews/reference-inkwidgets
- Two controller kinds. `inkGameController` binds a root library item to an ink layer and has game-instance, library-animation and sound access. `inkLogicController` is lightweight and attaches to any widget. Lifecycle hooks are `OnInitialize` and `OnUninitialize`. [V] https://wiki.redmodding.org/scripting-cyberpunk/scripting/game-systems/ui-scripting/ink-controllers
- Menus live in the `inkMenuLayer`, whose controller is `gameuiInGameMenuGameController` (layer list documented as of 2.12). [V] https://wiki.redmodding.org/scripting-cyberpunk/scripting/game-systems/ui-scripting
- The wiki states that by hooking the right methods you can add, modify or delete any UI element on screen, with the caveat that the game may force visibility of some elements. [V] same page.
- The hands-on "Interface modding" guide for editing inkwidgets is an empty stub. [V] https://wiki.redmodding.org/cyberpunk-2077-modding/modding-guides/custom-icons-and-ui/interface-modding

### 2.2 Resources behind this screen

From a community file list dated 2024-05 (patch 2.12 era). Paths not re-checked against a 2.3x install. [V that the list contains them, U for 2.3x]
https://github.com/DoctorPresto/Cyberpunk-File-Types/blob/main/inkwidget.txt

| Resource | Role |
|---|---|
| `base\gameplay\gui\fullscreen\inventory\inventory_screen.inkwidget` | Inventory screen [I: role by name; the wiki shows "the .inkWidget file for the inventory screen" only as an image] |
| `base\gameplay\gui\fullscreen\inventory\inventory_screen_animations.inkanim` | Its animations [I] |
| `base\gameplay\gui\fullscreen\inventory\backpack.inkwidget`, `backpack_animations.inkanim` | Backpack [I] |
| `base\gameplay\gui\fullscreen\hub_menu\new_hub.inkwidget` | Hub menu; referenced by scripts for `menu_label` items [V] https://codeberg.org/adamsmasher/cyberpunk/src/branch/master/cyberpunk/UI/fullscreen/ingame/hubSelectorController.swift |
| `base\gameplay\gui\fullscreen\hub_menu\new_hub_layout.inkwidget`, `hub.inkwidget`, `radial_hub_menu.inkwidget` | Other hub variants; which one is live in 2.3x not determined [U] |
| `base\gameplay\gui\fullscreen\wardrobe\wardrobe_fullscreen.inkwidget` | Vanilla wardrobe [I] |
| `base\gameplay\gui\fullscreen\menu.inkmenu` | Menu registry (`menusEntries`) [V] https://github.com/djkovrik/CP77Mods/blob/master/src/Revised%20Backpack/Sources/Scripts/RevisedBackpack/NewHubMenuItem.reds |
| `base\gameplay\gui\common\main_colors.inkstyle` | Shared color and font tokens (`MainColors.Red`, `MainColors.ReadableXSmall`, ...) [V] https://github.com/psiberx/cp2077-equipment-ex/blob/master/scripts/Overrides/InventoryItemModeLogicController.reds |
| `base\gameplay\gui\common\buttonhints.inkwidget` | Button hints, spawned by the inventory controller [V] script dump below |
| `base\gameplay\gui\fullscreen\inventory\inventory4_atlas.inkatlas` | Default empty-slot icon atlas [V] https://codeberg.org/adamsmasher/cyberpunk/src/branch/master/cyberpunk/UI/inventory/inventoryItemDisplayController.swift |
| `base\gameplay\gui\common\tooltip\*.inkwidget` | Tooltips [I] |

### 2.3 Script classes

All from the decompiled script dump at commit `a2e6bb3`, labelled "2.31". [V]
https://codeberg.org/adamsmasher/cyberpunk

| Class | File | Notes |
|---|---|---|
| `gameuiInventoryGameController extends gameuiMenuGameController` | `cyberpunk/UI/inventory/inventoryGameController.swift` | **Script class, not native.** Main controller. The wiki also names it as the inventory screen's game controller: https://wiki.redmodding.org/scripting-cyberpunk/scripting/game-systems/ui-scripting/ink-controllers |
| `InventoryItemModeLogicController extends inkLogicController` | `cyberpunk/UI/inventory/inventoryItemMode.swift` | Item chooser mode after clicking a slot |
| `InventoryItemDisplayController extends BaseButtonView` | `cyberpunk/UI/inventory/inventoryItemDisplayController.swift` | One slot tile |
| `InventoryEquipmentSlot`, `InventoryWeaponSlot` | `inventoryEquipmentSlot.swift`, `inventoryWeaponSlot.swift` | Slot wrappers |
| `PaperdollGlitchController extends inkLogicController` | `inventoryPaperdollGlitchController.swift` | Doll glitch effect |
| `inkInventoryPuppetPreviewGameController` (**native**) | `core/ui/baseControllers/entityPreviewGameController.swift` | Paper doll preview; chain is `inkPuppetPreviewGameController` -> `inkPreviewGameController` -> `gameuiMenuGameController` |
| `MenuHubGameController`, `MenuHubLogicController` | `cyberpunk/UI/fullscreen/hub/hubMenuGameController.swift`, `hubMenuLogicController.swift` | Hub menu |
| `SubMenuPanelLogicController extends PlayerStatsUIHolder` | `cyberpunk/UI/fullscreen/hub/subMenuPanelLogicController.swift` | Top bar: `m_levelValue`, `m_streetCredLabel`, `m_currencyValue`, `m_weightValue` |
| `MenuItemController`, `HubMenuUtils`, `MenuDataBuilder` | `hub/menuButtonController.swift`, `hub/hubMenuUtils.swift`, `ingame/menuDataBuilder.swift` | Menu links and entries |
| `BackpackMainGameController` (**native class**) | `cyberpunk/UI/fullscreen/backpack/backpack_main.swift` | Backpack |
| `WardrobeUIGameController` | `cyberpunk/UI/fullscreen/wardrobeDevice/wardrobeUIController.swift` | Vanilla wardrobe |

Not found under the names proposed in the brief: there is no class called `InventoryPaperdollGlitchController` (it is `PaperdollGlitchController`) and no `gameuiInventoryPuppetPreviewGameController` (it is `inkInventoryPuppetPreviewGameController`). [V]

Details of `gameuiInventoryGameController` that matter for a mod: [V]

- Widget refs set in the inkwidget: `m_paperDollWidget`, `m_defaultWrapper`, `m_itemWrapper`, `m_cyberwareHolder`, `m_playerStatsWidget`, `m_btnBackpack`, `m_btnCyberware`, `m_btnCrafting`, `m_btnStats`, `m_btnSets`, `m_sortingButton`, `m_sortingDropdown`.
- Slot lists held in script: `m_WeaponsList`, `m_EquipmentList`, `m_CyberwareList`, `m_PocketList`, `m_ConsumablesList`.
- Slots are populated in script: `OnEquipmentAreaCategoryCreated`, `PopulateArea`, `RefreshUI`.
- Related links are set in `OnSetUserData` through `HubMenuUtils.SetMenuHyperlinkData(...)` with fullscreen names `backpack`, `crafting_main`, `temp_stats`, `wardrobe`, `cyberware_equip`.
- Library animations played by name: `menu_intro`, `default_wrapper_Intro`, `default_wrapper_outro`, `inventory_grid_intro`, `cyberware_grid_intro`.
- Doll zoom: `ZoomCamera(target)` queues `gameuiPuppetPreview_SetCameraSetupEvent` with a `setupIndex` from the enum `InventoryPaperdollZoomArea` (Default, Weapon, Legs, Feet, Cyberware, QuickSlot, Consumable, Outfit, Head, Face, InnerChest, OuterChest).
- Doll slide: `PlaySlidePaperdollAnimation` animates `m_paperDollWidget` with script-built `inkAnimTranslation`.

Widget names inside the inventory tree, taken from Equipment-EX source, not from the inkwidget itself: `default_wrapper/menuLinks`, `default_wrapper/menuLinks/btnsContainer`, `buttonFluff2`, and the library item `HyperlinkButton`. Hub names from Revised Backpack: `mainMenu/buttonsContainer/panel_inventory`, library item `menu_button`. [V]
https://github.com/psiberx/cp2077-equipment-ex/blob/master/scripts/Overrides/gameuiInventoryGameController.reds
https://github.com/djkovrik/CP77Mods/blob/master/src/Revised%20Backpack/Sources/Scripts/RevisedBackpack/NewHubMenuItem.reds

Paper doll preview: [V]

- `inkPreviewGameController` exposes native `Rotate(yaw)` and `RotateVector(Vector3)`, with `m_isRotatable` and `m_rotationSpeed`.
- `inkPuppetPreviewGameController` exposes native `GetGamePuppet()`.
- `inkInventoryPuppetPreviewGameController` handles mouse-drag rotation in script (`m_collider`, `m_mouseRotationSpeed`) and maps the zoom index to `AnimFeature_Paperdoll` flags in `OnSetCameraSetupEvent`.
- The camera itself is not exposed in scripts. Only a setup index and a slot name are passed. [V that scripts show only this; I that the camera lives in native code or a scene resource]

## 3. Modding approaches

### (a) Edit `.inkwidget` in WolvenKit, ship an `.archive`

- Can change anything the file defines: layout, anchors, margins, sizes, visibility, texture parts, fonts, added or removed widgets. [V for the property set] https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-creators-theory/files-and-what-they-do/file-formats/inkwidgets-a-custom-interface
- A worked official guide exists only for the main and pause menus (button size, spacing, font size). [V] https://wiki.redmodding.org/cyberpunk-2077-modding/modding-guides/custom-icons-and-ui/main-menu-and-pause-menu-editing
- Conflict model: per file, and the first archive in ASCII order wins. Two mods shipping the same `.inkwidget` cannot coexist. [V] https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-users/users-modding-cyberpunk-2077/load-order
- Risk: `edit` refs in controllers (such as `m_btnBackpack`) and index-based `.inkanim` targets depend on the tree. Removing or reordering widgets can break them. [I]
- Risk: a replaced vanilla file freezes that file at the version you copied; a game patch that changes it is lost. [I]

### (b) redscript annotations

- `@wrapMethod`, `@replaceMethod`, `@addMethod`, `@addField`. `@wrapMethod` chains across mods, which keeps mods compatible. Annotations cannot target native functions. [V] https://wiki.redmodding.org/scripting-cyberpunk/redscript/language-reference/hook-annotations
- Since `gameuiInventoryGameController` and the slot, hub and top-bar controllers are script classes, their methods (including `private final` ones) are wrappable. Equipment-EX wraps `OnInitialize`, `OnBack`, `OnEquipmentClick` and replaces `SetupSetButton`, `RefreshEquippedWardrobeItems`. [V] https://github.com/psiberx/cp2077-equipment-ex/blob/master/scripts/Overrides/gameuiInventoryGameController.reds
- `@replaceMethod` on the same method by two mods conflicts. Equipment-EX and Wardrobe Extras both replace methods on this controller (`RefreshEquippedWardrobeItems`, `RefreshUI`). [V for the two replacements, I for the conflict] https://github.com/djkovrik/CP77Mods/blob/master/src/Wardrobe%20Extras/r6/scripts/ExtraWardrobeSlots/replacements/gameuiInventoryGameController.reds
- Latest redscript release: v0.5.31 (2025-08-28). [V] https://github.com/jac3km4/redscript/releases

### (c) Codeware

All [V] from https://github.com/psiberx/cp2077-codeware/wiki#user-interface unless noted.

- Access every ink layer, window, game controller and logic controller: `GameInstance.GetInkSystem().GetLayers()`, `GetLayer(n"inkHUDLayer").GetVirtualWindow()`.
- Script-created widgets and controllers are "attached to all game systems and fully functional"; native controllers such as `inkScrollController` can be initialised from script.
- `inkComponent` (widget plus logic as one unit: `OnCreate`, `OnInitialize`, `OnUninitialize`). `inkCustomController` still works for older mods.
- Controller override at spawn: `SpawnFromLocal(parent, n"HyperlinkButton:MyButtonController")`. Also works inside `.inkwidget` library item names.
- Callback events: `InkWidget/Spawn` (`inkWidgetSpawnEvent`, targetable by library path and item name or by controller type), `Resource/PostLoad`/`Resource/Ready`/`Resource/Loaded` (mutate a resource in memory when it loads), `Input/Key`, `Input/Axis`.
- Ready-made buttons, action hints, text inputs and popups (`Codeware.UI.*`).
- `GameInstance.GetPlayerSystem(...).GetInventoryPuppet()` returns the inventory-screen puppet.
- Localization system and providers for script-side text.
- Compatibility stated in the README: game 2.31, redscript 0.5.31+, RED4ext 1.29.0+. Latest release v1.20.5 (2026-09-20). https://github.com/psiberx/cp2077-codeware

### (d) ArchiveXL

- Localization: add or edit onscreen texts without overwriting game files, via `localization.onscreens` in an `.xl`. [V] https://github.com/psiberx/cp2077-archive-xl/wiki#extending-resources
- "Spawn widgets from any library without registering dependencies." [V] https://github.com/psiberx/cp2077-archive-xl
- Resource patching (non-conflicting merges) is documented for `.ent`, `.app`, `.mesh`. [V] https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-creators-theory/core-mods-explained/archivexl/archivexl-resource-patching
- In source, the patch extension additionally handles `CurveSet`, `gameDeviceResource`, `worldStreamingWorld` and `inkanimAnimationLibraryResource`. There is **no handler for `.inkwidget`**, `.inkstyle` or `.inkatlas`. So inkanim libraries can be patched; widget libraries cannot. [V] https://github.com/psiberx/cp2077-archive-xl/blob/main/src/App/Extensions/ResourcePatch/Extension.cpp
- Compatibility: game 2.31. Latest release v1.27.3 (2026-09-07).

### (e) CET / Lua / ImGui

- CET UI is Dear ImGui, drawn only inside the `onDraw` callback. [V] https://wiki.redmodding.org/scripting-cyberpunk/cyber-engine-tweaks/cet-functions/ui-examples
- It is a separate overlay and does not take part in ink layout, styling, animation or input. [I]
- CET can observe native methods that redscript cannot wrap, depending on whether the game calls the RTTI wrapper. [V] https://wiki.redmodding.org/scripting-cyberpunk/redscript/language-reference/hook-annotations
- CET Lua can call the same ink and Codeware APIs, so it can also mutate ink widgets. [I, from the "CET and Codeware" wiki page title only; page not read]
- Useful mainly as host for the RedHotTools overlay. Latest release v1.37.1 (2025-09-28). [V] https://github.com/maximegmd/CyberEngineTweaks/releases

### (f) RED4ext native plugins

- Docs cover creating plugins, custom native classes and native functions. [V] https://docs.red4ext.com/mod-developers/creating-a-plugin
- ArchiveXL hooks the engine's widget spawner natively (`InkWidgetLibrary::SpawnFromLocal`, `SpawnFromExternal`, async variants) to implement controller injection. This shows native ink internals are reachable, by address hooks. [V] https://github.com/psiberx/cp2077-archive-xl/blob/main/src/App/Extensions/InkSpawner/Extension.cpp
- Address hooks need updating per game patch. [I]
- Needed only for things scripts cannot reach, such as preview camera internals. Latest release v1.30.0 (2026-03-09).

### (g) REDmod

- CDPR command-line tool; mods live in `mods/<name>/` with `info.json`, and script mods replace whole `.script` files. [V] https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-creators-theory/modding-tools/redmod
- Conflicts are per file and the first mod wins. [V] https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-users/users-modding-cyberpunk-2077/redmod/usage
- Replacing `inventoryGameController.script` wholesale would conflict with every other mod touching it and with patches. No advantage over redscript here. [I]

## 4. Precedents

| Mod | Source | Mechanism | What it proves |
|---|---|---|---|
| **Equipment-EX** (psiberx) | https://github.com/psiberx/cp2077-equipment-ex (Nexus: https://www.nexusmods.com/cyberpunk2077/mods/6945) | redscript + Codeware + ArchiveXL + TweakXL. Ships its own `equipment_ex\gui\wardrobe.inkwidget`; does **not** replace the vanilla inventory inkwidget. Hides two link buttons by index, spawns a `HyperlinkButton` with its own controller, resizes the links container, spawns the wardrobe screen into the inventory root, slides and hides the paper doll, wraps `OnBack` and `OnEquipmentClick`, hooks `OnPuppetReady` for scene `inventory` to dress the puppet, localizes 13 languages via `.xl`. | A full sub-screen can be added to this exact screen with no vanilla file replaced. [V] |
| **Revised Backpack** (djkovrik) | https://github.com/djkovrik/CP77Mods/tree/master/src/Revised%20Backpack (Nexus: https://www.nexusmods.com/cyberpunk2077/mods/17642) | Own `revised_backpack.inkwidget`; registers a new menu by pushing an `inkMenuEntry` into `menu.inkmenu` on `Resource/Ready`; adds a hub button via `MenuHubLogicController.OnInitialize`; repoints the inventory's Backpack link with `SetMenuHyperlinkData`. | New fullscreen menus and hub entries are possible; Related links can be retargeted. [V] |
| **Stash and Backpack Search** (djkovrik) | https://github.com/djkovrik/CP77Mods/tree/master/src/Stash%20and%20Backpack%20Search (Nexus: https://www.nexusmods.com/cyberpunk2077/mods/14264) | Pure redscript + `Codeware.UI`; adds a text input to `BackpackMainGameController` and wraps `BackpackDataView.DerivedFilterItem`. | Text input and custom filtering can be injected into a vanilla menu, even one with a native controller class. [V] |
| **HUD Painter** (djkovrik) | https://github.com/djkovrik/CP77Mods/tree/master/src/HUD%20Painter (Nexus: https://www.nexusmods.com/cyberpunk2077/mods/14935) | Rewrites `main_colors.inkstyle` properties in memory on `Resource/Loaded`. Wiki reference shows it recolors Inventory elements. | Global recoloring without shipping a replaced `.inkstyle`. [V] https://wiki.redmodding.org/cyberpunk-2077-modding/modding-guides/hud-painter-resource |
| **Wardrobe Extras** (djkovrik) | https://github.com/djkovrik/CP77Mods/tree/master/src/Wardrobe%20Extras | `@replaceMethod` on `gameuiInventoryGameController.RefreshUI` and others. | Core refresh logic is replaceable; also a live conflict hazard. [V] |
| **HUDitor** (djkovrik) | https://github.com/djkovrik/CP77Mods/tree/master/src/HUDitor | redscript reparenting of HUD widgets plus a CET settings file. | Runtime reparenting of vanilla widgets. [V for file layout, I for details; source files not read] |
| **Ultrawide UI Overhaul** | https://www.nexusmods.com/cyberpunk2077/mods/33193 | Snippet claims redesigned menus including Inventory for 21:9 to 32:9. Mechanism not seen. | [U] |
| **Inventory Free View** | https://www.nexusmods.com/cyberpunk2077/mods/32542 | Snippet claims 12-step zoom, rotation and tilt of the inventory preview. Mechanism not seen. | [U] |
| **V Focus** | https://www.nexusmods.com/cyberpunk2077/mods/33527 | Title claims zoom, pan, rotate for inventory and wardrobe preview. | [U] |
| **Project E3 UI** and patches | https://www.nexusmods.com/cyberpunk2077/mods/22918, https://www.nexusmods.com/cyberpunk2077/mods/32828 | Restyle; the existence of separate "compatibility patch" mods for Equipment-EX and Extra Weapon Slots suggests it replaces shared files. | [U]; conflict reading is [I] |

Not researched: Virtual Atelier, Mod Settings, Native Settings UI, Limited HUD, "No Special Outfit Lock". No claims made about them.

## 5. Hard limits and risks

1. **No non-conflicting patching of `.inkwidget`.** ArchiveXL's patcher has no widget-library handler, and archive conflicts are first-file-wins. Replacing `inventory_screen.inkwidget` makes the mod exclusive with any other mod that replaces it. [V] https://github.com/psiberx/cp2077-archive-xl/blob/main/src/App/Extensions/ResourcePatch/Extension.cpp and https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-users/users-modding-cyberpunk-2077/load-order
2. **Native code is out of reach for redscript.** Annotations cannot target native functions. The preview controllers' `Rotate`, `RotateVector`, `GetGamePuppet` are native, and the camera is addressed only by an index. [V] https://wiki.redmodding.org/scripting-cyberpunk/redscript/language-reference/hook-annotations and https://codeberg.org/adamsmasher/cyberpunk/src/branch/master/core/ui/baseControllers/entityPreviewGameController.swift
3. **Runtime tree edits are brittle.** Precedents address widgets by path name and even child index (`btnList.GetWidgetByIndex(3)`). Any other mod or patch that changes the tree breaks those lookups, and `GetChildWidgetByPath` then returns null. [V for the practice, I for the failure mode] https://github.com/psiberx/cp2077-equipment-ex/blob/master/scripts/Overrides/gameuiInventoryGameController.reds
4. **Coexistence with Equipment-EX is a design constraint.** It already replaces `SetupSetButton` and `RefreshEquippedWardrobeItems`, hides link buttons by index, resizes `menuLinks`, moves `buttonFluff2`, and animates the paper doll. A mod that rearranges the same area must detect it (Codeware reflection or `ModuleExists`) or it will fight it. Its latest release is v1.2.7 (2024-12-13) and its README still says game 2.2. [V for what it does; I for the consequence] https://github.com/psiberx/cp2077-equipment-ex
5. **Framework dependency on game patches.** Codeware, ArchiveXL and RED4ext are native and versioned per game build (README: 2.31). After a game patch the mod is dead until they update. RedHotTools' README still lists game 2.21 while its latest release is v1.3.0-rc.2 (2026-07-12), so the dev inspector may lag. [V for versions; I for the consequence] https://github.com/psiberx/cp2077-codeware, https://github.com/psiberx/cp2077-red-hot-tools
6. **Animations.** Library animations are played by name from script and `.inkanim` targets are index paths. Hiding or moving widgets by script is safe; restructuring the inkwidget is not. Script-built `inkAnimDef` animations are a safe alternative, as Equipment-EX uses. [V for mechanism, I for the risk]
7. **Hot reload does not refresh live widgets.** Already-spawned UI keeps old resources; the widget must be respawned (reopen the menu) or a save loaded. [V] https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-creators-theory/modding-tools/redhottools/rht-hot-reload
8. **Gamepad navigation, ultrawide, performance.** No primary source found. See section 7.
9. **Localization.** Solved for new strings via ArchiveXL, but every language needs its own JSON; unlisted languages get no text unless a fallback is provided. [V for mechanism, U for fallback behaviour]

## 6. Recommended toolchain and workflow

Stack: redscript + Codeware + ArchiveXL (for localization and, if needed, a mod-owned `.inkwidget`/`.inkatlas`). Same stack as Equipment-EX and Revised Backpack. [I]

1. **Read the vanilla logic.** Script dump: https://codeberg.org/adamsmasher/cyberpunk (start at `cyberpunk/UI/inventory/inventoryGameController.swift`). Class and method lookup with copy-as-annotation: https://nativedb.red4ext.com [V]
2. **Inspect the live tree.** RedHotTools Ink Inspector in the CET overlay: "Inspect" shows the whole hierarchy with on-screen highlight; "Pick" (bind a hotkey) selects the widget under the cursor. The Widget tab shows properties and the attached `logicController`; the Context tab shows the library path (source `.inkwidget`) and the full name path usable with `GetWidgetByPathName`. Properties can be changed live to try values. [V] https://wiki.redmodding.org/scripting-cyberpunk/scripting/game-systems/ui-scripting, https://wiki.redmodding.org/scripting-cyberpunk/scripting/game-systems/ui-scripting/inkwidgets-basics, https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-creators-theory/modding-tools/redhottools/rht-ink-inspector
3. **Log trees from script** with Codeware when the inspector is unavailable. [V] https://wiki.redmodding.org/scripting-cyberpunk/scripting/game-systems/ui-scripting/logging-widget-trees
4. **Write hooks.** Prefer `@wrapMethod` on `OnInitialize`, `OnSetUserData`, `RefreshUI`, `OnEquipmentAreaCategoryCreated`. Avoid `@replaceMethod`. Name every widget you create with `SetName` so it shows in the inspector. [I, naming tip V]
5. **Iterate.** RedHotTools hot-reloads scripts and tweaks from the VS Code extension, and archives dropped into `archive/pc/hot` (or the WolvenKit "Hot Reload" button). Then close and reopen the inventory. It also blocks game start when script compilation fails. Limits: struct field changes and new scriptable-system request handlers need a session reload. [V] https://github.com/psiberx/cp2077-red-hot-tools
6. **Only if a new layout is needed:** build a mod-owned `.inkwidget` in WolvenKit and spawn it with `SpawnFromExternal(root, r"mymod\\gui\\x.inkwidget", n"Root:MyMod.MyController")`. Do not ship a modified vanilla inkwidget. [I, pattern V in Equipment-EX]
7. **Guard for other mods** using Codeware reflection or `ModuleExists("EquipmentEx")`. [V that both exist] https://github.com/psiberx/cp2077-codeware/wiki#mods-and-patches-compatibility

### Linux / Proton

- Required for RED4ext/CET-based mods: install `d3dcompiler_47` and `vcrun2022` into the game prefix with Protontricks (app id 1091500), and set the Steam launch option `WINEDLLOVERRIDES="winmm,version=n,b" %command%`. Steam sometimes resets launch options after updates. [V] https://wiki.redmodding.org/cyberpunk-2077-modding/for-mod-users/users-modding-cyberpunk-2077/modding-on-linux
- If vcredist fails: `protontricks 1091500 --force vcrun2022`. [V] same page.
- WolvenKit GUI ships as a Windows installer; the 9.0.1 release also ships `WolvenKit.ConsoleLinux-9.0.1.zip` (CLI). The wiki links a list of "known Linux issues and their workarounds" for the GUI; that list was not read. [V for assets] https://github.com/WolvenKit/WolvenKit/releases
- Whether RedHotTools archive hot reload and the WolvenKit GUI inkwidget editor/preview work under Wine/Proton: not verified. [U]
- A redscript-plus-Codeware-only mod needs no WolvenKit at all; `.reds` files and the `.xl` are plain text. Localization JSON must still be packed into an `.archive` (WolvenKit CLI). [I]

## 7. Could not verify

- All Nexus page content (Cloudflare challenge): Ultrawide UI Overhaul, Inventory Free View, V Focus, Project E3 UI and its patches. Their mechanisms and claims are from search snippets only.
- That `inventory_screen.inkwidget` is the live inventory widget in 2.3x, and its internal structure. The file was not opened; the path comes from a 2024-05 file list. Confirm with Ink Inspector's Context tab.
- Which hub inkwidget (`new_hub`, `new_hub_layout`, `hub`) is live and holds the top bar.
- How gamepad navigation and focus work on this screen. No use of `SetNavigation`/`inkDiscreteNavigationController` was found in the inventory scripts, which suggests a virtual cursor, but this was not confirmed.
- Ultrawide and aspect-ratio handling in ink. No wiki page covers it.
- Performance cost of script-built widgets or of `RefreshUI` wraps.
- Whether a free preview camera is possible from scripts, and where camera setups are defined.
- WolvenKit GUI and RedHotTools behaviour under Proton.
- ArchiveXL localization fallback for languages a mod does not ship.
- CET "CET and Codeware" page, WolvenKit inkwidget editor documentation, psiberx Ink Playground repo (`cp2077-ink-playground` does not exist; Codeware wiki links https://github.com/psiberx/cp2077-playground, not read).
- Mods not researched: Virtual Atelier, Mod Settings, Native Settings UI, Limited HUD, No Special Outfit Lock.
