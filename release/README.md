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
  so are the slots and tabs that hold them.
- **Mod packs**: each card names the clothing mod its item comes from, and PACK filters the
  grid to one pack. Packs are detected automatically.
- **Outfits**: a three-column grid with item icons, search and favourites. After you change
  a saved look, UPDATE saves the change and REVERT puts the outfit back.
- **EQUIPPED ONLY** shows only what V is wearing.

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
- Labels are in English.
- Pack names come from item IDs. A pack the mod doesn't know shows as its ID prefix in
  capitals, for example YV for VOID.
- Favourites, the last worn outfit, NEW tags and the column choice are stored in your save.
  To uninstall, delete `r6/scripts/WardrobeTabs` and `archive/pc/mod/WardrobeTabs.archive`.
  Saves made with the mod keep a little unused data.

## Credits

Built on Equipment-EX by psiberx, with Codeware, ArchiveXL and TweakXL.
