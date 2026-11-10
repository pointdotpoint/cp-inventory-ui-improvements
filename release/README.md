# Wardrobe UI Improvements

A redesign of the Equipment-EX wardrobe screen for Cyberpunk 2077.

## What it does

- **Body column**: what V is wearing, grouped by HEAD, BODY, ARMS, LEGS and FEET. Click an
  item or a + to jump to that slot.
- **Item drawer**: area tabs, a slot list with item counts, and a grid of named item cards.
  Pick 4, 5, 6 or 7 cards per row with the buttons in the header. The choice is saved with
  your game.
- **Search**: filters as you type. The X clears it. While searching, each area tab shows how
  many items match.
- **Hover to try on**: rest the cursor on a card for a moment and V wears it in the preview.
  Move away and the real look comes back. Click to equip.
- **Camera follows the area**: HEAD, BODY, ARMS, LEGS and FEET each frame that part of V.
- **NEW tags**: items V didn't own the last time you opened the wardrobe are marked NEW, and
  so are the slots, tabs and packs that hold them.
- **Mod packs**: each card names the clothing mod its item comes from, and PACK filters the
  grid to one pack. Packs are detected automatically.
- **Outfits**: a four-column grid with item icons, search and favourites. Each outfit shows
  the playtime it was created at, and SORT orders them A-Z, newest or oldest first
  (favourites stay on top). After you change
  a saved look, UPDATE saves the change and REVERT puts the outfit back.
- **EQUIPPED** shows only what V is wearing; **NEW** shows only items tagged NEW.

## Requirements

- Cyberpunk 2077 2.5
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- [RED4ext](https://www.nexusmods.com/cyberpunk2077/mods/2380)
- [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780)
- [ArchiveXL](https://www.nexusmods.com/cyberpunk2077/mods/4198)
- [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197)
- [Equipment-EX](https://www.nexusmods.com/cyberpunk2077/mods/6945)

Optional: [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885) for the settings
below.

Works with [WEAVE](https://www.nexusmods.com/cyberpunk2077/mods/28273) too, which replaces
Equipment-EX's scripts with a faster version (see its page for what it needs). Recommended if
you own thousands of clothing items.

## Install

Install with Vortex or Mod Organizer, or extract the archive into the game folder (the
folder that holds `bin`, `archive` and `r6`). Open the wardrobe the way Equipment-EX does.

## Settings

With Mod Settings installed, Settings > Mods > Wardrobe UI Improvements has two switches, both on by
default:

- **Preview items on hover**
- **Move camera to the selected area**

Changes apply the next time the wardrobe opens.

## Good to know

- Mouse and keyboard only. There is no controller navigation yet.
- With thousands of clothing items, Equipment-EX takes several seconds to build its item list
  every time the wardrobe opens (about 6 seconds with 9,000 items in testing). With WEAVE the
  same wardrobe opens in about a second.
- The mod's labels follow the game's language. Every language the game offers is included;
  the non-English texts are machine translations, so corrections are welcome. Slot, item and
  outfit names come from the game, Equipment-EX and the clothing mods.
- Pack names come from item IDs. A pack the mod doesn't know shows as its ID prefix in
  capitals, for example YV for VOID.
- Favourites, the last worn outfit, NEW tags and the column choice are stored in your save.
  To uninstall, delete `r6/scripts/WardrobeTabs` and `archive/pc/mod/WardrobeTabs.archive`.
  Saves made with the mod keep a little unused data.

## Changing or translating labels

Any label can be changed for one language without editing the mod's files (TweakXL does it):

1. Create a file in the game folder, for example
   `r6/tweaks/WUI_MyLabels/de-de.yaml` (any folder and file name ending in `.yaml`). Save it as
   UTF-8, without tabs.
2. Add one line per label you want to change:
   ```yaml
   WUI_Loc.de-de.Bar-Revert: "ZURÜCK"
   WUI_Loc.de-de.Area-Feet: "SCHUHE"
   ```
   - The part after the language code is the label's name. All names and their English are in
     `r6/scripts/WardrobeTabs/WardrobeTabsLocalizationTexts.reds`
     (`this.Text("WUI-<Name>", "English")`; leave out the `WUI-`).
   - Language codes: `ar-ar`, `cz-cz`, `de-de`, `en-us`, `es-es`, `es-mx`, `fr-fr`, `hu-hu`,
     `it-it`, `jp-jp`, `kr-kr`, `pl-pl`, `pt-br`, `ru-ru`, `th-th`, `tr-tr`, `ua-ua`, `zh-cn`,
     `zh-tw`. Use `en-us` to change the English.
   - If the original text holds `{0}`, keep it: the mod puts a number or a name there.
   - Labels you leave out keep the mod's own text.
3. Restart the game.

The wardrobe shows your labels the next time it opens. The Mod Settings menu shows them only
after switching the game's language once (to any language and back). A mistake in the file
makes TweakXL skip that file only; the error is in `red4ext/plugins/TweakXL/`'s log. The full
instructions are at the top of `r6/scripts/WardrobeTabs/WardrobeTabsLocalization.reds`. Send a
corrected translation to the mod author and it can ship with the mod as it is.

## Credits

Built on Equipment-EX by psiberx, with Codeware, ArchiveXL and TweakXL.

The card grid layouts in `WardrobeTabs.archive` are built from Equipment-EX's wardrobe layout,
used under the MIT License (Copyright (c) 2022 Pavel Siberx). The full notice is in
`THIRD_PARTY_NOTICES.txt` next to this README.
