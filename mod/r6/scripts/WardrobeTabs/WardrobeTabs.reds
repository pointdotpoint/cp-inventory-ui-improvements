// WardrobeTabs: reorganises the Equipment-EX wardrobe (layout B in prototype/wardrobe-mockups).
// Requires Equipment-EX.
// - Body column, left of V: one group per body area with a tile per worn item and a + tile.
// - Drawer (the item panel): a header with the selected slot's name, a subtitle, search,
//   HEAD..FEET area tabs, column buttons, PACK and EQUIPPED ONLY; a sidebar left of the
//   grid with the area's slots; the grid as named cards, 4 to 7 per row; and the outfit bar
//   along the bottom (current look, OUTFITS / BACK).
//   Equipment-EX's slot headers and its own header row are hidden. Mouse only.
// - Outfits view (OUTFITS): SAVE OUTFIT, NO OUTFIT and a search box in the drawer header, and
//   the saved outfits as a three-column grid of cells, favourites (star) first.
//
// Two constraints shape this file:
// - Equipment-EX's grid classes are module-private, so this file joins its module.
// - redscript cannot wrap or add methods on classes defined in scripts, only fields. All
//   behaviour therefore hangs off the vanilla base classes (the screen's
//   inkPreviewGameController, the cells' VendorItemVirtualController), the item list is
//   narrowed by replacing the data source's contents instead of hooking the filter, and
//   changes Equipment-EX makes (rebuilt source, search text, filter, equipped items) are
//   found by polling from a looping animation.
module EquipmentEx

import Codeware.UI.*

public abstract class WardrobeTabsConfig {
    // A string per area rather than an array: in this setup an array returned by a static
    // function came back empty at runtime when indexed.
    public static func AreaLabel(area: Int32) -> String {
        switch area {
            case 0: return "HEAD";
            case 1: return "BODY";
            case 2: return "ARMS";
            case 3: return "LEGS";
            case 4: return "FEET";
        }
        return "OTHER";
    }

    // The vanilla equipment-area setup whose pose V takes for an area's camera. The vanilla
    // setups themselves only hold two shots (0-7 full body, 8-11 upper body at 1.85), so the
    // camera uses the mod's own setups below. Default is full body.
    public static func AreaCamera(area: Int32) -> InventoryPaperdollZoomArea {
        switch area {
            case 0: return InventoryPaperdollZoomArea.Head;
            case 1: return InventoryPaperdollZoomArea.OuterChest;
            case 2: return InventoryPaperdollZoomArea.Cyberware;
            case 3: return InventoryPaperdollZoomArea.Legs;
            case 4: return InventoryPaperdollZoomArea.Feet;
        }
        return InventoryPaperdollZoomArea.Default;
    }

    // Each area's own camera setup: an aim point from the inventory preview room
    // (empty_room_inventory.ent) and a camera distance (vanilla's upper-body shot is 1.85).
    // UpperBody is 1.43 above the floor and FullBody 1.05. Head, Chest and Legs are bound to
    // bones, but in the wardrobe they do not follow V's bones: Head aimed at V's feet (v25) and
    // Legs at her feet 0.4 to the side (v23-v24, V pushed right), so they resolve to V's origin
    // plus their offset. Head therefore serves as the feet point. Nothing sits above UpperBody,
    // so HEAD frames from there, farther back.
    public static func CameraSlot(area: Int32) -> CName {
        switch area {
            case 0: return n"UISlotPreview_UpperBody";
            case 1: return n"UISlotPreview_UpperBody";
            case 2: return n"UISlotPreview_FullBody";
            case 3: return n"UISlotPreview_FullBody";
            case 4: return n"UISlotPreview_Head";
        }
        return n"UISlotPreview_FullBody";
    }

    public static func CameraZoom(area: Int32) -> Float {
        switch area {
            case 0: return 1.45; // 1.1 cut the head off at the top
            case 1: return 1.85;
            case 2: return 1.85;
            case 3: return 1.85;
            case 4: return 2.2; // 1.6 showed one boot
        }
        return -1.0;
    }

    public static func CameraAreas() -> Int32 = 5;

    // Release version, logged once per wardrobe opening.
    public static func Version() -> String = "1.0.0";
    // Routine log lines (try-ons, camera moves, refills, clicks) for development; failures and
    // the opening line are always logged.
    public static func Verbose() -> Bool = false;

    // The FEET aim point is V's feet, so the camera centres them. No aim point sits between
    // the feet and the hips, so the preview image moves down this far (ink units, of its 2000)
    // while FEET is framed, to put the feet in the lower part of the view.
    public static func FeetLift() -> Float = 300.0;

    // NEW tags and the dots on rows and tabs that hold NEW items.
    public static func NewColor() -> HDRColor = new HDRColor(1.0, 0.85, 0.25, 1.0)

    // Horizontal shift of the V preview: centred between the body column and the drawer
    // (-140 before the slot sidebar widened the drawer, minus half of GridLeft()).
    public static func PreviewShift() -> Float = -318.0;

    // Catch-all for slots that are not in Equipment-EX's known areas, e.g. slots added by
    // other mods or by future Equipment-EX versions. Only shown when it has items.
    public static func OtherTab() -> Int32 = 5;

    // The drawer header replaces Equipment-EX's header rows inside the item panel, so the
    // grid sits right below it. The panel is 1382 wide including its scroll bar; the grid
    // container is 1352 wide. The slot sidebar widens both by GridLeft().
    public static func PanelWidth() -> Float = 1382.0;
    public static func HeaderHeight() -> Float = 230.0;
    public static func ContainerWidth() -> Float = 1352.0;
    // The grid container's height in Equipment-EX's layout. Set explicitly when the container
    // is widened: its GetSize() read 0 while building, which left the outfit bar (anchored to
    // the container's bottom) on top of the area tabs and the backdrop empty.
    public static func ContainerHeight() -> Float = 1414.0;
    // The outfit bar covers the bottom of the grid; the grid gets as much extra scroll room.
    public static func BarHeight() -> Float = 120.0;
    // Backdrop behind the grid.
    public static func GridBackdrop() -> Float = 0.5;

    // Body column: left edge, top, width. One group per body area shares GroupsHeight(),
    // at most GroupMax() each: a header, then a tile per worn item and a + tile.
    public static func BodyLeft() -> Float = 130.0;
    public static func BodyTop() -> Float = 300.0;
    public static func BodyWidth() -> Float = 640.0;
    public static func GroupsHeight() -> Float = 1540.0;
    public static func GroupMax() -> Float = 300.0;
    public static func GroupHeader() -> Float = 92.0;
    // Tiles per group, the + tile included.
    public static func GroupTiles() -> Int32 = 9;
    public static func TileMax() -> Float = 170.0;
    public static func TileGap() -> Float = 12.0;

    // Slot sidebar, left of the grid inside its container: slot chips per page, chip height and
    // gap, the sidebar's width and the gap before the grid. The grid container grows by
    // GridLeft(); Equipment-EX's panel is anchored right, so the drawer grows to the left.
    public static func ChipsPerPage() -> Int32 = 16;
    public static func ChipHeight() -> Float = 62.0;
    public static func ChipGap() -> Float = 8.0;
    public static func SidebarWidth() -> Float = 340.0;
    public static func GridLeft() -> Float = 356.0;

    // Card cells (wardrobe_tabs\gui\grid.inkwidget) are 192 x 216, seven to a row: the item
    // display (224 x 202) scaled to 168 x 151.5, then the name.
    // Measures for the seven-column cell; cells of other column counts (Root4..Root6 in the
    // archive) scale them by their width over 192 (WardrobeTabsCardScale).
    public static func CardArtScale() -> Float = 0.75;
    public static func CardArtLeft() -> Float = 12.0;
    public static func CardArtWidth() -> Float = 168.0;
    public static func CardNameTop() -> Float = 160.0;
    public static func CardNameWidth() -> Float = 172.0;
    // Watcher ticks (0.05 s each) the search text must stay unchanged before it filters.
    public static func SearchSettleTicks() -> Int32 = 3;
    // Watcher ticks (0.05 s) a card is hovered before V tries its item on (0.25 s pause plus a
    // 0.2 s debounce, so sweeping across cards previews nothing), and ticks with nothing
    // hovered before the preview goes back (bridges the gaps between cards).
    public static func TryOnTicks() -> Int32 = 9;
    public static func TryOffTicks() -> Int32 = 2;

    // Outfit cells, three to a row, inside Equipment-EX's outfit scroll area. Its slider takes
    // the right edge of the 1352 wide host.
    public static func OutfitColumns() -> Int32 = 3;
    public static func OutfitCellWidth() -> Float = 410.0;
    public static func OutfitCellHeight() -> Float = 172.0;
    public static func OutfitGap() -> Float = 16.0;
    // Item icons along the bottom of a cell, head to toe; the last slot reads +N when an
    // outfit has more. Item icons are about 200 tall, scaled to the slot.
    public static func OutfitIcons() -> Int32 = 7;
    public static func OutfitIconSize() -> Float = 46.0;
    public static func OutfitIconGap() -> Float = 6.0;
    public static func OutfitIconTop() -> Float = 104.0;
    // Visible height of the outfit grid, above the outfit bar, and the scroll per wheel notch.
    public static func OutfitViewHeight() -> Float = WardrobeTabsConfig.ContainerHeight() - WardrobeTabsConfig.BarHeight() - 30.0;
    public static func OutfitWheelStep() -> Float = 128.0;
    // The scroll bar's x, right of the cells. The manager it sits in has no size of its own,
    // so it is placed from the left.
    public static func OutfitBarLeft() -> Float = WardrobeTabsConfig.ContainerWidth() - 40.0;

    // Buttons after the area tabs, toggles, chip paging (0..9) and the chips: OUTFITS / BACK,
    // UPDATE and REVERT in the outfit bar, then the outfits view's SAVE OUTFIT and NO OUTFIT.
    public static func OutfitsButton() -> Int32 = 10 + WardrobeTabsConfig.ChipsPerPage();
    public static func UpdateButton() -> Int32 = WardrobeTabsConfig.OutfitsButton() + 1;
    public static func RevertButton() -> Int32 = WardrobeTabsConfig.OutfitsButton() + 2;
    public static func SaveOutfitButton() -> Int32 = WardrobeTabsConfig.OutfitsButton() + 3;
    public static func NoOutfitButton() -> Int32 = WardrobeTabsConfig.OutfitsButton() + 4;
    // PACK in the drawer header, then the rows of its list (ALL, BASE GAME, one per pack).
    public static func PackButton() -> Int32 = WardrobeTabsConfig.OutfitsButton() + 5;
    public static func PackRows() -> Int32 = 20;
    public static func PackRowHeight() -> Float = 52.0;
    // The column buttons 4 5 6 7, after the pack list's rows.
    public static func ColumnButton(columns: Int32) -> Int32 = WardrobeTabsConfig.PackButton() + 1 + WardrobeTabsConfig.PackRows() + columns - WardrobeTabsConfig.MinColumns();
    public static func MinColumns() -> Int32 = 4;
    public static func MaxColumns() -> Int32 = 7;

    // Areas are the slotArea names declared in OutfitConfig.OutfitSlots().
    public static func TabOfArea(area: CName) -> Int32 {
        if Equals(area, n"Head") || Equals(area, n"Face") || Equals(area, n"Ears") || Equals(area, n"Neck") {
            return 0;
        }
        if Equals(area, n"Torso") || Equals(area, n"Back") || Equals(area, n"Waist") || Equals(area, n"Body") {
            return 1;
        }
        if Equals(area, n"Arms") || Equals(area, n"Hands") || Equals(area, n"Fingers") {
            return 2;
        }
        if Equals(area, n"Legs") {
            return 3;
        }
        if Equals(area, n"Feet") || Equals(area, n"Toes") {
            return 4;
        }
        return WardrobeTabsConfig.OtherTab();
    }

    public static func TabOfSlot(slotID: TweakDBID) -> Int32 {
        for slot in OutfitConfig.OutfitSlots() {
            if slot.slotID == slotID {
                return WardrobeTabsConfig.TabOfArea(slot.slotArea);
            }
        }
        return WardrobeTabsConfig.OtherTab();
    }

    // Display name: some items' names arrive as an unresolved "LocKey#..." string.
    public static func ItemName(item: wref<InventoryGridItemData>) -> String {
        return WardrobeTabsConfig.CleanName(GetLocalizedText(item.Item.GetName()));
    }

    // Some mods name items like keys: "casual_pt37_boots_black" (Veegee's translations),
    // or the unresolved key itself, "casual_pt37_boots_black_name". A name with no spaces and
    // at least two "_" ends in the colour, so it is shown as "casual pt37 boots (black)" and
    // grouped by the "(...)" rule below.
    public static func CleanName(name: String) -> String {
        if StrFindFirst(name, " ") >= 0 || StrFindFirst(name, "_") < 0 {
            return name;
        }
        let key: String = name;
        if StrEndsWith(UTF8StrLower(key), "_name") {
            key = StrLeft(key, StrLen(key) - 5);
        }
        if StrFindFirst(key, "_") == StrFindLast(key, "_") {
            return StrReplaceAll(key, "_", " ");
        }
        return StrReplaceAll(StrBeforeLast(key, "_"), "_", " ") + " (" + StrAfterLast(key, "_") + ")";
    }
}



// Kept on the view manager so the choices survive closing the wardrobe.
@addField(ViewManager)
public let m_wtOutfitsSection: Bool;

@addField(ViewManager)
public let m_wtSlot: TweakDBID;

@addField(ViewManager)
public let m_wtArea: Int32;

// Favourite outfits by name, saved with the game like the outfits themselves.
@addField(OutfitSystem)
public persistent let m_wtFavourites: array<CName>;

// The outfit the current look came from: the last one worn exactly. Equipment-EX only knows an
// outfit while the look matches it, so after an edit only this says which outfit was edited.
@addField(OutfitSystem)
public persistent let m_wtLinked: CName;

// NEW tags. Every clothing record V owned (inventory, stash, wardrobe store) when the wardrobe
// last opened, and the ones that were new then and have not been hovered or equipped since.
// The first scan only records, so the tags start empty. Saved with the game.
@addField(OutfitSystem)
public persistent let m_wtSeen: array<TweakDBID>;

@addField(OutfitSystem)
public persistent let m_wtNewItems: array<TweakDBID>;

@addField(OutfitSystem)
public persistent let m_wtSeenReady: Bool;

// Card grid columns picked with the 4 5 6 7 buttons (0: never picked, seven).
@addField(OutfitSystem)
public persistent let m_wtColumns: Int32;

public func WardrobeTabsColumns() -> Int32 {
    let system: ref<OutfitSystem> = OutfitSystem.GetInstance(GetGameInstance());
    let columns: Int32 = IsDefined(system) ? system.m_wtColumns : 0;
    if columns < WardrobeTabsConfig.MinColumns() || columns > WardrobeTabsConfig.MaxColumns() {
        return WardrobeTabsConfig.MaxColumns();
    }
    return columns;
}

public func WardrobeTabsDebug(text: String) -> Void {
    if WardrobeTabsConfig.Verbose() {
        ModLog(n"WardrobeTabs", text);
    }
}

// A card cell's size relative to the seven-column one (192 wide).
public func WardrobeTabsCardScale(cell: ref<inkWidget>) -> Float {
    let width: Float = IsDefined(cell) ? cell.GetWidth() : 0.0;
    return width > 1.0 ? width / 192.0 : 1.0;
}

// m_wtNewItems as a lookup for the cards, rebuilt when the wardrobe opens.
@addField(ViewManager)
public let m_wtNewSet: ref<inkHashMap>;

public class WardrobeTabsMark {}

// A mod pack, detected in game (WardrobeTabsPackOf), with the number of owned items it holds
// as the wardrobe last listed them.
public class WardrobeTabsPack {
    public let prefix: String;
    public let name: String;
    public let lower: String;
    public let count: Int32;

    public static func Create(name: String) -> ref<WardrobeTabsPack> {
        let pack: ref<WardrobeTabsPack> = new WardrobeTabsPack();
        pack.name = name;
        pack.lower = UTF8StrLower(name);
        return pack;
    }
}

public class WardrobeTabsPackList {
    // In the order met; the PACK list sorts its rows by name. Never reordered, so a pack choice
    // (index + 2) stays valid while packs are added.
    public let packs: array<ref<WardrobeTabsPack>>;
    // TDBID.ToNumber(record) -> its WardrobeTabsPack, or baseMark for base-game items.
    public let index: ref<inkHashMap>;
    public let baseMark: ref<WardrobeTabsPack>;
    public let names: ref<WardrobeTabsPackNames>;
    public let baseCount: Int32;
}

@addField(ViewManager)
public let m_wtPackList: ref<WardrobeTabsPackList>;

// The pack filter: 0 all, 1 base game, 2 + n the list's pack n. Kept for the game session.
@addField(ViewManager)
public let m_wtPackChoice: Int32;

// The pack an item's record comes from (null: base game), worked out once per record. TweakDB
// keeps no source mod, so packs are inferred: base-game items name themselves with a numeric
// LocKey ("LocKey#12345"), mods with their own keys or text; a mod item's pack is its record
// ID's prefix (Items.yv_long_coat -> "yv"), named through WardrobeTabsPackNames (generated by
// tools/build_pack_index.py) or shown as the prefix in capitals.
public func WardrobeTabsPackOf(itemID: ItemID) -> wref<WardrobeTabsPack> {
    let list: ref<WardrobeTabsPackList> = ViewManager.GetInstance(GetGameInstance()).m_wtPackList;
    if !IsDefined(list) {
        return null;
    }
    let record: TweakDBID = ItemID.GetTDBID(itemID);
    let key: Uint64 = TDBID.ToNumber(record);
    let pack: ref<WardrobeTabsPack>;
    if list.index.KeyExist(key) {
        pack = list.index.Get(key) as WardrobeTabsPack;
    } else {
        pack = WardrobeTabsDetectPack(list, record);
        list.index.Insert(key, pack);
    }
    return pack == list.baseMark ? null : pack;
}

public func WardrobeTabsDetectPack(list: ref<WardrobeTabsPackList>, record: TweakDBID) -> ref<WardrobeTabsPack> {
    let item: ref<Item_Record> = TweakDBInterface.GetItemRecord(record);
    if !IsDefined(item) || WardrobeTabsIsBaseName(NameToString(item.DisplayName())) {
        return list.baseMark;
    }
    let id: String = TDBID.ToStringDEBUG(record);
    if StrBeginsWith(id, "Items.") {
        id = StrMid(id, 6);
    }
    // Up to the first _ or . (Items.kozsa.apocalypse_x -> "kozsa").
    let length: Int32 = 0;
    while length < StrLen(id) && NotEquals(StrMid(id, length, 1), "_") && NotEquals(StrMid(id, length, 1), ".") {
        length += 1;
    }
    let prefix: String = UTF8StrLower(StrLeft(id, length));
    if StrLen(prefix) == 0 {
        return list.baseMark;
    }
    for pack in list.packs {
        if Equals(pack.prefix, prefix) {
            return pack;
        }
    }
    let name: String = list.names.Name(prefix);
    let pack: ref<WardrobeTabsPack> = WardrobeTabsPack.Create(StrLen(name) > 0 ? name : StrUpper(prefix));
    pack.prefix = prefix;
    ArrayPush(list.packs, pack);
    return pack;
}

// "LocKey#" and digits only (or no name at all): a base-game name. Mods use their own keys,
// including "LocKey#" followed by text.
public func WardrobeTabsIsBaseName(name: String) -> Bool {
    if StrLen(name) == 0 || Equals(name, "None") {
        return true;
    }
    if !StrBeginsWith(name, "LocKey#") || StrLen(name) == 7 {
        return false;
    }
    let index: Int32 = 7;
    while index < StrLen(name) {
        let digit: String = StrMid(name, index, 1);
        if StrCmp(digit, "0") < 0 || StrCmp(digit, "9") > 0 {
            return false;
        }
        index += 1;
    }
    return true;
}

// Area index + 1, resolved once per slot. 0 marks slot data the mod has not seen yet,
// which is how a repopulated grid is recognised.
@addField(InventoryGridSlotData)
public let m_wtTab: Int32;

@addField(WardrobeScreenController)
public let m_wtBuilt: Bool;

@addField(WardrobeScreenController)
public let m_wtAllItems: array<ref<IScriptable>>;

@addField(WardrobeScreenController)
public let m_wtWatcher: ref<inkAnimProxy>;

@addField(WardrobeScreenController)
public let m_wtGrid: wref<inkCompoundWidget>;

@addField(WardrobeScreenController)
public let m_wtOutfitsHost: wref<inkWidget>;

// Slot data in Equipment-EX's order, the item worn in each (or null), and how many of
// each slot's items match the search and filter.
@addField(WardrobeScreenController)
public let m_wtSlots: array<ref<InventoryGridSlotData>>;

@addField(WardrobeScreenController)
public let m_wtWorn: array<ref<InventoryGridItemData>>;

// Per slot: a worn item that is not in any of the grid's lists (Equipment-EX lists only the
// selected item source), read from the item attached to the player's slot instead.
@addField(WardrobeScreenController)
public let m_wtWornNames: array<String>;

@addField(WardrobeScreenController)
public let m_wtWornIcons: array<String>;

@addField(WardrobeScreenController)
public let m_wtWornRecords: array<TweakDBID>;

// What the column shows, one entry per worn slot; the grid is refilled only when it changes.
@addField(WardrobeScreenController)
public let m_wtWornSig: String;

@addField(WardrobeScreenController)
public let m_wtMatches: array<Int32>;

@addField(WardrobeScreenController)
public let m_wtUsedSlots: Int32;

@addField(WardrobeScreenController)
public let m_wtQuery: String;

// The search box's text as last seen, and ticks since it last changed: the search is applied
// once it has settled (WardrobeTabsConfig.SearchSettleTicks).
@addField(WardrobeScreenController)
public let m_wtTyped: String;

@addField(WardrobeScreenController)
public let m_wtTypedTicks: Int32;

// True once Equipment-EX's per-keystroke OnInput filter is unhooked and this mod filters.
@addField(WardrobeScreenController)
public let m_wtSearchOwned: Bool;

// An item's name as the search compares it, made once per item (Equipment-EX makes new item
// data whenever it rebuilds the grid).
@addField(InventoryGridItemData)
public let m_wtSearchName: String;

@addField(InventoryGridItemData)
public let m_wtSearchReady: Bool;

@addField(InventoryGridItemData)
public let m_wtPack: wref<WardrobeTabsPack>;

@addField(InventoryGridItemData)
public let m_wtPackReady: Bool;

// The PACK list: open or not, and which pack choice each row stands for.
@addField(WardrobeScreenController)
public let m_wtPackOpen: Bool;

@addField(WardrobeScreenController)
public let m_wtPackMenu: wref<inkCanvas>;

@addField(WardrobeScreenController)
public let m_wtPackRowChoice: array<Int32>;

@addField(WardrobeScreenController)
public let m_wtEquippedOnly: Bool;

@addField(WardrobeScreenController)
public let m_wtHover: wref<inkWidget>;

// Body column: one group per area (group g shows area g), each with a header and pooled
// tiles. m_wtTileSlots holds, per tile, the slot it shows, -2 for the + tile, or -1.
@addField(WardrobeScreenController)
public let m_wtGroupHeads: array<wref<inkCanvas>>;

@addField(WardrobeScreenController)
public let m_wtGroupLabels: array<wref<inkText>>;

@addField(WardrobeScreenController)
public let m_wtGroupCounts: array<wref<inkText>>;

@addField(WardrobeScreenController)
public let m_wtGroupDetails: array<wref<inkText>>;

@addField(WardrobeScreenController)
public let m_wtTiles: array<wref<inkCanvas>>;

@addField(WardrobeScreenController)
public let m_wtTileBgs: array<wref<inkRectangle>>;

@addField(WardrobeScreenController)
public let m_wtTileBars: array<wref<inkRectangle>>;

@addField(WardrobeScreenController)
public let m_wtTileIcons: array<wref<inkImage>>;

@addField(WardrobeScreenController)
public let m_wtTileIconPaths: array<String>;

@addField(WardrobeScreenController)
public let m_wtTilePlus: array<wref<inkText>>;

@addField(WardrobeScreenController)
public let m_wtTileSlots: array<Int32>;

// Drawer header.
@addField(WardrobeScreenController)
public let m_wtTitle: wref<inkText>;

@addField(WardrobeScreenController)
public let m_wtSubtitle: wref<inkText>;

@addField(WardrobeScreenController)
public let m_wtClothingOnly: array<wref<inkWidget>>;

@addField(WardrobeScreenController)
public let m_wtHeader: wref<inkCompoundWidget>;

// Buttons: area tabs (0..5), a hidden placeholder (6), EQUIPPED ONLY (7), chip paging (8, 9),
// slot chips (10..), OUTFITS / BACK, SAVE OUTFIT and NO OUTFIT (WardrobeTabsConfig). Each
// has a background, a label and an optional count.
@addField(WardrobeScreenController)
public let m_wtButtons: array<wref<inkCanvas>>;

@addField(WardrobeScreenController)
public let m_wtButtonBgs: array<wref<inkRectangle>>;

@addField(WardrobeScreenController)
public let m_wtButtonTexts: array<wref<inkText>>;

@addField(WardrobeScreenController)
public let m_wtButtonCounts: array<wref<inkText>>;

// The NEW dot on each button (area tabs and slot rows use it), and per slot whether its list
// holds a NEW item.
@addField(WardrobeScreenController)
public let m_wtButtonNews: array<wref<inkRectangle>>;

@addField(WardrobeScreenController)
public let m_wtSlotNew: array<Bool>;

@addField(WardrobeScreenController)
public let m_wtScanned: Bool;

// Slot index per chip on the current page, and the page's first entry.
@addField(WardrobeScreenController)
public let m_wtChipSlots: array<Int32>;

@addField(WardrobeScreenController)
public let m_wtChipOffset: Int32;

@addField(WardrobeScreenController)
public let m_wtLook: wref<inkText>;

// The outfit bar sits in the grid container, or in the outfit list's host in OUTFITS.
@addField(WardrobeScreenController)
public let m_wtBar: wref<inkCanvas>;

// Outfits view: header widgets shown only there, its search box, the outfits in cell order
// with their item counts, and the cells (made as needed, kept while the screen is open).
@addField(WardrobeScreenController)
public let m_wtOutfitsOnly: array<wref<inkWidget>>;

@addField(WardrobeScreenController)
public let m_wtOutfitSearch: ref<HubTextInput>;

// The X inside the search box: clears whichever search the view shows (items or outfits).
@addField(WardrobeScreenController)
public let m_wtSearchClear: wref<inkCanvas>;

@addField(WardrobeScreenController)
public let m_wtOutfitQuery: String;

// Hover try-on. The card's item display under the cursor (and a hovered colour's item) is
// kept on Equipment-EX's ViewManager, which displays and screen can both reach; the screen's
// watcher puts its item on the preview once it has been hovered for TryOnTicks().
@addField(ViewManager)
public let m_wtHoverCard: wref<InventoryItemDisplayController>;

// What the watcher last saw under the cursor, for how many ticks, and for how many ticks
// nothing has been; the item on the preview and the slot it went into.
@addField(WardrobeScreenController)
public let m_wtTryHover: wref<UIInventoryItem>;

@addField(WardrobeScreenController)
public let m_wtTryCard: wref<InventoryItemDisplayController>;

@addField(WardrobeScreenController)
public let m_wtTryTicks: Int32;

@addField(WardrobeScreenController)
public let m_wtTryIdle: Int32;

// Mod Settings values, read when the wardrobe opens (WardrobeTabsSettings.reds).
@addField(WardrobeScreenController)
public let m_wtSettings: ref<WardrobeTabsSettings>;

// Engine time the hovered item changed, to log the real pause before a try-on.
@addField(WardrobeScreenController)
public let m_wtTryStart: Float;

// How far the preview image is moved down (FeetLift() while FEET is framed, else 0).
@addField(WardrobeScreenController)
public let m_wtLift: Float;

@addField(WardrobeScreenController)
public let m_wtLiftAnim: ref<inkAnimProxy>;

@addField(WardrobeScreenController)
public let m_wtTrying: wref<UIInventoryItem>;

@addField(WardrobeScreenController)
public let m_wtTrySlot: TweakDBID;

// Outfit names at the last fill, to tell a newly saved outfit.
@addField(WardrobeScreenController)
public let m_wtOutfitKnown: array<CName>;

@addField(WardrobeScreenController)
public let m_wtOutfitNames: array<CName>;

@addField(WardrobeScreenController)
public let m_wtOutfitParts: array<Int32>;

@addField(WardrobeScreenController)
public let m_wtOutfitContent: wref<inkCanvas>;

@addField(WardrobeScreenController)
public let m_wtOutfitEmpty: wref<inkText>;

// How far the outfit grid is scrolled, how far it can be, and its scroll bar.
@addField(WardrobeScreenController)
public let m_wtOutfitScroll: Float;

@addField(WardrobeScreenController)
public let m_wtOutfitScrollMax: Float;

@addField(WardrobeScreenController)
public let m_wtOutfitTrack: wref<inkRectangle>;

@addField(WardrobeScreenController)
public let m_wtOutfitThumb: wref<inkRectangle>;

@addField(WardrobeScreenController)
public let m_wtOutfitCells: array<wref<inkCanvas>>;

@addField(WardrobeScreenController)
public let m_wtOutfitCellBgs: array<wref<inkRectangle>>;

@addField(WardrobeScreenController)
public let m_wtOutfitCellBars: array<wref<inkRectangle>>;

@addField(WardrobeScreenController)
public let m_wtOutfitCellNames: array<wref<inkText>>;

@addField(WardrobeScreenController)
public let m_wtOutfitCellInfos: array<wref<inkText>>;

@addField(WardrobeScreenController)
public let m_wtOutfitStars: array<wref<inkCanvas>>;

@addField(WardrobeScreenController)
public let m_wtOutfitStarIcons: array<wref<inkImage>>;

@addField(WardrobeScreenController)
public let m_wtStarHover: wref<inkWidget>;

// The widget the last press started on (see OnWardrobePress).
@addField(WardrobeScreenController)
public let m_wtPressed: wref<inkWidget>;

// OutfitIcons() per cell, in cell order: the icon slots, their images, the icon each shows
// and the +N label (one per cell).
@addField(WardrobeScreenController)
public let m_wtOutfitIconSlots: array<wref<inkCanvas>>;

@addField(WardrobeScreenController)
public let m_wtOutfitIcons: array<wref<inkImage>>;

@addField(WardrobeScreenController)
public let m_wtOutfitIconPaths: array<String>;

@addField(WardrobeScreenController)
public let m_wtOutfitMores: array<wref<inkText>>;

// What the outfit cells were filled from (search text and outfit names), and which outfit
// was worn: the watcher refills them when either changes.
@addField(WardrobeScreenController)
public let m_wtOutfitSig: String;

@addField(WardrobeScreenController)
public let m_wtOutfitWorn: String;

// Slots that differ from the linked outfit; -1 while the look matches it or nothing is linked.
@addField(WardrobeScreenController)
public let m_wtLinkChanges: Int32;

// The area the preview camera was last moved to, plus one (0: full body, as the wardrobe
// opens), and the one to go back to when OUTFITS closes.
@addField(WardrobeScreenController)
public let m_wtCameraArea: Int32;

@addField(WardrobeScreenController)
public let m_wtCameraResume: Int32;

@wrapMethod(inkPreviewGameController)
protected cb func OnInitialize() -> Bool {
    wrappedMethod();
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if IsDefined(screen) {
        this.WardrobeTabsInstallGrid();
        // Equipment-EX calls super.OnInitialize() before creating its outfit list, grid and
        // header buttons, so building here would be too early. The watcher's first tick
        // builds the layout once everything exists.
        this.WardrobeTabsStartWatcher(screen);
    }
}

// One of the archive's grids (Root4..Root7), named and placed as Equipment-EX's was.
@addMethod(inkPreviewGameController)
private func WardrobeTabsSpawnGrid(area: ref<inkCompoundWidget>, columns: Int32) -> ref<inkWidget> {
    let grid: ref<inkWidget> = this.SpawnFromExternal(area, r"wardrobe_tabs\\gui\\grid.inkwidget", StringToName("Root" + ToString(columns)));
    if IsDefined(grid) {
        grid.SetName(n"vendor_virtualgrid");
        grid.SetMargin(new inkMargin(0.0, 0.0, 0.0, WardrobeTabsConfig.BarHeight() + 10.0));
    }
    return grid;
}

// Swaps the card grid for another column count while the wardrobe is open: Equipment-EX's
// grid controller is unbound, the new grid takes its place, classifier and data view, and
// Equipment-EX's fields point at it. The choice is saved with the game.
@addMethod(inkPreviewGameController)
private func WardrobeTabsSetColumns(screen: ref<WardrobeScreenController>, columns: Int32) -> Void {
    screen.m_outfitSystem.m_wtColumns = columns;
    let area: ref<inkCompoundWidget> = this.GetChildWidgetByPath(n"wrapper/wrapper/vendorPanel/inventoryContainer/stash_scroll_area_cache/scrollArea") as inkCompoundWidget;
    let old: ref<inkWidget> = screen.m_inventoryGridArea;
    if !IsDefined(area) || !IsDefined(old) || !Equals(old.GetName(), n"vendor_virtualgrid") {
        ModLog(n"WardrobeTabs", "Columns: grid not found, " + ToString(columns) + " applies next opening");
        return;
    }
    this.WardrobeTabsEndTryOn(screen);
    let view: ref<ViewManager> = this.WardrobeTabsView();
    view.m_wtHoverCard = null;
    let grid: ref<inkWidget> = this.WardrobeTabsSpawnGrid(area, columns);
    let controller: ref<inkVirtualGridController> = IsDefined(grid) ? grid.GetController() as inkVirtualGridController : null;
    if !IsDefined(controller) {
        if IsDefined(grid) {
            area.RemoveChild(grid);
        }
        ModLog(n"WardrobeTabs", "Columns: grid spawn failed, " + ToString(columns) + " applies next opening");
        return;
    }
    screen.m_inventoryGridController.SetSource(null);
    screen.m_inventoryGridController.SetClassifier(null);
    area.RemoveChild(old);
    screen.m_inventoryGridArea = grid;
    screen.m_inventoryGridController = controller;
    controller.SetClassifier(screen.m_inventoryGridTemplateClassifier);
    controller.SetSource(screen.m_inventoryGridDataView);
    this.WardrobeTabsApply(screen, true);
    WardrobeTabsDebug("Columns: " + ToString(columns));
}

// Install before Equipment-EX captures the grid controller and binds its data source.
// The bottom margin is scroll room for the outfit bar that covers the grid's bottom edge.
@addMethod(inkPreviewGameController)
private func WardrobeTabsInstallGrid() -> Void {
    let area: ref<inkCompoundWidget> = this.GetChildWidgetByPath(n"wrapper/wrapper/vendorPanel/inventoryContainer/stash_scroll_area_cache/scrollArea") as inkCompoundWidget;
    if !IsDefined(area) || !GameInstance.GetResourceDepot().ResourceExists(r"wardrobe_tabs\\gui\\grid.inkwidget") {
        ModLog(n"WardrobeTabs", "Card grid unavailable; retaining original grid");
        return;
    }
    let original: ref<inkWidget> = area.GetWidget(n"vendor_virtualgrid");
    if !IsDefined(original) {
        return;
    }
    let columns: Int32 = WardrobeTabsColumns();
    let grid: ref<inkWidget> = this.WardrobeTabsSpawnGrid(area, columns);
    if IsDefined(grid) && IsDefined(grid.GetController() as inkVirtualGridController) {
        area.RemoveChild(original);
        WardrobeTabsDebug("Card grid v4 installed before data binding (" + ToString(columns) + " columns)");
    } else {
        ModLog(n"WardrobeTabs", "Card grid spawn failed; retaining original grid");
        if IsDefined(grid) {
            area.RemoveChild(grid);
        }
    }
}

// Card cells: the asynchronously spawned item display keeps its size, at the top.
@wrapMethod(VendorItemVirtualController)
protected cb func OnSpawned(widget: ref<inkWidget>, userData: ref<IScriptable>) -> Bool {
    if IsDefined(this as InventoryGridItemController) && Equals(this.GetRootWidget().GetName(), n"wardrobeCardItem") {
        widget.SetAnchor(inkEAnchor.TopLeft);
        widget.SetAnchorPoint(new Vector2(0.0, 0.0));
        widget.SetHAlign(inkEHorizontalAlign.Left);
        widget.SetVAlign(inkEVerticalAlign.Top);
        let k: Float = WardrobeTabsCardScale(this.GetRootWidget());
        widget.SetMargin(new inkMargin(WardrobeTabsConfig.CardArtLeft() * k, 4.0 * k, 0.0, 0.0));
        widget.SetRenderTransformPivot(new Vector2(0.0, 0.0));
        widget.SetScale(new Vector2(WardrobeTabsConfig.CardArtScale() * k, WardrobeTabsConfig.CardArtScale() * k));
    }
    return wrappedMethod(widget, userData);
}

// Card cells are recycled while scrolling: name, WEARING, NEW and pack labels follow the data.
@wrapMethod(VendorItemVirtualController)
public final func OnDataChanged(value: Variant) -> Void {
    wrappedMethod(value);
    if IsDefined(this as InventoryGridItemController) && Equals(this.GetRootWidget().GetName(), n"wardrobeCardItem") {
        this.WardrobeTabsDecorateCard();
    }
}

@addMethod(VendorItemVirtualController)
private func WardrobeTabsDecorateCard() -> Void {
    let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
    if !IsDefined(root) {
        return;
    }
    // Cells of fewer columns are bigger: measures scale by k, text by the gentler t.
    let k: Float = WardrobeTabsCardScale(root);
    let t: Float = 1.0 + (k - 1.0) * 0.5;
    let left: Float = (WardrobeTabsConfig.CardArtLeft() + 2.0) * k;
    let label: ref<inkText> = root.GetWidget(n"wardrobeCardName") as inkText;
    if !IsDefined(label) {
        label = new inkText();
        label.SetName(n"wardrobeCardName");
        label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        label.SetLetterCase(textLetterCase.UpperCase);
        label.SetFontSize(Cast<Int32>(20.0 * t));
        label.SetAnchor(inkEAnchor.TopLeft);
        label.SetFitToContent(false);
        label.SetMargin(new inkMargin(left, WardrobeTabsConfig.CardNameTop() * k, 0.0, 0.0));
        label.SetWrapping(true, WardrobeTabsConfig.CardNameWidth() * k);
        label.SetOverflowPolicy(textOverflowPolicy.DotsEndLastLine);
        label.SetInteractive(false);
        label.Reparent(root);

        let tag: ref<inkCanvas> = new inkCanvas();
        tag.SetName(n"wardrobeCardTag");
        tag.SetAnchor(inkEAnchor.TopLeft);
        tag.SetSize(84.0 * t, 24.0 * t);
        tag.SetMargin(new inkMargin((WardrobeTabsConfig.CardArtLeft() + WardrobeTabsConfig.CardArtWidth()) * k - 90.0 * t, 9.0 * k, 0.0, 0.0));
        tag.SetInteractive(false);
        tag.Reparent(root);
        let tagBg: ref<inkRectangle> = new inkRectangle();
        tagBg.SetAnchor(inkEAnchor.Fill);
        tagBg.SetTintColor(new HDRColor(0.369, 0.965, 1.0, 1.0));
        tagBg.SetInteractive(false);
        tagBg.Reparent(tag);
        let tagText: ref<inkText> = new inkText();
        tagText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        tagText.SetLetterCase(textLetterCase.UpperCase);
        tagText.SetFontSize(Cast<Int32>(16.0 * t));
        tagText.SetText("WEARING");
        tagText.SetAnchor(inkEAnchor.Centered);
        tagText.SetAnchorPoint(0.5, 0.5);
        tagText.SetTintColor(new HDRColor(0.02, 0.03, 0.04, 1.0));
        tagText.SetInteractive(false);
        tagText.Reparent(tag);

        let newTag: ref<inkCanvas> = new inkCanvas();
        newTag.SetName(n"wardrobeCardNew");
        newTag.SetAnchor(inkEAnchor.TopLeft);
        // Same font, size and weight as the card name below.
        newTag.SetSize(62.0 * t, 28.0 * t);
        newTag.SetMargin(new inkMargin((WardrobeTabsConfig.CardArtLeft() + 10.0) * k, 9.0 * k, 0.0, 0.0));
        newTag.SetInteractive(false);
        newTag.Reparent(root);
        let newBg: ref<inkRectangle> = new inkRectangle();
        newBg.SetAnchor(inkEAnchor.Fill);
        newBg.SetTintColor(WardrobeTabsConfig.NewColor());
        newBg.SetInteractive(false);
        newBg.Reparent(newTag);
        let newText: ref<inkText> = new inkText();
        newText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        newText.SetLetterCase(textLetterCase.UpperCase);
        newText.SetFontSize(Cast<Int32>(20.0 * t));
        newText.SetText("NEW");
        newText.SetAnchor(inkEAnchor.Centered);
        newText.SetAnchorPoint(0.5, 0.5);
        newText.SetTintColor(new HDRColor(0.02, 0.03, 0.04, 1.0));
        newText.SetInteractive(false);
        newText.Reparent(newTag);

        // Pack name over the bottom of the item art (the name below keeps its two lines).
        let packText: ref<inkText> = new inkText();
        packText.SetName(n"wardrobeCardPack");
        packText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        packText.SetLetterCase(textLetterCase.UpperCase);
        packText.SetFontSize(Cast<Int32>(16.0 * t));
        packText.SetAnchor(inkEAnchor.TopLeft);
        packText.SetFitToContent(false);
        packText.SetSize((WardrobeTabsConfig.CardArtWidth() - 12.0) * k, 22.0 * t);
        packText.SetMargin(new inkMargin((WardrobeTabsConfig.CardArtLeft() + 8.0) * k, 154.0 * k - 22.0 * t, 0.0, 0.0));
        packText.SetOverflowPolicy(textOverflowPolicy.DotsEnd);
        packText.SetTintColor(new HDRColor(0.92, 0.62, 0.56, 0.85));
        packText.SetInteractive(false);
        packText.Reparent(root);
    }
    let tag: ref<inkWidget> = root.GetWidget(n"wardrobeCardTag");
    let newTag: ref<inkWidget> = root.GetWidget(n"wardrobeCardNew");
    let packText: ref<inkText> = root.GetWidget(n"wardrobeCardPack") as inkText;
    let data: ref<InventoryGridItemData> = this.m_newData as InventoryGridItemData;
    if !IsDefined(data) {
        label.SetText("");
        packText.SetText("");
        tag.SetVisible(false);
        newTag.SetVisible(false);
        return;
    }
    let wearing: Bool = data.Item.IsEquipped();
    let fresh: Bool = WardrobeTabsIsNew(data.Item.GetID());
    tag.SetVisible(wearing);
    newTag.SetVisible(fresh && !wearing);
    let pack: wref<WardrobeTabsPack> = WardrobeTabsPackOf(data.Item.GetID());
    packText.SetText(IsDefined(pack) ? pack.name : "");
    label.SetText(WardrobeTabsConfig.ItemName(data));
    label.SetWrapping(true, WardrobeTabsConfig.CardNameWidth() * k);
    label.SetSize(WardrobeTabsConfig.CardNameWidth() * k, 50.0 * t);
    label.SetTintColor(wearing ? new HDRColor(0.369, 0.965, 1.0, 1.0) : new HDRColor(1.176, 0.381, 0.348, 1.0));
}

// Card hover for try-on, from the vanilla item display (the path Equipment-EX's tooltip
// takes). Only displays inside a wardrobe card cell count.
@addMethod(InventoryItemDisplayController)
private func WardrobeTabsInCard() -> Bool {
    let widget: wref<inkWidget> = this.GetRootWidget();
    let depth: Int32 = 0;
    while IsDefined(widget) && depth < 3 {
        if Equals(widget.GetName(), n"wardrobeCardItem") {
            return true;
        }
        widget = widget.GetParentWidget();
        depth += 1;
    }
    return false;
}

@wrapMethod(InventoryItemDisplayController)
protected cb func OnDisplayHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    if this.WardrobeTabsInCard() {
        ViewManager.GetInstance(GetGameInstance()).m_wtHoverCard = this;
    }
    return result;
}

public func WardrobeTabsIsNew(itemID: ItemID) -> Bool {
    let set: ref<inkHashMap> = ViewManager.GetInstance(GetGameInstance()).m_wtNewSet;
    return IsDefined(set) && set.KeyExist(TDBID.ToNumber(ItemID.GetTDBID(itemID)));
}

// Hides the hovered card's NEW tag at once; the next rebind reads the cleared set anyway.
@addMethod(InventoryItemDisplayController)
public func WardrobeTabsHideNewTag() -> Void {
    let widget: wref<inkWidget> = this.GetRootWidget();
    let depth: Int32 = 0;
    while IsDefined(widget) && depth < 3 {
        if Equals(widget.GetName(), n"wardrobeCardItem") {
            let tag: ref<inkWidget> = (widget as inkCompoundWidget).GetWidget(n"wardrobeCardNew");
            if IsDefined(tag) {
                tag.SetVisible(false);
            }
            return;
        }
        widget = widget.GetParentWidget();
        depth += 1;
    }
}

@wrapMethod(InventoryItemDisplayController)
protected cb func OnDisplayHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    let view: ref<ViewManager> = ViewManager.GetInstance(GetGameInstance());
    if IsDefined(view) && view.m_wtHoverCard == this {
        view.m_wtHoverCard = null;
    }
    return result;
}

@wrapMethod(inkPreviewGameController)
protected cb func OnUninitialize() -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if IsDefined(screen) {
        // The menus' preview puppet outlives the wardrobe: never leave a tried item on it.
        this.WardrobeTabsEndTryOn(screen);
        let view: ref<ViewManager> = this.WardrobeTabsView();
        view.m_wtHoverCard = null;
        if IsDefined(screen.m_wtWatcher) {
            screen.m_wtWatcher.UnregisterFromAllCallbacks(inkanimEventType.OnEndLoop);
            screen.m_wtWatcher.Stop();
            screen.m_wtWatcher = null;
        }
        ArrayClear(screen.m_wtAllItems);
        ArrayClear(screen.m_wtSlots);
        ArrayClear(screen.m_wtWorn);
        ArrayClear(screen.m_wtWornNames);
        ArrayClear(screen.m_wtWornIcons);
        ArrayClear(screen.m_wtWornRecords);
        ArrayClear(screen.m_wtClothingOnly);
        ArrayClear(screen.m_wtGroupHeads);
        ArrayClear(screen.m_wtTiles);
        ArrayClear(screen.m_wtButtons);
        ArrayClear(screen.m_wtButtonNews);
        ArrayClear(screen.m_wtOutfitsOnly);
        ArrayClear(screen.m_wtOutfitCells);
        ArrayClear(screen.m_wtOutfitStars);
    }
    wrappedMethod();
}

// Text tinted directly, so hover and selection can recolor it.
@addMethod(inkPreviewGameController)
private func WardrobeTabsMakeText(fontSize: Int32, width: Float) -> ref<inkText> {
    let label: ref<inkText> = new inkText();
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    label.SetLetterCase(textLetterCase.UpperCase);
    label.SetFontSize(fontSize);
    label.SetAnchor(inkEAnchor.TopLeft);
    if width > 0.0 {
        label.SetFitToContent(false);
        label.SetSize(width, Cast<Float>(fontSize) + 10.0);
        label.SetOverflowPolicy(textOverflowPolicy.DotsEnd);
    } else {
        label.SetFitToContent(true);
    }
    label.SetInteractive(false);
    return label;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsMakeRect(color: HDRColor, opacity: Float) -> ref<inkRectangle> {
    let rect: ref<inkRectangle> = new inkRectangle();
    rect.SetAnchor(inkEAnchor.Fill);
    rect.SetTintColor(color);
    rect.SetOpacity(opacity);
    rect.SetInteractive(false);
    return rect;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsMakeButton(screen: ref<WardrobeScreenController>, parent: ref<inkCompoundWidget>, text: String, x: Float, y: Float, width: Float, height: Float) -> ref<inkCanvas> {
    let button: ref<inkCanvas> = new inkCanvas();
    button.SetAnchor(inkEAnchor.TopLeft);
    button.SetSize(width, height);
    button.SetMargin(new inkMargin(x, y, 0.0, 0.0));
    button.childOrder = inkEChildOrder.Forward;
    button.SetInteractive(true);
    button.RegisterToCallback(n"OnRelease", this, n"OnWardrobeButtonClick");
    button.RegisterToCallback(n"OnPress", this, n"OnWardrobePress");
    button.RegisterToCallback(n"OnHoverOver", this, n"OnWardrobeTabsHoverOver");
    button.RegisterToCallback(n"OnHoverOut", this, n"OnWardrobeTabsHoverOut");
    button.Reparent(parent);
    let bg: ref<inkRectangle> = this.WardrobeTabsMakeRect(new HDRColor(0.263, 0.086, 0.094, 1.0), 0.8);
    bg.Reparent(button);
    let edge: ref<inkRectangle> = new inkRectangle();
    edge.SetAnchor(inkEAnchor.BottomFillHorizontaly);
    edge.SetSize(width, 3.0);
    edge.SetTintColor(new HDRColor(0.682, 0.231, 0.212, 1.0));
    edge.SetInteractive(false);
    edge.Reparent(button);
    let label: ref<inkText> = this.WardrobeTabsMakeText(Cast<Int32>(height * 0.45), 0.0);
    label.SetText(text);
    label.SetAnchor(inkEAnchor.Centered);
    label.SetAnchorPoint(0.5, 0.5);
    label.Reparent(button);
    let count: ref<inkText> = this.WardrobeTabsMakeText(22, 0.0);
    count.SetAnchor(inkEAnchor.CenterRight);
    count.SetAnchorPoint(1.0, 0.5);
    count.SetMargin(new inkMargin(0.0, 0.0, 12.0, 0.0));
    count.Reparent(button);
    let news: ref<inkRectangle> = new inkRectangle();
    news.SetAnchor(inkEAnchor.TopRight);
    news.SetAnchorPoint(1.0, 0.0);
    news.SetSize(10.0, 10.0);
    news.SetMargin(new inkMargin(0.0, 5.0, 5.0, 0.0));
    news.SetTintColor(WardrobeTabsConfig.NewColor());
    news.SetVisible(false);
    news.SetInteractive(false);
    news.Reparent(button);
    ArrayPush(screen.m_wtButtons, button);
    ArrayPush(screen.m_wtButtonBgs, bg);
    ArrayPush(screen.m_wtButtonTexts, label);
    ArrayPush(screen.m_wtButtonCounts, count);
    ArrayPush(screen.m_wtButtonNews, news);
    return button;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsBuild(screen: ref<WardrobeScreenController>) -> Void {
    screen.m_wtBuilt = true;
    screen.m_wtSettings = new WardrobeTabsSettings();
    let panel: ref<inkCompoundWidget> = this.GetChildWidgetByPath(n"wrapper/wrapper/vendorPanel") as inkCompoundWidget;
    let wrapper: ref<inkCompoundWidget> = this.GetChildWidgetByPath(n"wrapper") as inkCompoundWidget;
    if !IsDefined(panel) || !IsDefined(wrapper) {
        return;
    }
    let header: ref<inkCompoundWidget> = panel.GetWidget(n"vendorHeader") as inkCompoundWidget;
    let headerWrapper: ref<inkCompoundWidget> = panel.GetWidgetByPathName(n"vendorHeader/vendoHeaderWrapper") as inkCompoundWidget;
    let filterRow: ref<inkWidget> = panel.GetWidgetByPathName(n"vendorHeader/inkHorizontalPanelWidget2");

    let grid: ref<inkCompoundWidget> = panel.GetWidget(n"inventoryContainer") as inkCompoundWidget;
    if IsDefined(grid) {
        grid.SetMargin(new inkMargin(0.0, 8.0, 0.0, 204.0));
        grid.SetAffectsLayoutWhenHidden(false);
        // Room for the slot sidebar: the container widens and its contents move right, all but
        // the scroll bar, which is anchored to the right edge.
        let gridLeft: Float = WardrobeTabsConfig.GridLeft();
        grid.SetSize(WardrobeTabsConfig.ContainerWidth() + gridLeft, WardrobeTabsConfig.ContainerHeight());
        let child: Int32 = 0;
        while child < grid.GetNumChildren() {
            let widget: ref<inkWidget> = grid.GetWidgetByIndex(child);
            if NotEquals(widget.GetName(), n"slider") {
                let margin: inkMargin = widget.GetMargin();
                margin.left += gridLeft;
                widget.SetMargin(margin);
            }
            child += 1;
        }
        // Backdrop behind the cards. The container draws children in Backward order, so the
        // last child is drawn first.
        let backdrop: ref<inkRectangle> = this.WardrobeTabsMakeRect(new HDRColor(0.0, 0.0, 0.0, 1.0), WardrobeTabsConfig.GridBackdrop());
        backdrop.SetName(n"wardrobeGridBackdrop");
        backdrop.SetMargin(new inkMargin(gridLeft, 0.0, 0.0, 0.0));
        backdrop.Reparent(grid);
    }
    screen.m_wtGrid = grid;

    // Host for the outfit list, occupying the grid's place in the panel.
    let host: ref<inkCanvas> = new inkCanvas();
    host.SetName(n"wardrobeOutfitsHost");
    host.SetSize(WardrobeTabsConfig.ContainerWidth(), WardrobeTabsConfig.ContainerHeight());
    host.SetHAlign(inkEHorizontalAlign.Left);
    host.SetVAlign(inkEVerticalAlign.Fill);
    // Lined up with the grid; the sidebar's column stays empty in OUTFITS.
    host.SetMargin(new inkMargin(WardrobeTabsConfig.GridLeft(), 8.0, 0.0, 204.0));
    host.SetAffectsLayoutWhenHidden(false);
    host.childOrder = inkEChildOrder.Backward;
    host.Reparent(panel);
    screen.m_wtOutfitsHost = host;
    let manager: ref<inkCompoundWidget> = screen.m_outfitManager.GetRootCompoundWidget();
    if IsDefined(manager) {
        manager.Reparent(host);
        // The drawer header names the section; hide the list's own WARDROBE OUTFITS title.
        let listHeader: ref<inkWidget> = manager.GetWidget(n"header");
        if IsDefined(listHeader) {
            listHeader.SetVisible(false);
        }
        // The list was laid out for the left column; fit it above the outfit bar.
        let list: ref<inkWidget> = manager.GetWidget(n"scroll_wrapper");
        if IsDefined(list) {
            list.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));
            list.SetSize(WardrobeTabsConfig.ContainerWidth(), WardrobeTabsConfig.ContainerHeight() - WardrobeTabsConfig.BarHeight() - 30.0);
        }
    }

    let preview: ref<inkWidget> = this.GetChildWidgetByPath(n"wrapper/preview");
    if IsDefined(preview) {
        preview.SetTranslation(WardrobeTabsConfig.PreviewShift(), 0.0);
    }

    ArrayClear(screen.m_wtButtons);
    ArrayClear(screen.m_wtButtonBgs);
    ArrayClear(screen.m_wtButtonTexts);
    ArrayClear(screen.m_wtButtonCounts);
    ArrayClear(screen.m_wtButtonNews);
    this.WardrobeTabsBuildHeader(screen, header, headerWrapper);
    if IsDefined(grid) {
        this.WardrobeTabsBuildSidebar(screen, grid);
        this.WardrobeTabsBuildBar(screen, grid);
        this.WardrobeTabsBuildOutfits(screen);
        this.WardrobeTabsBuildPacks(screen, grid);
    }
    this.WardrobeTabsBuildSearchClear(screen);
    this.WardrobeTabsBuildBody(screen, wrapper);

    // Equipment-EX's own header rows (title, FILTERS, filter icons, line) collapse; the
    // drawer header above takes their place, so the grid sits right below it.
    let line: ref<inkWidget> = panel.GetWidgetByPathName(n"vendorHeader/line_vendor");
    let hidden: array<ref<inkWidget>>;
    ArrayPush(hidden, headerWrapper);
    ArrayPush(hidden, filterRow);
    ArrayPush(hidden, line);
    for widget in hidden {
        if IsDefined(widget) {
            widget.SetAffectsLayoutWhenHidden(false);
            widget.SetVisible(false);
        }
    }
    this.WardrobeTabsRefresh(screen);
    ModLog(n"WardrobeTabs", "WardrobeTabs " + WardrobeTabsConfig.Version() + " ready (" + ToString(WardrobeTabsColumns()) + " columns; hover try-on "
        + ToString(screen.m_wtSettings.hoverTryOn) + ", area camera " + ToString(screen.m_wtSettings.areaCamera) + ")");
}

// Header at the top of the item panel's header column, across sidebar and grid: title and
// subtitle with search and the item-source button on the right; area tabs and toggles.
@addMethod(inkPreviewGameController)
private func WardrobeTabsBuildHeader(screen: ref<WardrobeScreenController>, header: ref<inkCompoundWidget>, headerWrapper: ref<inkCompoundWidget>) -> Void {
    let width: Float = WardrobeTabsConfig.PanelWidth() + WardrobeTabsConfig.GridLeft();
    let overlay: ref<inkCanvas> = new inkCanvas();
    overlay.SetName(n"wardrobeDrawerHeader");
    overlay.SetSize(width, WardrobeTabsConfig.HeaderHeight());
    overlay.SetHAlign(inkEHorizontalAlign.Left);
    overlay.childOrder = inkEChildOrder.Forward;
    overlay.Reparent(header, 0);
    screen.m_wtHeader = overlay;
    let accent: ref<inkRectangle> = new inkRectangle();
    accent.SetAnchor(inkEAnchor.TopFillHorizontaly);
    accent.SetSize(width, 4.0);
    accent.SetTintColor(new HDRColor(1.176, 0.381, 0.348, 1.0));
    accent.SetInteractive(false);
    accent.Reparent(overlay);
    let title: ref<inkText> = this.WardrobeTabsMakeText(72, 0.0);
    title.SetMargin(new inkMargin(0.0, 10.0, 0.0, 0.0));
    title.SetTintColor(new HDRColor(1.0, 0.86, 0.88, 1.0));
    title.Reparent(overlay);
    screen.m_wtTitle = title;
    let subtitle: ref<inkText> = this.WardrobeTabsMakeText(28, width - 40.0);
    subtitle.SetMargin(new inkMargin(4.0, 98.0, 0.0, 0.0));
    subtitle.SetTintColor(new HDRColor(0.682, 0.231, 0.212, 1.0));
    subtitle.Reparent(overlay);
    screen.m_wtSubtitle = subtitle;

    // Equipment-EX's search box and item-source button move here; their callbacks stay
    // Equipment-EX's. The settings panel's last two children (expand / collapse all) act on
    // slot headers, which the grid no longer shows.
    if IsDefined(headerWrapper) {
        let buttons: ref<inkCompoundWidget> = headerWrapper.GetWidgetByIndex(headerWrapper.GetNumChildren() - 1) as inkCompoundWidget;
        if IsDefined(buttons) {
            buttons.Reparent(overlay);
            buttons.SetAnchor(inkEAnchor.TopRight);
            buttons.SetAnchorPoint(1.0, 0.0);
            buttons.SetMargin(new inkMargin(0.0, 18.0, 0.0, 0.0));
            if buttons.GetNumChildren() == 3 {
                buttons.GetWidgetByIndex(1).SetVisible(false);
                buttons.GetWidgetByIndex(2).SetVisible(false);
            }
            ArrayPush(screen.m_wtClothingOnly, buttons);
        }
    }
    if IsDefined(screen.m_searchInput) {
        // Equipment-EX filters on every keystroke; the watcher filters once typing pauses.
        screen.m_searchInput.UnregisterFromCallback(n"OnInput", screen, n"OnSearchFieldInput");
        screen.m_wtSearchOwned = true;
        screen.m_searchInput.Reparent(overlay);
        screen.m_searchInput.SetWidth(560.0);
        let search: ref<inkWidget> = screen.m_searchInput.GetRootWidget();
        search.SetAnchor(inkEAnchor.TopRight);
        search.SetAnchorPoint(1.0, 0.0);
        search.SetMargin(new inkMargin(0.0, 18.0, 110.0, 0.0));
        ArrayPush(screen.m_wtClothingOnly, search);
    }

    // Area tabs (0..5), then the toggles (6, 7) on the right.
    let area: Int32 = 0;
    while area <= WardrobeTabsConfig.OtherTab() {
        let tab: ref<inkCanvas> = this.WardrobeTabsMakeButton(screen, overlay, WardrobeTabsConfig.AreaLabel(area), Cast<Float>(area) * 150.0, 148.0, 140.0, 62.0);
        ArrayPush(screen.m_wtClothingOnly, tab);
        area += 1;
    }
    // Button 6 is a hidden placeholder (it was GROUP COLOURS) so the indices below stay put.
    this.WardrobeTabsMakeButton(screen, overlay, "", 0.0, 0.0, 1.0, 1.0).SetVisible(false);
    ArrayPush(screen.m_wtClothingOnly, this.WardrobeTabsMakeButton(screen, overlay, "EQUIPPED ONLY", width - 310.0, 148.0, 300.0, 62.0));
}

// PACK (button PackButton()) in the drawer header, left of EQUIPPED ONLY, and its list
// of rows, the grid container's first child so it draws over the cards and takes their
// clicks. Rows are pooled: ALL, BASE GAME, then each pack with owned items.
@addMethod(inkPreviewGameController)
private func WardrobeTabsBuildPacks(screen: ref<WardrobeScreenController>, container: ref<inkCompoundWidget>) -> Void {
    this.WardrobeTabsPacks();
    let width: Float = WardrobeTabsConfig.PanelWidth() + WardrobeTabsConfig.GridLeft();
    if IsDefined(screen.m_wtHeader) {
        let pack: ref<inkCanvas> = this.WardrobeTabsMakeButton(screen, screen.m_wtHeader, "PACK: ALL", width - 610.0, 148.0, 290.0, 62.0);
        let text: wref<inkText> = screen.m_wtButtonTexts[ArraySize(screen.m_wtButtonTexts) - 1];
        text.SetFitToContent(false);
        text.SetSize(266.0, 34.0);
        text.SetHAlign(inkEHorizontalAlign.Center);
        text.SetOverflowPolicy(textOverflowPolicy.DotsEnd);
        ArrayPush(screen.m_wtClothingOnly, pack);
    }
    let rows: Int32 = WardrobeTabsConfig.PackRows();
    let height: Float = WardrobeTabsConfig.PackRowHeight();
    let menu: ref<inkCanvas> = new inkCanvas();
    menu.SetName(n"wardrobePackList");
    menu.SetAnchor(inkEAnchor.TopRight);
    menu.SetAnchorPoint(1.0, 0.0);
    menu.SetSize(320.0, Cast<Float>(rows) * (height + 4.0) + 16.0);
    menu.SetMargin(new inkMargin(0.0, 0.0, 300.0, 0.0));
    menu.childOrder = inkEChildOrder.Forward;
    menu.SetVisible(false);
    menu.Reparent(container, 0);
    let back: ref<inkRectangle> = this.WardrobeTabsMakeRect(new HDRColor(0.03, 0.02, 0.03, 1.0), 0.94);
    back.SetName(n"wardrobePackListBack");
    back.Reparent(menu);
    screen.m_wtPackMenu = menu;
    let row: Int32 = 0;
    while row < rows {
        this.WardrobeTabsMakeButton(screen, menu, "", 10.0, 8.0 + Cast<Float>(row) * (height + 4.0), 300.0, height);
        let text: wref<inkText> = screen.m_wtButtonTexts[ArraySize(screen.m_wtButtonTexts) - 1];
        text.SetFitToContent(false);
        text.SetSize(210.0, 30.0);
        text.SetFontSize(24);
        text.SetOverflowPolicy(textOverflowPolicy.DotsEnd);
        text.SetAnchor(inkEAnchor.CenterLeft);
        text.SetAnchorPoint(0.0, 0.5);
        text.SetMargin(new inkMargin(16.0, 0.0, 0.0, 0.0));
        row += 1;
    }
    // Column buttons 4 5 6 7 (ColumnButton()), between the area tabs and PACK.
    if IsDefined(screen.m_wtHeader) {
        let columns: Int32 = WardrobeTabsConfig.MinColumns();
        while columns <= WardrobeTabsConfig.MaxColumns() {
            let x: Float = width - 610.0 - 12.0 - Cast<Float>(WardrobeTabsConfig.MaxColumns() - columns + 1) * 54.0 + 6.0;
            ArrayPush(screen.m_wtClothingOnly, this.WardrobeTabsMakeButton(screen, screen.m_wtHeader, ToString(columns), x, 148.0, 48.0, 62.0));
            columns += 1;
        }
    }
}

// An X at the right end of the search box, shown while the box holds text. Both search boxes
// sit at the same place in the header (the item search in the wardrobe, the outfit search in
// OUTFITS), so one X serves both. Added after them: the header draws its children in Forward
// order, so the X is on top and takes the click.
@addMethod(inkPreviewGameController)
private func WardrobeTabsBuildSearchClear(screen: ref<WardrobeScreenController>) -> Void {
    if !IsDefined(screen.m_wtHeader) {
        return;
    }
    let clear: ref<inkCanvas> = new inkCanvas();
    clear.SetName(n"wardrobeSearchClear");
    clear.SetAnchor(inkEAnchor.TopRight);
    clear.SetAnchorPoint(1.0, 0.0);
    clear.SetSize(56.0, 56.0);
    // Inside the box (80 high, 18 from the top, 110 from the right).
    clear.SetMargin(new inkMargin(0.0, 30.0, 124.0, 0.0));
    clear.SetInteractive(true);
    clear.SetVisible(false);
    clear.RegisterToCallback(n"OnPress", this, n"OnWardrobePress");
    clear.RegisterToCallback(n"OnRelease", this, n"OnWardrobeSearchClear");
    clear.RegisterToCallback(n"OnHoverOver", this, n"OnWardrobeSearchClearHoverOver");
    clear.RegisterToCallback(n"OnHoverOut", this, n"OnWardrobeSearchClearHoverOut");
    clear.Reparent(screen.m_wtHeader);
    let mark: ref<inkText> = this.WardrobeTabsMakeText(36, 0.0);
    mark.SetText("X");
    mark.SetAnchor(inkEAnchor.Centered);
    mark.SetAnchorPoint(0.5, 0.5);
    mark.SetTintColor(new HDRColor(0.682, 0.231, 0.212, 1.0));
    mark.SetInteractive(false);
    mark.Reparent(clear);
    screen.m_wtSearchClear = clear;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsActiveSearch(screen: ref<WardrobeScreenController>) -> ref<HubTextInput> {
    return this.WardrobeTabsView().m_wtOutfitsSection ? screen.m_wtOutfitSearch : screen.m_searchInput;
}

// Per tick: the X shows while the shown search box holds text.
@addMethod(inkPreviewGameController)
private func WardrobeTabsWatchSearchClear(screen: ref<WardrobeScreenController>) -> Void {
    if !IsDefined(screen.m_wtSearchClear) {
        return;
    }
    let search: ref<HubTextInput> = this.WardrobeTabsActiveSearch(screen);
    let shown: Bool = IsDefined(search) && StrLen(search.GetText()) > 0;
    if NotEquals(shown, screen.m_wtSearchClear.IsVisible()) {
        screen.m_wtSearchClear.SetVisible(shown);
    }
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeSearchClear(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) || !evt.IsAction(n"click") || !this.WardrobeTabsPressedHere(screen, evt) {
        return false;
    }
    let search: ref<HubTextInput> = this.WardrobeTabsActiveSearch(screen);
    if IsDefined(search) {
        this.PlaySound(n"Button", n"OnPress");
        // The watchers see the empty text and refill the grid or the outfit cells.
        search.SetText("");
        screen.m_wtSearchClear.SetVisible(false);
    }
    return true;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeSearchClearHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    let clear: ref<inkCompoundWidget> = evt.GetCurrentTarget() as inkCompoundWidget;
    if IsDefined(clear) {
        clear.GetWidgetByIndex(0).SetTintColor(new HDRColor(1.370, 0.444, 0.405, 1.0));
    }
    return false;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeSearchClearHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    let clear: ref<inkCompoundWidget> = evt.GetCurrentTarget() as inkCompoundWidget;
    if IsDefined(clear) {
        clear.GetWidgetByIndex(0).SetTintColor(new HDRColor(0.682, 0.231, 0.212, 1.0));
    }
    return false;
}

// The pack list, kept for the game session; packs are added as items are met.
@addMethod(inkPreviewGameController)
private func WardrobeTabsPacks() -> ref<WardrobeTabsPackList> {
    let view: ref<ViewManager> = this.WardrobeTabsView();
    if !IsDefined(view.m_wtPackList) {
        let list: ref<WardrobeTabsPackList> = new WardrobeTabsPackList();
        list.index = new inkHashMap();
        list.baseMark = new WardrobeTabsPack();
        list.names = new WardrobeTabsPackNames();
        view.m_wtPackList = list;
    }
    return view.m_wtPackList;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsItemPack(item: ref<InventoryGridItemData>) -> wref<WardrobeTabsPack> {
    if !item.m_wtPackReady {
        item.m_wtPack = WardrobeTabsPackOf(item.Item.GetID());
        item.m_wtPackReady = true;
    }
    return item.m_wtPack;
}

// Owned items per pack, across every slot.
@addMethod(inkPreviewGameController)
private func WardrobeTabsCountPacks(screen: ref<WardrobeScreenController>) -> Void {
    let list: ref<WardrobeTabsPackList> = this.WardrobeTabsPacks();
    for pack in list.packs {
        pack.count = 0;
    }
    list.baseCount = 0;
    for slot in screen.m_wtSlots {
        for child in slot.Children {
            let pack: wref<WardrobeTabsPack> = this.WardrobeTabsItemPack(child);
            if IsDefined(pack) {
                pack.count += 1;
            } else {
                list.baseCount += 1;
            }
        }
    }
    let summary: String = "";
    for pack in list.packs {
        if pack.count > 0 {
            summary += " " + pack.name + " (" + pack.prefix + ") " + ToString(pack.count) + ";";
        }
    }
    WardrobeTabsDebug("Packs: " + ToString(list.baseCount) + " base-game items;" + summary);
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsPackChoiceName(choice: Int32) -> String {
    let list: ref<WardrobeTabsPackList> = this.WardrobeTabsPacks();
    if choice == 1 {
        return "BASE GAME";
    }
    if choice >= 2 && choice - 2 < ArraySize(list.packs) {
        return list.packs[choice - 2].name;
    }
    return "ALL";
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsRedrawPacks(screen: ref<WardrobeScreenController>) -> Void {
    let button: Int32 = WardrobeTabsConfig.PackButton();
    let rows: Int32 = WardrobeTabsConfig.PackRows();
    if ArraySize(screen.m_wtButtons) < button + 1 + rows {
        return;
    }
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let list: ref<WardrobeTabsPackList> = this.WardrobeTabsPacks();
    screen.m_wtButtonTexts[button].SetText("PACK: " + this.WardrobeTabsPackChoiceName(view.m_wtPackChoice));
    this.WardrobeTabsStyleButton(screen, button, view.m_wtPackChoice != 0 || screen.m_wtPackOpen);
    let open: Bool = screen.m_wtPackOpen && !view.m_wtOutfitsSection;
    if IsDefined(screen.m_wtPackMenu) {
        screen.m_wtPackMenu.SetVisible(open);
    }
    ArrayClear(screen.m_wtPackRowChoice);
    let total: Int32 = list.baseCount;
    for pack in list.packs {
        total += pack.count;
    }
    ArrayPush(screen.m_wtPackRowChoice, 0);
    ArrayPush(screen.m_wtPackRowChoice, 1);
    // Packs with owned items (and the chosen one), by name.
    let index: Int32 = 0;
    while index < ArraySize(list.packs) {
        if list.packs[index].count > 0 || view.m_wtPackChoice == index + 2 {
            let at: Int32 = 2;
            while at < ArraySize(screen.m_wtPackRowChoice)
                && StrCmp(list.packs[screen.m_wtPackRowChoice[at] - 2].lower, list.packs[index].lower) <= 0 {
                at += 1;
            }
            ArrayInsert(screen.m_wtPackRowChoice, at, index + 2);
        }
        index += 1;
    }
    if ArraySize(screen.m_wtPackRowChoice) > rows {
        ArrayResize(screen.m_wtPackRowChoice, rows);
    }
    let row: Int32 = 0;
    while row < rows {
        let at: Int32 = button + 1 + row;
        let used: Bool = row < ArraySize(screen.m_wtPackRowChoice);
        screen.m_wtButtons[at].SetVisible(used);
        screen.m_wtButtonNews[at].SetVisible(false);
        if used {
            let choice: Int32 = screen.m_wtPackRowChoice[row];
            let count: Int32 = choice == 0 ? total : (choice == 1 ? list.baseCount : list.packs[choice - 2].count);
            screen.m_wtButtonTexts[at].SetText(this.WardrobeTabsPackChoiceName(choice));
            screen.m_wtButtonCounts[at].SetText(ToString(count));
            this.WardrobeTabsStyleButton(screen, at, choice == view.m_wtPackChoice);
        }
        row += 1;
    }
    if IsDefined(screen.m_wtPackMenu) {
        screen.m_wtPackMenu.SetHeight(Cast<Float>(ArraySize(screen.m_wtPackRowChoice)) * (WardrobeTabsConfig.PackRowHeight() + 4.0) + 12.0);
    }
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsPackPasses(item: ref<InventoryGridItemData>) -> Bool {
    let choice: Int32 = this.WardrobeTabsView().m_wtPackChoice;
    if choice == 0 {
        return true;
    }
    let pack: wref<WardrobeTabsPack> = this.WardrobeTabsItemPack(item);
    if choice == 1 {
        return !IsDefined(pack);
    }
    let list: ref<WardrobeTabsPackList> = this.WardrobeTabsPacks();
    return IsDefined(pack) && choice - 2 < ArraySize(list.packs) && pack == list.packs[choice - 2];
}

// Slot sidebar in the column the grid container freed on its left: one chip per slot of the
// selected area, then PREVIOUS / NEXT (buttons 8, 9) when the area has more than a page.
// It is the container's child, so it hides with the grid in OUTFITS.
@addMethod(inkPreviewGameController)
private func WardrobeTabsBuildSidebar(screen: ref<WardrobeScreenController>, container: ref<inkCompoundWidget>) -> Void {
    let width: Float = WardrobeTabsConfig.SidebarWidth();
    let height: Float = WardrobeTabsConfig.ChipHeight();
    let step: Float = height + WardrobeTabsConfig.ChipGap();
    let chips: Int32 = WardrobeTabsConfig.ChipsPerPage();
    let paging: Float = Cast<Float>(chips) * step;
    let sidebar: ref<inkCanvas> = new inkCanvas();
    sidebar.SetName(n"wardrobeSlotSidebar");
    sidebar.SetAnchor(inkEAnchor.TopLeft);
    sidebar.SetSize(width, paging + height);
    sidebar.childOrder = inkEChildOrder.Forward;
    sidebar.Reparent(container, 0);
    let half: Float = (width - WardrobeTabsConfig.ChipGap()) / 2.0;
    this.WardrobeTabsMakeButton(screen, sidebar, "PREVIOUS", 0.0, paging, half, height);
    this.WardrobeTabsMakeButton(screen, sidebar, "NEXT", width - half, paging, half, height);
    let chip: Int32 = 0;
    while chip < chips {
        this.WardrobeTabsMakeButton(screen, sidebar, "", 0.0, Cast<Float>(chip) * step, width, height);
        let text: wref<inkText> = screen.m_wtButtonTexts[ArraySize(screen.m_wtButtonTexts) - 1];
        text.SetFitToContent(false);
        text.SetSize(width - 76.0, 34.0);
        text.SetOverflowPolicy(textOverflowPolicy.DotsEnd);
        text.SetFontSize(26);
        text.SetAnchor(inkEAnchor.CenterLeft);
        text.SetAnchorPoint(0.0, 0.5);
        text.SetMargin(new inkMargin(18.0, 0.0, 0.0, 0.0));
        chip += 1;
    }
}

// Outfit bar along the bottom of the drawer, over the grid's bottom edge. It is the grid
// container's first child (drawn last, given Backward order); in OUTFITS it moves to the
// outfit list's host.
@addMethod(inkPreviewGameController)
private func WardrobeTabsBuildBar(screen: ref<WardrobeScreenController>, container: ref<inkCompoundWidget>) -> Void {
    let width: Float = WardrobeTabsConfig.ContainerWidth();
    let height: Float = WardrobeTabsConfig.BarHeight();
    let bar: ref<inkCanvas> = new inkCanvas();
    bar.SetName(n"wardrobeOutfitBar");
    bar.SetAnchor(inkEAnchor.BottomFillHorizontaly);
    bar.SetAnchorPoint(0.0, 1.0);
    bar.SetSize(width, height);
    bar.SetMargin(new inkMargin(WardrobeTabsConfig.GridLeft(), 0.0, 0.0, 0.0));
    bar.childOrder = inkEChildOrder.Forward;
    bar.Reparent(container, 0);
    screen.m_wtBar = bar;
    let back: ref<inkRectangle> = this.WardrobeTabsMakeRect(new HDRColor(0.045, 0.012, 0.025, 1.0), 0.96);
    back.SetInteractive(true);
    back.Reparent(bar);
    let line: ref<inkRectangle> = new inkRectangle();
    line.SetAnchor(inkEAnchor.TopFillHorizontaly);
    line.SetSize(width, 2.0);
    line.SetTintColor(new HDRColor(0.486, 0.129, 0.204, 1.0));
    line.SetInteractive(false);
    line.Reparent(bar);
    let heading: ref<inkText> = this.WardrobeTabsMakeText(34, 0.0);
    heading.SetText("CURRENT LOOK");
    heading.SetMargin(new inkMargin(24.0, 18.0, 0.0, 0.0));
    heading.SetTintColor(new HDRColor(1.0, 0.86, 0.88, 1.0));
    heading.Reparent(bar);
    let look: ref<inkText> = this.WardrobeTabsMakeText(26, 590.0);
    look.SetMargin(new inkMargin(24.0, 66.0, 0.0, 0.0));
    look.SetTintColor(new HDRColor(0.682, 0.231, 0.212, 1.0));
    look.Reparent(bar);
    screen.m_wtLook = look;
    // OUTFITS, which reads BACK in the outfits view; saving is done there (SAVE OUTFIT).
    this.WardrobeTabsMakeButton(screen, bar, "OUTFITS", width - 24.0 - 260.0, 22.0, 260.0, 76.0);
    // Shown while the look is an edited outfit: save over it, or wear it as saved.
    this.WardrobeTabsMakeButton(screen, bar, "UPDATE", width - 24.0 - 260.0 - 16.0 - 200.0, 22.0, 200.0, 76.0);
    this.WardrobeTabsMakeButton(screen, bar, "REVERT", width - 24.0 - 260.0 - 32.0 - 400.0, 22.0, 200.0, 76.0);
}

// Outfits view: SAVE OUTFIT and NO OUTFIT in the header row the area tabs use, its own search
// box where the item search sits, and a grid of outfit cells in Equipment-EX's outfit scroll
// area in place of its one-column list. The list stays, hidden; its popups are still used.
@addMethod(inkPreviewGameController)
private func WardrobeTabsBuildOutfits(screen: ref<WardrobeScreenController>) -> Void {
    ArrayClear(screen.m_wtOutfitsOnly);
    let overlay: ref<inkCompoundWidget> = screen.m_wtHeader;
    if IsDefined(overlay) {
        ArrayPush(screen.m_wtOutfitsOnly, this.WardrobeTabsMakeButton(screen, overlay, "SAVE OUTFIT", 0.0, 148.0, 300.0, 62.0));
        ArrayPush(screen.m_wtOutfitsOnly, this.WardrobeTabsMakeButton(screen, overlay, "NO OUTFIT", 310.0, 148.0, 300.0, 62.0));
        let search: ref<HubTextInput> = HubTextInput.Create();
        search.SetName(n"wardrobeOutfitSearch");
        search.SetDefaultText(GetLocalizedTextByKey(n"UI-Wardrobe-SearchByName"));
        search.SetLetterCase(textLetterCase.UpperCase);
        search.SetMaxLength(24);
        search.Reparent(overlay);
        search.SetWidth(560.0);
        let root: ref<inkWidget> = search.GetRootWidget();
        root.SetAnchor(inkEAnchor.TopRight);
        root.SetAnchorPoint(1.0, 0.0);
        root.SetMargin(new inkMargin(0.0, 18.0, 110.0, 0.0));
        ArrayPush(screen.m_wtOutfitsOnly, root);
        screen.m_wtOutfitSearch = search;
    }

    // Equipment-EX's list goes; the cells get a scroll area of their own in the manager (so its
    // hover tracking still sees the cursor). A cell canvas added beside the list in Equipment-EX's
    // scroll area never showed: scroll areas have one content child.
    let manager: ref<inkCompoundWidget> = screen.m_outfitManager.GetRootCompoundWidget();
    if !IsDefined(manager) {
        return;
    }
    let wrapper: ref<inkWidget> = manager.GetWidget(n"scroll_wrapper");
    if IsDefined(wrapper) {
        wrapper.SetAffectsLayoutWhenHidden(false);
        wrapper.SetVisible(false);
    }
    let height: Float = WardrobeTabsConfig.OutfitViewHeight();
    let viewport: ref<inkScrollArea> = new inkScrollArea();
    viewport.SetName(n"wardrobeOutfitViewport");
    viewport.SetAnchor(inkEAnchor.TopLeft);
    viewport.SetSize(WardrobeTabsConfig.ContainerWidth(), height);
    viewport.SetRenderTransformPivot(new Vector2(0.0, 0.0));
    viewport.SetConstrainContentPosition(true);
    viewport.SetUseInternalMask(true);
    viewport.SetInteractive(true);
    viewport.RegisterToCallback(n"OnRelative", this, n"OnWardrobeOutfitWheel");
    viewport.Reparent(manager, 0);
    // The only child of the scroll area, moved by WardrobeTabsScrollOutfits.
    let content: ref<inkCanvas> = new inkCanvas();
    content.SetName(n"wardrobeOutfitGrid");
    content.SetAnchor(inkEAnchor.TopLeft);
    content.SetRenderTransformPivot(new Vector2(0.0, 0.0));
    content.childOrder = inkEChildOrder.Forward;
    content.Reparent(viewport);
    screen.m_wtOutfitContent = content;
    // Scroll bar on the right, shown when the outfits overflow.
    let track: ref<inkRectangle> = new inkRectangle();
    track.SetAnchor(inkEAnchor.TopLeft);
    track.SetSize(6.0, height);
    track.SetMargin(new inkMargin(WardrobeTabsConfig.OutfitBarLeft(), 0.0, 0.0, 0.0));
    track.SetTintColor(new HDRColor(0.486, 0.129, 0.204, 1.0));
    track.SetOpacity(0.5);
    track.SetInteractive(false);
    track.Reparent(manager, 0);
    screen.m_wtOutfitTrack = track;
    let thumb: ref<inkRectangle> = new inkRectangle();
    thumb.SetAnchor(inkEAnchor.TopLeft);
    thumb.SetSize(6.0, height);
    thumb.SetMargin(new inkMargin(WardrobeTabsConfig.OutfitBarLeft(), 0.0, 0.0, 0.0));
    thumb.SetTintColor(new HDRColor(1.176, 0.381, 0.348, 1.0));
    thumb.SetInteractive(false);
    thumb.Reparent(manager, 0);
    screen.m_wtOutfitThumb = thumb;
    let empty: ref<inkText> = this.WardrobeTabsMakeText(30, 0.0);
    empty.SetMargin(new inkMargin(8.0, 12.0, 0.0, 0.0));
    empty.SetTintColor(new HDRColor(0.682, 0.231, 0.212, 1.0));
    empty.Reparent(content);
    screen.m_wtOutfitEmpty = empty;
}

// One outfit cell: name, item count, a bar while worn, the favourite star top right and a
// row of item icons.
@addMethod(inkPreviewGameController)
private func WardrobeTabsMakeOutfitCell(screen: ref<WardrobeScreenController>) -> Void {
    let width: Float = WardrobeTabsConfig.OutfitCellWidth();
    let height: Float = WardrobeTabsConfig.OutfitCellHeight();
    let cell: ref<inkCanvas> = new inkCanvas();
    cell.SetAnchor(inkEAnchor.TopLeft);
    cell.SetSize(width, height);
    cell.childOrder = inkEChildOrder.Forward;
    cell.SetInteractive(true);
    cell.RegisterToCallback(n"OnRelease", this, n"OnWardrobeOutfitClick");
    cell.RegisterToCallback(n"OnPress", this, n"OnWardrobePress");
    cell.RegisterToCallback(n"OnHoverOver", this, n"OnWardrobeOutfitHoverOver");
    cell.RegisterToCallback(n"OnHoverOut", this, n"OnWardrobeOutfitHoverOut");
    cell.Reparent(screen.m_wtOutfitContent);
    let bg: ref<inkRectangle> = this.WardrobeTabsMakeRect(new HDRColor(0.15, 0.035, 0.08, 1.0), 0.9);
    bg.Reparent(cell);
    let bar: ref<inkRectangle> = new inkRectangle();
    bar.SetAnchor(inkEAnchor.BottomFillHorizontaly);
    bar.SetSize(width, 5.0);
    bar.SetTintColor(new HDRColor(0.369, 0.965, 1.0, 1.0));
    bar.SetInteractive(false);
    bar.Reparent(cell);
    let name: ref<inkText> = this.WardrobeTabsMakeText(36, width - 110.0);
    name.SetMargin(new inkMargin(24.0, 14.0, 0.0, 0.0));
    name.Reparent(cell);
    let info: ref<inkText> = this.WardrobeTabsMakeText(24, width - 110.0);
    info.SetMargin(new inkMargin(24.0, 64.0, 0.0, 0.0));
    info.Reparent(cell);
    let star: ref<inkCanvas> = new inkCanvas();
    star.SetAnchor(inkEAnchor.TopRight);
    star.SetAnchorPoint(1.0, 0.0);
    star.SetSize(72.0, 72.0);
    star.SetMargin(new inkMargin(0.0, 14.0, 14.0, 0.0));
    star.SetInteractive(true);
    star.RegisterToCallback(n"OnRelease", this, n"OnWardrobeStarClick");
    star.RegisterToCallback(n"OnPress", this, n"OnWardrobePress");
    star.RegisterToCallback(n"OnHoverOver", this, n"OnWardrobeStarHoverOver");
    star.RegisterToCallback(n"OnHoverOut", this, n"OnWardrobeStarHoverOut");
    star.Reparent(cell);
    // The ripperdoc's favourite star.
    let icon: ref<inkImage> = new inkImage();
    icon.SetAtlasResource(r"base\\gameplay\\gui\\fullscreen\\ripperdoc\\assets\\cw_bars_assets.inkatlas");
    icon.SetTexturePart(n"fav_star");
    icon.SetAnchor(inkEAnchor.Centered);
    icon.SetAnchorPoint(0.5, 0.5);
    icon.SetFitToContent(false);
    icon.SetSize(44.0, 44.0);
    icon.SetInteractive(false);
    icon.Reparent(star);
    let size: Float = WardrobeTabsConfig.OutfitIconSize();
    let slot: Int32 = 0;
    while slot < WardrobeTabsConfig.OutfitIcons() {
        let holder: ref<inkCanvas> = new inkCanvas();
        holder.SetAnchor(inkEAnchor.TopLeft);
        holder.SetSize(size, size);
        holder.SetMargin(new inkMargin(24.0 + Cast<Float>(slot) * (size + WardrobeTabsConfig.OutfitIconGap()), WardrobeTabsConfig.OutfitIconTop(), 0.0, 0.0));
        holder.SetInteractive(false);
        holder.Reparent(cell);
        let back: ref<inkRectangle> = this.WardrobeTabsMakeRect(new HDRColor(0.045, 0.012, 0.025, 1.0), 0.7);
        back.SetInteractive(false);
        back.Reparent(holder);
        let image: ref<inkImage> = new inkImage();
        image.SetAnchor(inkEAnchor.Centered);
        image.SetAnchorPoint(0.5, 0.5);
        image.SetFitToContent(true);
        image.SetScale(new Vector2(size / 200.0, size / 200.0));
        image.SetInteractive(false);
        image.Reparent(holder);
        ArrayPush(screen.m_wtOutfitIconSlots, holder);
        ArrayPush(screen.m_wtOutfitIcons, image);
        ArrayPush(screen.m_wtOutfitIconPaths, "");
        if slot == WardrobeTabsConfig.OutfitIcons() - 1 {
            let more: ref<inkText> = this.WardrobeTabsMakeText(24, 0.0);
            more.SetAnchor(inkEAnchor.Centered);
            more.SetAnchorPoint(0.5, 0.5);
            more.SetTintColor(new HDRColor(1.176, 0.381, 0.348, 1.0));
            more.Reparent(holder);
            ArrayPush(screen.m_wtOutfitMores, more);
        }
        slot += 1;
    }
    ArrayPush(screen.m_wtOutfitCells, cell);
    ArrayPush(screen.m_wtOutfitCellBgs, bg);
    ArrayPush(screen.m_wtOutfitCellBars, bar);
    ArrayPush(screen.m_wtOutfitCellNames, name);
    ArrayPush(screen.m_wtOutfitCellInfos, info);
    ArrayPush(screen.m_wtOutfitStars, star);
    ArrayPush(screen.m_wtOutfitStarIcons, icon);
}

// A cell's icon row: the outfit's items in Equipment-EX's slot order (head to toe), the last
// slot reading +N when they do not all fit.
@addMethod(inkPreviewGameController)
private func WardrobeTabsFillOutfitIcons(screen: ref<WardrobeScreenController>, cell: Int32, parts: array<ref<OutfitPart>>) -> Void {
    let slots: array<TweakDBID> = screen.m_outfitSystem.GetOutfitSlots();
    let keys: array<Int32>;
    let paths: array<String>;
    for part in parts {
        let key: Int32 = ArrayFindFirst(slots, part.GetSlotID());
        if key < 0 {
            key = ArraySize(slots);
        }
        let recordID: TweakDBID = ItemID.GetTDBID(part.GetItemID());
        let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(recordID);
        let path: String = IsDefined(record) ? UIInventoryItemsManager.ResolveItemIconName(recordID, record, false) : "";
        let at: Int32 = 0;
        while at < ArraySize(keys) && keys[at] <= key {
            at += 1;
        }
        ArrayInsert(keys, at, key);
        ArrayInsert(paths, at, path);
    }
    let icons: Int32 = WardrobeTabsConfig.OutfitIcons();
    let count: Int32 = ArraySize(paths);
    let shown: Int32 = count > icons ? icons - 1 : count;
    let slot: Int32 = 0;
    while slot < icons {
        let at: Int32 = cell * icons + slot;
        let more: Bool = count > icons && slot == icons - 1;
        screen.m_wtOutfitIconSlots[at].SetVisible(slot < shown || more);
        let path: String = slot < shown ? paths[slot] : "";
        if NotEquals(screen.m_wtOutfitIconPaths[at], path) {
            screen.m_wtOutfitIconPaths[at] = path;
            screen.m_wtOutfitIcons[at].SetVisible(NotEquals(path, ""));
            if NotEquals(path, "") {
                InkImageUtils.RequestSetImage(this, screen.m_wtOutfitIcons[at], path);
            }
        }
        slot += 1;
    }
    screen.m_wtOutfitMores[cell].SetVisible(count > icons);
    screen.m_wtOutfitMores[cell].SetText("+" + ToString(count - shown));
}

// Fills the outfit cells: favourites first, then the rest, each in Equipment-EX's
// alphabetical order, narrowed by the search.
@addMethod(inkPreviewGameController)
private func WardrobeTabsShowOutfits(screen: ref<WardrobeScreenController>) -> Void {
    if !IsDefined(screen.m_wtOutfitContent) {
        return;
    }
    let all: array<CName> = screen.m_outfitSystem.GetOutfits();
    let favourites: array<CName>;
    let others: array<CName>;
    for name in all {
        if StrLen(screen.m_wtOutfitQuery) == 0 || StrContains(UTF8StrLower(NameToString(name)), screen.m_wtOutfitQuery) {
            if ArrayContains(screen.m_outfitSystem.m_wtFavourites, name) {
                ArrayPush(favourites, name);
            } else {
                ArrayPush(others, name);
            }
        }
    }
    ArrayClear(screen.m_wtOutfitNames);
    ArrayClear(screen.m_wtOutfitParts);
    for name in favourites {
        ArrayPush(screen.m_wtOutfitNames, name);
    }
    for name in others {
        ArrayPush(screen.m_wtOutfitNames, name);
    }
    let count: Int32 = ArraySize(screen.m_wtOutfitNames);
    while ArraySize(screen.m_wtOutfitCells) < count {
        this.WardrobeTabsMakeOutfitCell(screen);
    }
    let columns: Int32 = WardrobeTabsConfig.OutfitColumns();
    let stepX: Float = WardrobeTabsConfig.OutfitCellWidth() + WardrobeTabsConfig.OutfitGap();
    let stepY: Float = WardrobeTabsConfig.OutfitCellHeight() + WardrobeTabsConfig.OutfitGap();
    let index: Int32 = 0;
    while index < ArraySize(screen.m_wtOutfitCells) {
        let cell: wref<inkCanvas> = screen.m_wtOutfitCells[index];
        cell.SetVisible(index < count);
        if index < count {
            let name: CName = screen.m_wtOutfitNames[index];
            cell.SetMargin(new inkMargin(Cast<Float>(index % columns) * stepX, Cast<Float>(index / columns) * stepY, 0.0, 0.0));
            screen.m_wtOutfitCellNames[index].SetText(NameToString(name));
            let parts: array<ref<OutfitPart>> = screen.m_outfitSystem.GetOutfitParts(name);
            ArrayPush(screen.m_wtOutfitParts, ArraySize(parts));
            this.WardrobeTabsFillOutfitIcons(screen, index, parts);
        }
        index += 1;
    }
    let rows: Int32 = (count + columns - 1) / columns;
    let height: Float = MaxF(Cast<Float>(rows) * stepY, 60.0);
    screen.m_wtOutfitContent.SetSize(Cast<Float>(columns) * stepX, height);
    screen.m_wtOutfitEmpty.SetVisible(count == 0);
    screen.m_wtOutfitEmpty.SetText(ArraySize(all) == 0 ? "NO SAVED OUTFITS YET: SAVE OUTFIT KEEPS WHAT V IS WEARING"
        : "NO OUTFIT MATCHES \"" + screen.m_wtOutfitQuery + "\"");
    screen.m_wtOutfitScrollMax = MaxF(height - WardrobeTabsConfig.OutfitViewHeight(), 0.0);
    this.WardrobeTabsScrollOutfits(screen, screen.m_wtOutfitScroll);
    WardrobeTabsDebug("Outfits view: " + ToString(count) + " of " + ToString(ArraySize(all)) + " outfits in "
        + ToString(rows) + " rows, " + ToString(ArraySize(screen.m_wtOutfitCells)) + " cells, content height " + FloatToString(height));
}

// Moves the outfit grid inside its scroll area and the scroll bar's thumb with it.
@addMethod(inkPreviewGameController)
private func WardrobeTabsScrollOutfits(screen: ref<WardrobeScreenController>, offset: Float) -> Void {
    let max: Float = screen.m_wtOutfitScrollMax;
    screen.m_wtOutfitScroll = MinF(MaxF(offset, 0.0), max);
    screen.m_wtOutfitContent.SetTranslation(0.0, -screen.m_wtOutfitScroll);
    let view: Float = WardrobeTabsConfig.OutfitViewHeight();
    screen.m_wtOutfitTrack.SetVisible(max > 0.0);
    screen.m_wtOutfitThumb.SetVisible(max > 0.0);
    if max > 0.0 {
        let thumb: Float = MaxF(view * view / (view + max), 60.0);
        screen.m_wtOutfitThumb.SetHeight(thumb);
        screen.m_wtOutfitThumb.SetMargin(new inkMargin(WardrobeTabsConfig.OutfitBarLeft(), (view - thumb) * screen.m_wtOutfitScroll / max, 0.0, 0.0));
    }
}

// Mouse wheel over the outfit grid, as Equipment-EX reads it for the preview's zoom.
@addMethod(inkPreviewGameController)
protected cb func OnWardrobeOutfitWheel(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) || !evt.IsAction(n"mouse_wheel") || evt.GetAxisData() == 0.0 {
        return false;
    }
    let step: Float = WardrobeTabsConfig.OutfitWheelStep();
    this.WardrobeTabsScrollOutfits(screen, screen.m_wtOutfitScroll + (evt.GetAxisData() > 0.0 ? -step : step));
    return true;
}

// Hover, worn and favourite states of the filled cells.
@addMethod(inkPreviewGameController)
private func WardrobeTabsStyleOutfits(screen: ref<WardrobeScreenController>) -> Void {
    let count: Int32 = Min(ArraySize(screen.m_wtOutfitNames), ArraySize(screen.m_wtOutfitCells));
    let index: Int32 = 0;
    while index < count {
        let name: CName = screen.m_wtOutfitNames[index];
        let worn: Bool = screen.m_outfitSystem.IsEquipped(name);
        // The linked outfit after an edit: EDITED where WEARING would be, its bar dimmed.
        let edited: Bool = screen.m_wtLinkChanges >= 0 && Equals(name, screen.m_outfitSystem.m_wtLinked);
        let favourite: Bool = ArrayContains(screen.m_outfitSystem.m_wtFavourites, name);
        let hovered: Bool = screen.m_wtHover == screen.m_wtOutfitCells[index];
        screen.m_wtOutfitCellBgs[index].SetTintColor(hovered ? new HDRColor(0.30, 0.06, 0.08, 1.0) : new HDRColor(0.15, 0.035, 0.08, 1.0));
        screen.m_wtOutfitCellBars[index].SetVisible(worn || edited);
        screen.m_wtOutfitCellBars[index].SetOpacity(worn ? 1.0 : 0.4);
        screen.m_wtOutfitCellNames[index].SetTintColor(worn ? new HDRColor(0.369, 0.965, 1.0, 1.0)
            : (hovered ? new HDRColor(1.370, 0.444, 0.405, 1.0) : new HDRColor(1.176, 0.381, 0.348, 1.0)));
        let parts: Int32 = screen.m_wtOutfitParts[index];
        screen.m_wtOutfitCellInfos[index].SetText(ToString(parts) + (parts == 1 ? " ITEM" : " ITEMS") + (worn ? "  |  WEARING" : (edited ? "  |  EDITED" : "")));
        screen.m_wtOutfitCellInfos[index].SetTintColor(worn ? new HDRColor(0.204, 0.569, 0.592, 1.0) : new HDRColor(0.682, 0.231, 0.212, 1.0));
        let starHovered: Bool = screen.m_wtStarHover == screen.m_wtOutfitStars[index];
        screen.m_wtOutfitStarIcons[index].SetTintColor(favourite ? new HDRColor(0.98, 0.84, 0.36, 1.0)
            : (starHovered ? new HDRColor(1.370, 0.444, 0.405, 1.0) : new HDRColor(0.682, 0.231, 0.212, 1.0)));
        screen.m_wtOutfitStarIcons[index].SetOpacity(favourite || starHovered ? 1.0 : 0.45);
        index += 1;
    }
}

// Polled in the outfits view: refills the cells when the search text or the saved outfits
// change (Equipment-EX's save and delete popups), restyles them when the worn outfit changes.
// A newly saved outfit the search would hide clears the search, so its cell shows.
@addMethod(inkPreviewGameController)
private func WardrobeTabsWatchOutfits(screen: ref<WardrobeScreenController>) -> Void {
    let typed: String = IsDefined(screen.m_wtOutfitSearch) ? UTF8StrLower(screen.m_wtOutfitSearch.GetText()) : "";
    let outfits: array<CName> = screen.m_outfitSystem.GetOutfits();
    // Not on the view's first fill, where every name is unknown.
    if StrLen(typed) > 0 && StrLen(screen.m_wtOutfitSig) > 0 {
        for name in outfits {
            if !ArrayContains(screen.m_wtOutfitKnown, name) && !StrContains(UTF8StrLower(NameToString(name)), typed) {
                screen.m_wtOutfitSearch.SetText("");
                typed = "";
                break;
            }
        }
    }
    screen.m_wtOutfitKnown = outfits;
    let sig: String = typed + "|";
    let worn: String = screen.m_outfitSystem.IsActive() ? "+" : "-";
    for name in outfits {
        sig += NameToString(name) + ";";
        if screen.m_outfitSystem.IsEquipped(name) {
            worn += NameToString(name);
        }
    }
    if NotEquals(sig, screen.m_wtOutfitSig) || NotEquals(worn, screen.m_wtOutfitWorn) {
        // Overwriting an outfit changes its items and wears it, so a new worn outfit refills too.
        screen.m_wtOutfitSig = sig;
        screen.m_wtOutfitWorn = worn;
        if NotEquals(typed, screen.m_wtOutfitQuery) {
            screen.m_wtOutfitScroll = 0.0;
        }
        screen.m_wtOutfitQuery = typed;
        this.WardrobeTabsShowOutfits(screen);
        this.WardrobeTabsRedraw(screen);
    }
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsOutfitIndex(screen: ref<WardrobeScreenController>, target: wref<inkWidget>) -> Int32 {
    let index: Int32 = 0;
    while index < ArraySize(screen.m_wtOutfitNames) && index < ArraySize(screen.m_wtOutfitCells) {
        if screen.m_wtOutfitCells[index] == target || screen.m_wtOutfitStars[index] == target {
            return index;
        }
        index += 1;
    }
    return -1;
}

// As Equipment-EX's outfit list does: no outfit changes while its system is blocked.
@addMethod(inkPreviewGameController)
private func WardrobeTabsOutfitAccess(screen: ref<WardrobeScreenController>) -> Bool {
    if screen.m_outfitSystem.IsBlocked() {
        let notification: ref<UIMenuNotificationEvent> = new UIMenuNotificationEvent();
        notification.m_notificationType = UIMenuNotificationType.InventoryActionBlocked;
        this.QueueEvent(notification);
        return false;
    }
    return true;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsBuildBody(screen: ref<WardrobeScreenController>, wrapper: ref<inkCompoundWidget>) -> Void {
    let width: Float = WardrobeTabsConfig.BodyWidth();
    let body: ref<inkCanvas> = new inkCanvas();
    body.SetName(n"wardrobeBodyColumn");
    body.SetAnchor(inkEAnchor.TopLeft);
    body.SetSize(width, 60.0 + WardrobeTabsConfig.GroupsHeight());
    body.SetMargin(new inkMargin(WardrobeTabsConfig.BodyLeft(), WardrobeTabsConfig.BodyTop(), 0.0, 0.0));
    body.childOrder = inkEChildOrder.Forward;
    body.Reparent(wrapper, 0);

    let label: ref<inkText> = this.WardrobeTabsMakeText(32, 0.0);
    label.SetText("WEARING");
    label.SetTintColor(new HDRColor(0.682, 0.231, 0.212, 1.0));
    label.Reparent(body);
    // Guide line beside the groups, as on the inventory's clothing column.
    let guide: ref<inkRectangle> = new inkRectangle();
    guide.SetAnchor(inkEAnchor.TopLeft);
    guide.SetSize(3.0, WardrobeTabsConfig.GroupsHeight());
    guide.SetMargin(new inkMargin(-30.0, 60.0, 0.0, 0.0));
    guide.SetTintColor(new HDRColor(0.486, 0.129, 0.204, 1.0));
    guide.SetOpacity(0.6);
    guide.SetInteractive(false);
    guide.Reparent(body);

    ArrayClear(screen.m_wtGroupHeads);
    ArrayClear(screen.m_wtGroupLabels);
    ArrayClear(screen.m_wtGroupCounts);
    ArrayClear(screen.m_wtGroupDetails);
    ArrayClear(screen.m_wtTiles);
    ArrayClear(screen.m_wtTileBgs);
    ArrayClear(screen.m_wtTileBars);
    ArrayClear(screen.m_wtTileIcons);
    ArrayClear(screen.m_wtTileIconPaths);
    ArrayClear(screen.m_wtTilePlus);
    ArrayClear(screen.m_wtTileSlots);
    let group: Int32 = 0;
    while group <= WardrobeTabsConfig.OtherTab() {
        let head: ref<inkCanvas> = new inkCanvas();
        head.SetAnchor(inkEAnchor.TopLeft);
        head.SetSize(width, WardrobeTabsConfig.GroupHeader() - 8.0);
        head.childOrder = inkEChildOrder.Forward;
        head.SetInteractive(true);
        head.RegisterToCallback(n"OnRelease", this, n"OnWardrobeGroupClick");
        head.RegisterToCallback(n"OnPress", this, n"OnWardrobePress");
        head.RegisterToCallback(n"OnHoverOver", this, n"OnWardrobeTabsHoverOver");
        head.RegisterToCallback(n"OnHoverOut", this, n"OnWardrobeTabsHoverOut");
        head.Reparent(body);
        let name: ref<inkText> = this.WardrobeTabsMakeText(42, 0.0);
        name.SetText(WardrobeTabsConfig.AreaLabel(group));
        name.Reparent(head);
        let count: ref<inkText> = this.WardrobeTabsMakeText(26, 0.0);
        count.SetAnchor(inkEAnchor.TopRight);
        count.SetAnchorPoint(1.0, 0.0);
        count.SetMargin(new inkMargin(0.0, 14.0, 0.0, 0.0));
        count.Reparent(head);
        let detail: ref<inkText> = this.WardrobeTabsMakeText(25, width);
        detail.SetMargin(new inkMargin(0.0, 52.0, 0.0, 0.0));
        detail.Reparent(head);
        ArrayPush(screen.m_wtGroupHeads, head);
        ArrayPush(screen.m_wtGroupLabels, name);
        ArrayPush(screen.m_wtGroupCounts, count);
        ArrayPush(screen.m_wtGroupDetails, detail);
        let index: Int32 = 0;
        while index < WardrobeTabsConfig.GroupTiles() {
            let tile: ref<inkCanvas> = new inkCanvas();
            tile.SetAnchor(inkEAnchor.TopLeft);
            tile.childOrder = inkEChildOrder.Forward;
            tile.SetInteractive(true);
            tile.RegisterToCallback(n"OnRelease", this, n"OnWardrobeTileClick");
            tile.RegisterToCallback(n"OnPress", this, n"OnWardrobePress");
            tile.RegisterToCallback(n"OnHoverOver", this, n"OnWardrobeTabsHoverOver");
            tile.RegisterToCallback(n"OnHoverOut", this, n"OnWardrobeTabsHoverOut");
            tile.Reparent(body);
            let bg: ref<inkRectangle> = this.WardrobeTabsMakeRect(new HDRColor(0.15, 0.035, 0.08, 1.0), 0.9);
            bg.Reparent(tile);
            let bar: ref<inkRectangle> = new inkRectangle();
            bar.SetAnchor(inkEAnchor.BottomFillHorizontaly);
            bar.SetSize(100.0, 5.0);
            bar.SetTintColor(new HDRColor(0.369, 0.965, 1.0, 1.0));
            bar.SetInteractive(false);
            bar.Reparent(tile);
            let icon: ref<inkImage> = new inkImage();
            icon.SetAnchor(inkEAnchor.Centered);
            icon.SetAnchorPoint(0.5, 0.5);
            icon.SetFitToContent(true);
            icon.SetInteractive(false);
            icon.Reparent(tile);
            let plus: ref<inkText> = this.WardrobeTabsMakeText(64, 0.0);
            plus.SetText("+");
            plus.SetAnchor(inkEAnchor.Centered);
            plus.SetAnchorPoint(0.5, 0.5);
            plus.Reparent(tile);
            ArrayPush(screen.m_wtTiles, tile);
            ArrayPush(screen.m_wtTileBgs, bg);
            ArrayPush(screen.m_wtTileBars, bar);
            ArrayPush(screen.m_wtTileIcons, icon);
            ArrayPush(screen.m_wtTileIconPaths, "");
            ArrayPush(screen.m_wtTilePlus, plus);
            ArrayPush(screen.m_wtTileSlots, -1);
            index += 1;
        }
        group += 1;
    }
}

// Equipment-EX rebuilds the grid's data source at times no vanilla method observes,
// so a looping animation polls for a rebuilt source and other changes.
@addMethod(inkPreviewGameController)
private func WardrobeTabsStartWatcher(screen: ref<WardrobeScreenController>) -> Void {
    let interpolator: ref<inkAnimTransparency> = new inkAnimTransparency();
    interpolator.SetDuration(0.05);
    interpolator.SetStartTransparency(1.0);
    interpolator.SetEndTransparency(1.0);
    let definition: ref<inkAnimDef> = new inkAnimDef();
    definition.AddInterpolator(interpolator);
    let options: inkAnimOptions;
    options.loopType = inkanimLoopType.Cycle;
    options.loopInfinite = true;
    screen.m_wtWatcher = this.GetRootWidget().PlayAnimationWithOptions(definition, options);
    screen.m_wtWatcher.RegisterToCallback(inkanimEventType.OnEndLoop, this, n"OnWardrobeTabsWatch");
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsView() -> ref<ViewManager> {
    return ViewManager.GetInstance(this.GetPlayerControlledObject().GetGame());
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsRefresh(screen: ref<WardrobeScreenController>) -> Void {
    let clothing: Bool = !this.WardrobeTabsView().m_wtOutfitsSection;
    for widget in screen.m_wtClothingOnly {
        if IsDefined(widget) {
            widget.SetVisible(clothing);
        }
    }
    for widget in screen.m_wtOutfitsOnly {
        if IsDefined(widget) {
            widget.SetVisible(!clothing);
        }
    }
    if !clothing {
        // Filled now rather than on the next tick.
        screen.m_wtOutfitSig = "";
        this.WardrobeTabsWatchOutfits(screen);
    }
    if IsDefined(screen.m_wtGrid) {
        screen.m_wtGrid.SetVisible(clothing);
    }
    if IsDefined(screen.m_wtOutfitsHost) {
        screen.m_wtOutfitsHost.SetVisible(!clothing);
    }
    if IsDefined(screen.m_wtBar) {
        let target: ref<inkCompoundWidget> = (clothing ? screen.m_wtGrid : screen.m_wtOutfitsHost) as inkCompoundWidget;
        if IsDefined(target) && screen.m_wtBar.GetParentWidget() != target {
            screen.m_wtBar.Reparent(target, 0);
            // The grid container starts with the sidebar's column; the host is already past it.
            screen.m_wtBar.SetMargin(new inkMargin(clothing ? WardrobeTabsConfig.GridLeft() : 0.0, 0.0, 0.0, 0.0));
        }
    }
    this.WardrobeTabsRedraw(screen);
}

// Once per opening: every clothing record V owns (inventory, stash, wardrobe store, whatever
// the item source) that was not owned last time becomes NEW, unless it is worn.
@addMethod(inkPreviewGameController)
private func WardrobeTabsScanNew(screen: ref<WardrobeScreenController>) -> Void {
    let player: ref<GameObject> = this.GetPlayerControlledObject();
    let system: ref<OutfitSystem> = screen.m_outfitSystem;
    let mark: ref<WardrobeTabsMark> = new WardrobeTabsMark();
    let seen: ref<inkHashMap> = new inkHashMap();
    for record in system.m_wtSeen {
        seen.Insert(TDBID.ToNumber(record), mark);
    }
    let owned: array<ItemID> = GameInstance.GetWardrobeSystem(player.GetGame()).GetStoredItemIDs();
    let transactions: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let held: array<wref<gameItemData>>;
    transactions.GetItemList(player, held);
    let stash: wref<Stash> = screen.m_inventoryHelper.GetStash();
    if IsDefined(stash) {
        transactions.GetItemList(stash, held);
    }
    for data in held {
        if IsDefined(data) {
            ArrayPush(owned, data.GetID());
        }
    }
    let ready: Bool = system.m_wtSeenReady;
    let added: Int32 = 0;
    let tagged: Int32 = 0;
    for itemID in owned {
        let record: TweakDBID = ItemID.GetTDBID(itemID);
        let key: Uint64 = TDBID.ToNumber(record);
        if !seen.KeyExist(key) && IsDefined(TweakDBInterface.GetClothingRecord(record)) {
            seen.Insert(key, mark);
            ArrayPush(system.m_wtSeen, record);
            added += 1;
            if ready && !system.IsEquipped(itemID) {
                ArrayPush(system.m_wtNewItems, record);
                tagged += 1;
            }
        }
    }
    system.m_wtSeenReady = true;
    let set: ref<inkHashMap> = new inkHashMap();
    for record in system.m_wtNewItems {
        set.Insert(TDBID.ToNumber(record), mark);
    }
    this.WardrobeTabsView().m_wtNewSet = set;
    WardrobeTabsDebug("NEW tags: " + ToString(ArraySize(owned)) + " owned items, " + ToString(added) + " not seen before"
        + (ready ? ", " + ToString(tagged) + " tagged" : " (first scan: recorded, none tagged)")
        + "; " + ToString(ArraySize(system.m_wtNewItems)) + " NEW, " + ToString(ArraySize(system.m_wtSeen)) + " seen");
}

// Per slot: whether its list holds a NEW item, for the dots on rows and tabs.
@addMethod(inkPreviewGameController)
private func WardrobeTabsUpdateNewSlots(screen: ref<WardrobeScreenController>) -> Void {
    ArrayClear(screen.m_wtSlotNew);
    ArrayResize(screen.m_wtSlotNew, ArraySize(screen.m_wtSlots));
    if ArraySize(screen.m_outfitSystem.m_wtNewItems) == 0 {
        return;
    }
    let index: Int32 = 0;
    while index < ArraySize(screen.m_wtSlots) {
        for child in screen.m_wtSlots[index].Children {
            if WardrobeTabsIsNew(child.Item.GetID()) && (!this.WardrobeTabsFiltering(screen) || this.WardrobeTabsMatches(screen, child)) {
                screen.m_wtSlotNew[index] = true;
                break;
            }
        }
        index += 1;
    }
}

// Drops an item's NEW tag (hovered long enough to try on, or equipped). True if it had one.
@addMethod(inkPreviewGameController)
private func WardrobeTabsClearNew(screen: ref<WardrobeScreenController>, itemID: ItemID) -> Bool {
    let set: ref<inkHashMap> = this.WardrobeTabsView().m_wtNewSet;
    let record: TweakDBID = ItemID.GetTDBID(itemID);
    if !IsDefined(set) || !set.KeyExist(TDBID.ToNumber(record)) {
        return false;
    }
    set.Remove(TDBID.ToNumber(record));
    ArrayRemove(screen.m_outfitSystem.m_wtNewItems, record);
    this.WardrobeTabsUpdateNewSlots(screen);
    return true;
}

// Splits a freshly populated source into its slots and tags each slot with its area.
@addMethod(inkPreviewGameController)
private func WardrobeTabsCapture(screen: ref<WardrobeScreenController>) -> Void {
    screen.m_wtAllItems = screen.m_inventoryGridDataSource.GetArray();
    ArrayClear(screen.m_wtSlots);
    for entry in screen.m_wtAllItems {
        let slot: ref<InventoryGridSlotData> = entry as InventoryGridSlotData;
        if IsDefined(slot) {
            if slot.m_wtTab == 0 {
                slot.m_wtTab = WardrobeTabsConfig.TabOfSlot(slot.ItemData.SlotID) + 1;
            }
            ArrayPush(screen.m_wtSlots, slot);
        }
    }
    if !screen.m_wtScanned {
        screen.m_wtScanned = true;
        this.WardrobeTabsScanNew(screen);
    }
    this.WardrobeTabsUpdateWorn(screen);
    this.WardrobeTabsCountPacks(screen);
    this.WardrobeTabsUpdateMatches(screen);
    this.WardrobeTabsUpdateNewSlots(screen);
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let selected: Int32 = this.WardrobeTabsSlotIndex(screen, view.m_wtSlot);
    if selected < 0 {
        view.m_wtSlot = this.WardrobeTabsDefaultSlot(screen);
        selected = this.WardrobeTabsSlotIndex(screen, view.m_wtSlot);
    }
    if selected >= 0 {
        view.m_wtArea = screen.m_wtSlots[selected].m_wtTab - 1;
    }
    this.WardrobeTabsApply(screen, false);
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsSlotIndex(screen: ref<WardrobeScreenController>, slotID: TweakDBID) -> Int32 {
    let index: Int32 = 0;
    while index < ArraySize(screen.m_wtSlots) {
        if screen.m_wtSlots[index].ItemData.SlotID == slotID {
            return index;
        }
        index += 1;
    }
    return -1;
}

// The first slot with something equipped, else the first slot.
@addMethod(inkPreviewGameController)
private func WardrobeTabsDefaultSlot(screen: ref<WardrobeScreenController>) -> TweakDBID {
    let index: Int32 = 0;
    while index < ArraySize(screen.m_wtSlots) {
        if this.WardrobeTabsIsWorn(screen, index) {
            return screen.m_wtSlots[index].ItemData.SlotID;
        }
        index += 1;
    }
    return ArraySize(screen.m_wtSlots) > 0 ? screen.m_wtSlots[0].ItemData.SlotID : TDBID.None();
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsUpdateWorn(screen: ref<WardrobeScreenController>) -> Bool {
    let count: Int32 = ArraySize(screen.m_wtSlots);
    ArrayClear(screen.m_wtWorn);
    ArrayClear(screen.m_wtWornNames);
    ArrayClear(screen.m_wtWornIcons);
    ArrayClear(screen.m_wtWornRecords);
    ArrayResize(screen.m_wtWorn, count);
    ArrayResize(screen.m_wtWornNames, count);
    ArrayResize(screen.m_wtWornIcons, count);
    ArrayResize(screen.m_wtWornRecords, count);
    let listed: array<TweakDBID>;
    let index: Int32 = 0;
    while index < count {
        for child in screen.m_wtSlots[index].Children {
            if screen.m_outfitSystem.IsEquipped(child.Item.GetID()) {
                screen.m_wtWorn[index] = child;
                ArrayPush(listed, ItemID.GetTDBID(child.Item.GetID()));
                break;
            }
        }
        index += 1;
    }
    // Equipment-EX lists only the selected item source, so a worn item can be missing from
    // every list. Its slot still holds the (preview) item, which has the same record.
    let player: ref<GameObject> = this.GetPlayerControlledObject();
    let transactions: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let used: array<TweakDBID> = screen.m_outfitSystem.GetUsedSlots();
    let candidates: array<InventoryItemData>;
    let gathered: Bool = false;
    for slotID in used {
        let object: ref<ItemObject> = transactions.GetItemInSlot(player, slotID);
        if IsDefined(object) {
            let itemID: ItemID = object.GetItemID();
            let recordID: TweakDBID = ItemID.GetTDBID(itemID);
            if !ArrayContains(listed, recordID) {
                let at: Int32 = this.WardrobeTabsSlotIndex(screen, slotID);
                // The real item is in the inventory, the stash or the wardrobe store under
                // another source; added to its slot's list, it shows in the grid as worn and
                // passes EQUIPPED ONLY like a listed one.
                let added: ref<InventoryGridItemData>;
                if at >= 0 && !IsDefined(screen.m_wtWorn[at]) {
                    if !gathered {
                        gathered = true;
                        screen.m_inventoryHelper.GetPlayerItems(candidates);
                        if IsDefined(screen.m_inventoryHelper.GetStash()) {
                            screen.m_inventoryHelper.GetStashItems(candidates);
                        }
                        screen.m_inventoryHelper.GetWardrobeItems(candidates);
                    }
                    added = this.WardrobeTabsAddWorn(screen, screen.m_wtSlots[at], recordID, candidates);
                }
                if IsDefined(added) {
                    screen.m_wtWorn[at] = added;
                    ArrayPush(listed, recordID);
                    WardrobeTabsDebug(screen.m_wtSlots[at].ItemData.CategoryName + ": worn item added to the item list: " + WardrobeTabsConfig.ItemName(added));
                } else if at < 0 || IsDefined(screen.m_wtWorn[at]) {
                    ModLog(n"WardrobeTabs", "Worn item without a slot row: " + TDBID.ToStringDEBUG(recordID) + " in " + TDBID.ToStringDEBUG(slotID));
                } else {
                    let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(recordID);
                    let name: String = screen.m_outfitSystem.GetItemName(itemID);
                    if StrLen(name) == 0 && IsDefined(record) {
                        name = NameToString(record.DisplayName());
                    }
                    screen.m_wtWornNames[at] = WardrobeTabsConfig.CleanName(name);
                    screen.m_wtWornIcons[at] = IsDefined(record) ? UIInventoryItemsManager.ResolveItemIconName(recordID, record, false) : "";
                    screen.m_wtWornRecords[at] = recordID;
                }
            }
        }
    }
    screen.m_wtUsedSlots = ArraySize(used);
    // Signature of what the column shows; logged and reported only when it changes.
    let sig: String = "";
    let log: String = "";
    index = 0;
    while index < count {
        if this.WardrobeTabsIsWorn(screen, index) {
            sig += ToString(index) + "=" + this.WardrobeTabsWornName(screen, index) + ";";
            if !IsDefined(screen.m_wtWorn[index]) {
                log += (StrLen(log) > 0 ? ", " : "") + screen.m_wtSlots[index].ItemData.CategoryName + ": " + screen.m_wtWornNames[index];
            }
        }
        index += 1;
    }
    if Equals(sig, screen.m_wtWornSig) {
        return false;
    }
    screen.m_wtWornSig = sig;
    if StrLen(log) > 0 {
        WardrobeTabsDebug("Worn items not in the item lists, shown from their slots: " + log);
    }
    return true;
}

// Built as Equipment-EX's PopulateInventoryGrid builds its items.
@addMethod(inkPreviewGameController)
private func WardrobeTabsAddWorn(screen: ref<WardrobeScreenController>, slot: ref<InventoryGridSlotData>, recordID: TweakDBID, candidates: array<InventoryItemData>) -> ref<InventoryGridItemData> {
    for data in candidates {
        if ItemID.GetTDBID(data.ID) == recordID && screen.m_outfitSystem.IsEquipped(data.ID) {
            let item: ref<InventoryGridItemData> = new InventoryGridItemData();
            item.Item = UIInventoryItem.Make(screen.m_player, slot.ItemData.SlotID, data, screen.m_uiInventorySystem.GetInventoryItemsManager());
            item.DisplayContextData = screen.m_itemDisplayContext;
            item.Parent = slot;
            ArrayInsert(slot.Children, 0, item);
            return item;
        }
    }
    return null;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsIsWorn(screen: ref<WardrobeScreenController>, index: Int32) -> Bool {
    return IsDefined(screen.m_wtWorn[index]) || TDBID.IsValid(screen.m_wtWornRecords[index]);
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsWornName(screen: ref<WardrobeScreenController>, index: Int32) -> String {
    return IsDefined(screen.m_wtWorn[index]) ? WardrobeTabsConfig.ItemName(screen.m_wtWorn[index]) : screen.m_wtWornNames[index];
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsWornIcon(screen: ref<WardrobeScreenController>, index: Int32) -> String {
    return IsDefined(screen.m_wtWorn[index]) ? screen.m_wtWorn[index].Item.GetIconPath() : screen.m_wtWornIcons[index];
}

// Cheap per-tick check: the number of used slots, and whether each remembered item is
// still equipped. Swapping an item in a slot unequips the remembered one.
@addMethod(inkPreviewGameController)
private func WardrobeTabsWornChanged(screen: ref<WardrobeScreenController>) -> Bool {
    // Stored in a local first: ArraySize(GetUsedSlots()) written inline gave 1 at runtime
    // while the same call stored in a local gave 12, so the two never matched.
    let used: array<TweakDBID> = screen.m_outfitSystem.GetUsedSlots();
    if ArraySize(used) != screen.m_wtUsedSlots {
        return true;
    }
    for worn in screen.m_wtWorn {
        if IsDefined(worn) && !screen.m_outfitSystem.IsEquipped(worn.Item.GetID()) {
            return true;
        }
    }
    // Unlisted items: the record in the slot changes when another item replaces it.
    let player: ref<GameObject> = this.GetPlayerControlledObject();
    let index: Int32 = 0;
    while index < ArraySize(screen.m_wtWornRecords) {
        if TDBID.IsValid(screen.m_wtWornRecords[index]) {
            let object: ref<ItemObject> = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(player, screen.m_wtSlots[index].ItemData.SlotID);
            if !IsDefined(object) || ItemID.GetTDBID(object.GetItemID()) != screen.m_wtWornRecords[index] {
                return true;
            }
        }
        index += 1;
    }
    return false;
}

// Mirrors InventoryGridDataView.FilterItem: the name search, and the "equipped" filter.
@addMethod(inkPreviewGameController)
private func WardrobeTabsMatches(screen: ref<WardrobeScreenController>, item: ref<InventoryGridItemData>) -> Bool {
    if screen.m_wtEquippedOnly && !item.Item.IsEquipped() {
        return false;
    }
    if !this.WardrobeTabsPackPasses(item) {
        return false;
    }
    if NotEquals(screen.m_wtQuery, "") {
        if !item.m_wtSearchReady {
            item.m_wtSearchName = UTF8StrLower(GetLocalizedText(item.Item.m_data.Name));
            item.m_wtSearchReady = true;
        }
        if StrContains(item.m_wtSearchName, screen.m_wtQuery) {
            return true;
        }
        let pack: wref<WardrobeTabsPack> = this.WardrobeTabsItemPack(item);
        return IsDefined(pack) && StrContains(pack.lower, screen.m_wtQuery);
    }
    return true;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsUpdateMatches(screen: ref<WardrobeScreenController>) -> Void {
    ArrayClear(screen.m_wtMatches);
    let filtering: Bool = this.WardrobeTabsFiltering(screen);
    for slot in screen.m_wtSlots {
        let count: Int32 = 0;
        if !filtering {
            count = ArraySize(slot.Children);
        } else {
            for child in slot.Children {
                if this.WardrobeTabsMatches(screen, child) {
                    count += 1;
                }
            }
        }
        ArrayPush(screen.m_wtMatches, count);
    }
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsFiltering(screen: ref<WardrobeScreenController>) -> Bool {
    return screen.m_wtEquippedOnly || NotEquals(screen.m_wtQuery, "") || this.WardrobeTabsView().m_wtPackChoice != 0;
}

// Shows the selected slot's items in the grid, those matching any search or filter. Excluding
// the slot data drops its header; clearing IsCollapsed keeps its items visible whatever Equipment-EX
// remembers for it. Without a scroll reset the position is kept across the rebuild.
@addMethod(inkPreviewGameController)
private func WardrobeTabsApply(screen: ref<WardrobeScreenController>, resetScroll: Bool) -> Void {
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let index: Int32 = this.WardrobeTabsSlotIndex(screen, view.m_wtSlot);
    let kept: array<ref<IScriptable>>;
    if index >= 0 {
        let slot: ref<InventoryGridSlotData> = screen.m_wtSlots[index];
        slot.IsCollapsed = false;
        let filtering: Bool = this.WardrobeTabsFiltering(screen);
        for child in slot.Children {
            if !filtering || this.WardrobeTabsMatches(screen, child) {
                ArrayPush(kept, child);
            }
        }
    }
    if !resetScroll {
        screen.QueueScrollPositionRestore();
    }
    screen.m_inventoryGridDataSource.Reset(kept);
    screen.m_inventoryGridDataView.UpdateView();
    if resetScroll {
        screen.m_inventoryScrollController.SetScrollPosition(0.0);
    }
    this.WardrobeTabsRedraw(screen);
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsRedraw(screen: ref<WardrobeScreenController>) -> Void {
    let selected: Int32 = this.WardrobeTabsSlotIndex(screen, this.WardrobeTabsView().m_wtSlot);
    this.WardrobeTabsUpdateLink(screen);
    this.WardrobeTabsRedrawBody(screen, selected);
    this.WardrobeTabsRedrawHeader(screen, selected);
    this.WardrobeTabsRedrawButtons(screen, selected);
    this.WardrobeTabsRedrawLook(screen);
    this.WardrobeTabsStyleOutfits(screen);
}

// HEAD to FEET always; OTHER only when something there is worn. Within a group, worn items
// in Equipment-EX's slot order (head to toe), then the + tile. Tiles shrink to fit one row.
@addMethod(inkPreviewGameController)
private func WardrobeTabsRedrawBody(screen: ref<WardrobeScreenController>, selected: Int32) -> Void {
    if ArraySize(screen.m_wtGroupHeads) == 0 {
        return;
    }
    let width: Float = WardrobeTabsConfig.BodyWidth();
    let gap: Float = WardrobeTabsConfig.TileGap();
    let perGroup: Int32 = WardrobeTabsConfig.GroupTiles();
    let clothing: Bool = !this.WardrobeTabsView().m_wtOutfitsSection;
    let red: HDRColor = new HDRColor(1.176, 0.381, 0.348, 1.0);
    let activeRed: HDRColor = new HDRColor(1.370, 0.444, 0.405, 1.0);
    let mildRed: HDRColor = new HDRColor(0.682, 0.231, 0.212, 1.0);
    let blue: HDRColor = new HDRColor(0.369, 0.965, 1.0, 1.0);
    let otherWorn: Bool = false;
    let index: Int32 = 0;
    while index < ArraySize(screen.m_wtSlots) {
        if screen.m_wtSlots[index].m_wtTab - 1 == WardrobeTabsConfig.OtherTab() && this.WardrobeTabsIsWorn(screen, index) {
            otherWorn = true;
        }
        index += 1;
    }
    let shown: Int32 = otherWorn ? WardrobeTabsConfig.OtherTab() + 1 : WardrobeTabsConfig.OtherTab();
    let height: Float = MinF(WardrobeTabsConfig.GroupMax(), WardrobeTabsConfig.GroupsHeight() / Cast<Float>(shown));
    let group: Int32 = 0;
    while group < ArraySize(screen.m_wtGroupHeads) {
        let visible: Bool = group < shown;
        let head: wref<inkCanvas> = screen.m_wtGroupHeads[group];
        head.SetVisible(visible);
        let worn: array<Int32>;
        if visible {
            index = 0;
            while index < ArraySize(screen.m_wtSlots) {
                if screen.m_wtSlots[index].m_wtTab - 1 == group && this.WardrobeTabsIsWorn(screen, index) {
                    ArrayPush(worn, index);
                }
                index += 1;
            }
            let y: Float = 60.0 + Cast<Float>(group) * height;
            head.SetMargin(new inkMargin(0.0, y, 0.0, 0.0));
            screen.m_wtGroupLabels[group].SetTintColor(screen.m_wtHover == head ? activeRed : red);
            let count: Int32 = ArraySize(worn);
            screen.m_wtGroupCounts[group].SetText(count == 0 ? "NOTHING WORN" : ToString(count) + " WORN");
            screen.m_wtGroupCounts[group].SetTintColor(mildRed);
            // Detail line: the hovered tile's slot and item, else the worn slots' names.
            let detail: String = "";
            let hoveredSlot: Int32 = -1;
            let tile: Int32 = 0;
            while tile < perGroup {
                if screen.m_wtHover == screen.m_wtTiles[group * perGroup + tile] && tile < count {
                    hoveredSlot = worn[tile];
                }
                tile += 1;
            }
            if hoveredSlot >= 0 {
                detail = screen.m_wtSlots[hoveredSlot].ItemData.CategoryName + ":  " + this.WardrobeTabsWornName(screen, hoveredSlot);
            } else {
                for slot in worn {
                    detail += (StrLen(detail) > 0 ? ",  " : "") + screen.m_wtSlots[slot].ItemData.CategoryName;
                }
            }
            screen.m_wtGroupDetails[group].SetText(detail);
            screen.m_wtGroupDetails[group].SetTintColor(hoveredSlot >= 0 ? blue : mildRed);

            let shownTiles: Int32 = Min(count, perGroup - 1) + 1;
            let size: Float = MinF(WardrobeTabsConfig.TileMax(), (width - gap * Cast<Float>(shownTiles - 1)) / Cast<Float>(shownTiles));
            let tileHeight: Float = MinF(size * 0.86, height - WardrobeTabsConfig.GroupHeader() - 14.0);
            let scale: Float = MinF(0.7, tileHeight / 200.0);
            tile = 0;
            while tile < perGroup {
                let at: Int32 = group * perGroup + tile;
                let widget: wref<inkCanvas> = screen.m_wtTiles[at];
                let isItem: Bool = tile < shownTiles - 1;
                let isPlus: Bool = tile == shownTiles - 1;
                widget.SetVisible(isItem || isPlus);
                screen.m_wtTileSlots[at] = isItem ? worn[tile] : (isPlus ? -2 : -1);
                if isItem || isPlus {
                    let hovered: Bool = screen.m_wtHover == widget;
                    widget.SetSize(size, tileHeight);
                    widget.SetMargin(new inkMargin(Cast<Float>(tile) * (size + gap), y + WardrobeTabsConfig.GroupHeader(), 0.0, 0.0));
                    screen.m_wtTileBgs[at].SetTintColor(hovered ? new HDRColor(0.30, 0.06, 0.08, 1.0) : new HDRColor(0.15, 0.035, 0.08, 1.0));
                    screen.m_wtTileBgs[at].SetOpacity(isPlus ? 0.5 : 0.9);
                    screen.m_wtTileBars[at].SetVisible(isItem && clothing && worn[tile] == selected);
                    screen.m_wtTilePlus[at].SetVisible(isPlus);
                    screen.m_wtTilePlus[at].SetTintColor(hovered ? activeRed : mildRed);
                    screen.m_wtTileIcons[at].SetScale(new Vector2(scale, scale));
                    this.WardrobeTabsSetIcon(screen, at, isItem ? this.WardrobeTabsWornIcon(screen, worn[tile]) : "");
                }
                tile += 1;
            }
        } else {
            let tile: Int32 = 0;
            while tile < perGroup {
                screen.m_wtTiles[group * perGroup + tile].SetVisible(false);
                screen.m_wtTileSlots[group * perGroup + tile] = -1;
                tile += 1;
            }
        }
        group += 1;
    }
}

// Tiles keep their item while the column is unchanged, so each remembers its icon.
@addMethod(inkPreviewGameController)
private func WardrobeTabsSetIcon(screen: ref<WardrobeScreenController>, tile: Int32, path: String) -> Void {
    if Equals(screen.m_wtTileIconPaths[tile], path) {
        return;
    }
    screen.m_wtTileIconPaths[tile] = path;
    let icon: wref<inkImage> = screen.m_wtTileIcons[tile];
    icon.SetVisible(NotEquals(path, ""));
    if NotEquals(path, "") {
        InkImageUtils.RequestSetImage(this, icon, path);
    }
}

// Title: the slot, or OUTFITS. Subtitle: how many items (and colours when grouped), the
// share matching a search or filter, and what is worn there; for outfits, how many are
// saved, favourite and matching.
@addMethod(inkPreviewGameController)
private func WardrobeTabsRedrawHeader(screen: ref<WardrobeScreenController>, selected: Int32) -> Void {
    if !IsDefined(screen.m_wtTitle) {
        return;
    }
    let view: ref<ViewManager> = this.WardrobeTabsView();
    if view.m_wtOutfitsSection {
        let names: array<CName> = screen.m_outfitSystem.GetOutfits();
        let saved: Int32 = ArraySize(names);
        let favourites: Int32 = 0;
        for name in names {
            if ArrayContains(screen.m_outfitSystem.m_wtFavourites, name) {
                favourites += 1;
            }
        }
        let summary: String = ToString(saved) + (saved == 1 ? " SAVED OUTFIT" : " SAVED OUTFITS");
        if favourites > 0 {
            summary += "  |  " + ToString(favourites) + (favourites == 1 ? " FAVOURITE" : " FAVOURITES");
        }
        if StrLen(screen.m_wtOutfitQuery) > 0 {
            summary += "  |  " + ToString(ArraySize(screen.m_wtOutfitNames)) + " MATCH";
        }
        screen.m_wtTitle.SetText("OUTFITS");
        screen.m_wtSubtitle.SetText(summary);
        return;
    }
    if selected < 0 {
        screen.m_wtTitle.SetText("");
        screen.m_wtSubtitle.SetText("");
        return;
    }
    let slot: ref<InventoryGridSlotData> = screen.m_wtSlots[selected];
    screen.m_wtTitle.SetText(slot.ItemData.CategoryName);
    let total: Int32 = ArraySize(slot.Children);
    let text: String = ToString(total) + " ITEMS";
    if this.WardrobeTabsFiltering(screen) {
        text += "  |  " + ToString(screen.m_wtMatches[selected]) + " MATCH";
    }
    if this.WardrobeTabsIsWorn(screen, selected) {
        text += "  |  WEARING " + this.WardrobeTabsWornName(screen, selected);
    }
    screen.m_wtSubtitle.SetText(text);
}

// The selected area's slots, with matches when filtering, from the current chip page.
@addMethod(inkPreviewGameController)
private func WardrobeTabsAreaSlots(screen: ref<WardrobeScreenController>, area: Int32) -> array<Int32> {
    let filtering: Bool = this.WardrobeTabsFiltering(screen);
    let slots: array<Int32>;
    let index: Int32 = 0;
    while index < ArraySize(screen.m_wtSlots) {
        if screen.m_wtSlots[index].m_wtTab - 1 == area && (!filtering || screen.m_wtMatches[index] > 0) {
            ArrayPush(slots, index);
        }
        index += 1;
    }
    return slots;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsStyleButton(screen: ref<WardrobeScreenController>, button: Int32, active: Bool) -> Void {
    let hovered: Bool = screen.m_wtHover == screen.m_wtButtons[button];
    screen.m_wtButtonBgs[button].SetTintColor(active ? new HDRColor(0.090, 0.173, 0.180, 1.0)
        : (hovered ? new HDRColor(0.412, 0.086, 0.090, 1.0) : new HDRColor(0.263, 0.086, 0.094, 1.0)));
    screen.m_wtButtonTexts[button].SetTintColor(active ? new HDRColor(0.369, 0.965, 1.0, 1.0)
        : (hovered ? new HDRColor(1.370, 0.444, 0.405, 1.0) : new HDRColor(1.176, 0.381, 0.348, 1.0)));
    screen.m_wtButtonCounts[button].SetTintColor(active ? new HDRColor(0.204, 0.569, 0.592, 1.0) : new HDRColor(0.682, 0.231, 0.212, 1.0));
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsRedrawButtons(screen: ref<WardrobeScreenController>, selected: Int32) -> Void {
    let buttons: Int32 = ArraySize(screen.m_wtButtons);
    // Header, sidebar, bar and outfits buttons all exist only when the grid container was found.
    if buttons <= WardrobeTabsConfig.NoOutfitButton() {
        return;
    }
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let clothing: Bool = !view.m_wtOutfitsSection;
    let filtering: Bool = this.WardrobeTabsFiltering(screen);
    // Area tabs: OTHER only when it has slots.
    let area: Int32 = 0;
    while area <= WardrobeTabsConfig.OtherTab() {
        let slots: array<Int32> = this.WardrobeTabsAreaSlots(screen, area);
        screen.m_wtButtons[area].SetVisible(clothing && (area < WardrobeTabsConfig.OtherTab() || ArraySize(slots) > 0));
        // While searching or filtering, each tab shows how many items in its area match, and
        // areas without a match dim like empty ones.
        let label: String = WardrobeTabsConfig.AreaLabel(area);
        let matches: Int32 = 0;
        if filtering {
            for slot in slots {
                if slot < ArraySize(screen.m_wtMatches) {
                    matches += screen.m_wtMatches[slot];
                }
            }
            label += " (" + ToString(matches) + ")";
        }
        screen.m_wtButtonTexts[area].SetText(label);
        screen.m_wtButtons[area].SetOpacity(ArraySize(slots) > 0 && (!filtering || matches > 0) ? 1.0 : 0.4);
        this.WardrobeTabsStyleButton(screen, area, area == view.m_wtArea);
        let fresh: Bool = false;
        for slot in slots {
            if slot < ArraySize(screen.m_wtSlotNew) && screen.m_wtSlotNew[slot] {
                fresh = true;
            }
        }
        screen.m_wtButtonNews[area].SetVisible(fresh);
        area += 1;
    }
    this.WardrobeTabsStyleButton(screen, 7, screen.m_wtEquippedOnly);
    // Chips: one page of the area's slots, PREVIOUS / NEXT when there is more.
    let slots: array<Int32> = this.WardrobeTabsAreaSlots(screen, view.m_wtArea);
    let perPage: Int32 = WardrobeTabsConfig.ChipsPerPage();
    if screen.m_wtChipOffset > ArraySize(slots) - perPage { screen.m_wtChipOffset = ArraySize(slots) - perPage; }
    if screen.m_wtChipOffset < 0 { screen.m_wtChipOffset = 0; }
    screen.m_wtButtons[8].SetVisible(clothing && ArraySize(slots) > perPage);
    screen.m_wtButtons[9].SetVisible(clothing && ArraySize(slots) > perPage);
    screen.m_wtButtons[8].SetOpacity(screen.m_wtChipOffset > 0 ? 1.0 : 0.35);
    screen.m_wtButtons[9].SetOpacity(screen.m_wtChipOffset + perPage < ArraySize(slots) ? 1.0 : 0.35);
    this.WardrobeTabsStyleButton(screen, 8, false);
    this.WardrobeTabsStyleButton(screen, 9, false);
    ArrayClear(screen.m_wtChipSlots);
    let chip: Int32 = 0;
    while chip < perPage {
        let button: Int32 = 10 + chip;
        let entry: Int32 = screen.m_wtChipOffset + chip;
        let visible: Bool = clothing && entry < ArraySize(slots);
        screen.m_wtButtons[button].SetVisible(visible);
        screen.m_wtButtonNews[button].SetVisible(false);
        if entry < ArraySize(slots) {
            let index: Int32 = slots[entry];
            screen.m_wtButtonNews[button].SetVisible(index < ArraySize(screen.m_wtSlotNew) && screen.m_wtSlotNew[index]);
            let slot: ref<InventoryGridSlotData> = screen.m_wtSlots[index];
            screen.m_wtButtonTexts[button].SetText(slot.ItemData.CategoryName);
            screen.m_wtButtonCounts[button].SetText(filtering ? ToString(screen.m_wtMatches[index]) : ToString(ArraySize(slot.Children)));
            this.WardrobeTabsStyleButton(screen, button, index == selected);
            if index != selected && this.WardrobeTabsIsWorn(screen, index) && screen.m_wtHover != screen.m_wtButtons[button] {
                screen.m_wtButtonTexts[button].SetTintColor(new HDRColor(0.369, 0.965, 1.0, 1.0));
            }
            ArrayPush(screen.m_wtChipSlots, index);
        }
        chip += 1;
    }
    // Bar: OUTFITS with the saved count, BACK in the outfits view. Outfits view: SAVE OUTFIT,
    // and NO OUTFIT lit while no outfit is worn.
    let outfits: Int32 = WardrobeTabsConfig.OutfitsButton();
    let saved: array<CName> = screen.m_outfitSystem.GetOutfits();
    screen.m_wtButtonTexts[outfits].SetText(clothing ? "OUTFITS (" + ToString(ArraySize(saved)) + ")" : "BACK");
    this.WardrobeTabsStyleButton(screen, outfits, false);
    let edited: Bool = screen.m_wtLinkChanges >= 0;
    screen.m_wtButtons[WardrobeTabsConfig.UpdateButton()].SetVisible(edited);
    screen.m_wtButtons[WardrobeTabsConfig.RevertButton()].SetVisible(edited);
    this.WardrobeTabsStyleButton(screen, WardrobeTabsConfig.UpdateButton(), false);
    this.WardrobeTabsStyleButton(screen, WardrobeTabsConfig.RevertButton(), false);
    this.WardrobeTabsStyleButton(screen, WardrobeTabsConfig.SaveOutfitButton(), false);
    this.WardrobeTabsStyleButton(screen, WardrobeTabsConfig.NoOutfitButton(), !screen.m_outfitSystem.IsActive());
    this.WardrobeTabsRedrawPacks(screen);
    let columns: Int32 = WardrobeTabsConfig.MinColumns();
    while columns <= WardrobeTabsConfig.MaxColumns() && WardrobeTabsConfig.ColumnButton(columns) < ArraySize(screen.m_wtButtons) {
        this.WardrobeTabsStyleButton(screen, WardrobeTabsConfig.ColumnButton(columns), columns == WardrobeTabsColumns());
        columns += 1;
    }
}

// Moves the chip page so the selected slot is on it.
@addMethod(inkPreviewGameController)
private func WardrobeTabsRevealChip(screen: ref<WardrobeScreenController>) -> Void {
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let slots: array<Int32> = this.WardrobeTabsAreaSlots(screen, view.m_wtArea);
    let position: Int32 = ArrayFindFirst(slots, this.WardrobeTabsSlotIndex(screen, view.m_wtSlot));
    let perPage: Int32 = WardrobeTabsConfig.ChipsPerPage();
    if position >= 0 && (position < screen.m_wtChipOffset || position >= screen.m_wtChipOffset + perPage) {
        screen.m_wtChipOffset = (position / perPage) * perPage;
    }
}

// Keeps the linked outfit and counts the slots that differ from it. A look that matches an
// outfit links it (wearing, saving, UPDATE, REVERT all end that way); NO OUTFIT or deleting
// the linked outfit clears the link.
@addMethod(inkPreviewGameController)
private func WardrobeTabsUpdateLink(screen: ref<WardrobeScreenController>) -> Void {
    let system: ref<OutfitSystem> = screen.m_outfitSystem;
    screen.m_wtLinkChanges = -1;
    if !system.IsActive() {
        system.m_wtLinked = n"";
        return;
    }
    let outfits: array<CName> = system.GetOutfits();
    if IsNameValid(system.m_wtLinked) && system.IsEquipped(system.m_wtLinked) {
        return;
    }
    for outfit in outfits {
        if system.IsEquipped(outfit) {
            system.m_wtLinked = outfit;
            return;
        }
    }
    if !IsNameValid(system.m_wtLinked) || !ArrayContains(outfits, system.m_wtLinked) {
        system.m_wtLinked = n"";
        return;
    }
    // Saved items no longer worn are removed or replaced; a replaced one's slot is occupied,
    // so it is not counted again among the worn items the outfit does not have.
    let parts: array<ref<OutfitPart>> = system.GetOutfitParts(system.m_wtLinked);
    let used: array<TweakDBID> = system.GetUsedSlots();
    let missing: Int32 = 0;
    let replaced: Int32 = 0;
    let kept: Int32 = 0;
    for part in parts {
        if system.IsEquipped(part.GetItemID()) {
            kept += 1;
        } else {
            missing += 1;
            if system.IsOccupied(part.GetSlotID()) {
                replaced += 1;
            }
        }
    }
    screen.m_wtLinkChanges = missing + Max(0, ArraySize(used) - kept - replaced);
}

// "Saved as <outfit>" when the worn items match a saved outfit, "<outfit> | edited" after a
// change to the linked one.
@addMethod(inkPreviewGameController)
private func WardrobeTabsRedrawLook(screen: ref<WardrobeScreenController>) -> Void {
    if !IsDefined(screen.m_wtLook) {
        return;
    }
    let linked: CName = screen.m_outfitSystem.m_wtLinked;
    let changes: Int32 = screen.m_wtLinkChanges;
    let tried: wref<UIInventoryItem> = screen.m_wtTrying;
    screen.m_wtLook.SetTintColor(IsDefined(tried) ? new HDRColor(0.369, 0.965, 1.0, 1.0) : new HDRColor(0.682, 0.231, 0.212, 1.0));
    if IsDefined(tried) {
        screen.m_wtLook.SetText("TRYING ON: " + WardrobeTabsConfig.CleanName(GetLocalizedText(tried.GetName())));
    } else if changes > 0 {
        screen.m_wtLook.SetText(NameToString(linked) + "  |  EDITED  |  " + ToString(changes) + (changes == 1 ? " CHANGE" : " CHANGES"));
    } else if changes == 0 {
        // Same items, reassigned slots: not the saved outfit, but nothing to count.
        screen.m_wtLook.SetText(NameToString(linked) + "  |  EDITED");
    } else if IsNameValid(linked) {
        screen.m_wtLook.SetText("SAVED AS " + NameToString(linked));
    } else {
        let outfits: array<CName> = screen.m_outfitSystem.GetOutfits();
        screen.m_wtLook.SetText(ArraySize(outfits) == 0 ? "NO SAVED OUTFITS YET" : "NOT SAVED AS AN OUTFIT");
    }
}

// Selects a slot and shows its items from the top, switching to AVAILABLE CLOTHING.
@addMethod(inkPreviewGameController)
private func WardrobeTabsSelect(screen: ref<WardrobeScreenController>, index: Int32) -> Void {
    let view: ref<ViewManager> = this.WardrobeTabsView();
    if view.m_wtOutfitsSection {
        view.m_wtOutfitsSection = false;
        this.WardrobeTabsRefresh(screen);
    }
    view.m_wtArea = screen.m_wtSlots[index].m_wtTab - 1;
    // Slots in the framed area leave the camera alone; one in another area moves it.
    if screen.m_wtCameraArea != view.m_wtArea + 1 {
        this.WardrobeTabsCamera(screen, view.m_wtArea);
    }
    let slotID: TweakDBID = screen.m_wtSlots[index].ItemData.SlotID;
    if slotID == view.m_wtSlot {
        this.WardrobeTabsRevealChip(screen);
        this.WardrobeTabsRedraw(screen);
        return;
    }
    view.m_wtSlot = slotID;
    this.WardrobeTabsRevealChip(screen);
    this.WardrobeTabsApply(screen, true);
}

// Shows an area's slots in the chips; the grid moves to the area's first slot when the
// selected one is elsewhere.
@addMethod(inkPreviewGameController)
private func WardrobeTabsSelectArea(screen: ref<WardrobeScreenController>, area: Int32) -> Void {
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let slots: array<Int32> = this.WardrobeTabsAreaSlots(screen, area);
    if ArraySize(slots) == 0 {
        return;
    }
    screen.m_wtChipOffset = 0;
    // Picking an area always frames it, also again after the wheel zoomed elsewhere.
    this.WardrobeTabsCamera(screen, area);
    let selected: Int32 = this.WardrobeTabsSlotIndex(screen, view.m_wtSlot);
    if ArrayContains(slots, selected) && !view.m_wtOutfitsSection {
        view.m_wtArea = area;
        this.WardrobeTabsRevealChip(screen);
        this.WardrobeTabsRedraw(screen);
        return;
    }
    this.WardrobeTabsSelect(screen, slots[0]);
}

// Hover try-on, once per tick. A card hovered for TryOnTicks() puts its item on the preview
// puppet only (Equipment-EX's EquipPuppetItem); moving to another card swaps it after the same
// pause, and nothing hovered for TryOffTicks() puts the real look back. OUTFITS, a refilled
// or scrolled grid (new data under the cursor) and an equipped item end it too.
@addMethod(inkPreviewGameController)
private func WardrobeTabsWatchTryOn(screen: ref<WardrobeScreenController>) -> Void {
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let hovered: wref<UIInventoryItem>;
    if !view.m_wtOutfitsSection {
        if IsDefined(view.m_wtHoverCard) {
            hovered = view.m_wtHoverCard.GetUIInventoryItem();
        }
    }
    if IsDefined(hovered) && hovered.IsEquipped() {
        hovered = null;
    }
    if hovered != screen.m_wtTryHover {
        // Same display, other item: the grid scrolled or refilled under the cursor.
        if IsDefined(hovered) && view.m_wtHoverCard == screen.m_wtTryCard {
            this.WardrobeTabsEndTryOn(screen);
        }
        screen.m_wtTryHover = hovered;
        screen.m_wtTryTicks = 0;
        screen.m_wtTryStart = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetPlayerControlledObject().GetGame()));
    } else if screen.m_wtTryTicks < 1000 {
        screen.m_wtTryTicks += 1;
    }
    screen.m_wtTryCard = view.m_wtHoverCard;
    if !IsDefined(hovered) {
        screen.m_wtTryIdle += 1;
        // OUTFITS ends it at once; so does the tried item being equipped (clicked).
        let tried: wref<UIInventoryItem> = screen.m_wtTrying;
        let equipped: Bool = IsDefined(tried) && tried.IsEquipped();
        if screen.m_wtTryIdle >= WardrobeTabsConfig.TryOffTicks() || view.m_wtOutfitsSection || equipped {
            this.WardrobeTabsEndTryOn(screen);
        }
        return;
    }
    screen.m_wtTryIdle = 0;
    if screen.m_wtTryTicks == WardrobeTabsConfig.TryOnTicks() && hovered != screen.m_wtTrying {
        // Hovered long enough to try on: no longer NEW.
        if this.WardrobeTabsClearNew(screen, hovered.GetID()) {
            if IsDefined(view.m_wtHoverCard) {
                view.m_wtHoverCard.WardrobeTabsHideNewTag();
            }
            this.WardrobeTabsRedraw(screen);
        }
        if !IsDefined(screen.m_wtSettings) || screen.m_wtSettings.hoverTryOn {
            let paused: Float = EngineTime.ToFloat(GameInstance.GetEngineTime(this.GetPlayerControlledObject().GetGame())) - screen.m_wtTryStart;
            WardrobeTabsDebug("Hover pause before try-on: " + FloatToStringPrec(paused, 2) + " s");
            this.WardrobeTabsStartTryOn(screen, hovered);
        }
    }
}

// Moves the preview image down while the FEET setup is applied and back otherwise, with the
// camera's own 0.5 s. Read from the setup last applied, so Equipment-EX's wheel zoom (which
// sends its own setups) drops the lift too.
@addMethod(inkPreviewGameController)
private func WardrobeTabsWatchLift(screen: ref<WardrobeScreenController>) -> Void {
    let preview: wref<inkInventoryPuppetPreviewGameController> = PaperdollHelper.GetInstance(this.GetPlayerControlledObject().GetGame()).GetPreview();
    let lift: Float = 0.0;
    if IsDefined(preview) && preview.m_wtFirstSetup > 0 && preview.m_wtSetup == preview.m_wtFirstSetup + 4 {
        lift = WardrobeTabsConfig.FeetLift();
    }
    if lift == screen.m_wtLift {
        return;
    }
    // Relative to the wardrobe screen (Equipment-EX's "wardrobe/wrapper/preview" is from the
    // inventory menu, and found nothing here in v28).
    let image: wref<inkWidget> = this.GetChildWidgetByPath(n"wrapper/preview");
    if !IsDefined(image) {
        ModLog(n"WardrobeTabs", "Preview image not found for the FEET lift");
        screen.m_wtLift = lift;
        return;
    }
    if IsDefined(screen.m_wtLiftAnim) && screen.m_wtLiftAnim.IsPlaying() {
        screen.m_wtLiftAnim.Stop();
    }
    let move: ref<inkAnimTranslation> = new inkAnimTranslation();
    move.SetStartTranslation(image.GetTranslation());
    // Keeps the sideways PreviewShift() set when the drawer was built.
    move.SetEndTranslation(new Vector2(WardrobeTabsConfig.PreviewShift(), lift));
    move.SetDuration(0.5);
    move.SetType(inkanimInterpolationType.Quadratic);
    move.SetMode(inkanimInterpolationMode.EasyOut);
    let definition: ref<inkAnimDef> = new inkAnimDef();
    definition.AddInterpolator(move);
    screen.m_wtLiftAnim = image.PlayAnimation(definition);
    screen.m_wtLift = lift;
    WardrobeTabsDebug("Preview image moved down " + FloatToStringPrec(lift, 0));
}

// Moves the preview camera to an area's own setup (-1 or OTHER: vanilla's full body), with
// the game's own transition. Equipment-EX's wheel zoom sends the same event to the same
// preview.
@addMethod(inkPreviewGameController)
private func WardrobeTabsCamera(screen: ref<WardrobeScreenController>, area: Int32) -> Void {
    // Off in Mod Settings: the camera stays wherever Equipment-EX's wheel zoom puts it.
    if IsDefined(screen.m_wtSettings) && !screen.m_wtSettings.areaCamera {
        return;
    }
    let preview: wref<inkInventoryPuppetPreviewGameController> = PaperdollHelper.GetInstance(this.GetPlayerControlledObject().GetGame()).GetPreview();
    if !IsDefined(preview) {
        ModLog(n"WardrobeTabs", "Camera: no preview controller");
        return;
    }
    let index: Int32 = EnumInt(InventoryPaperdollZoomArea.Default);
    if area >= 0 && area < WardrobeTabsConfig.CameraAreas() {
        if preview.m_wtFirstSetup > 0 {
            index = preview.m_wtFirstSetup + area;
        } else {
            index = EnumInt(WardrobeTabsConfig.AreaCamera(area));
            ModLog(n"WardrobeTabs", "Camera: setups not added at preview start, using vanilla setup");
        }
    }
    let evt: ref<gameuiPuppetPreview_SetCameraSetupEvent> = new gameuiPuppetPreview_SetCameraSetupEvent();
    evt.setupIndex = Cast<Uint32>(index);
    preview.QueueEvent(evt);
    screen.m_wtCameraArea = area >= 0 && area < WardrobeTabsConfig.CameraAreas() ? area + 1 : 0;
    WardrobeTabsDebug("Camera: " + WardrobeTabsConfig.AreaLabel(area) + " -> setup " + ToString(index) + " ("
        + NameToString(WardrobeTabsConfig.CameraSlot(area)) + ", " + ToString(WardrobeTabsConfig.CameraZoom(area)) + ")");
}

// Index of the mod's first camera setup on V's preview (one per area, after vanilla's 12).
// They are added when the preview starts, as the old PreviewZoom did: added later, on the
// first area click (v20, v21), V vanished on every one of them.
@addField(inkInventoryPuppetPreviewGameController)
public let m_wtFirstSetup: Int32;

// The setup last applied, whoever sent it (the mod's areas or Equipment-EX's wheel zoom).
@addField(inkInventoryPuppetPreviewGameController)
public let m_wtSetup: Int32;

@wrapMethod(inkInventoryPuppetPreviewGameController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();
    this.WardrobeTabsCameraSetups();
    return result;
}

@addMethod(inkInventoryPuppetPreviewGameController)
public func WardrobeTabsCameraSetups() -> Int32 {
    if this.m_wtFirstSetup > 0 {
        return this.m_wtFirstSetup;
    }
    let first: Int32 = ArraySize(this.cameraController.cameraSetup);
    ArrayResize(this.cameraController.cameraSetup, first + WardrobeTabsConfig.CameraAreas());
    let area: Int32 = 0;
    while area < WardrobeTabsConfig.CameraAreas() {
        let setup: gameuiPuppetPreviewCameraSetup;
        setup.slotName = WardrobeTabsConfig.CameraSlot(area);
        setup.cameraZoom = WardrobeTabsConfig.CameraZoom(area);
        setup.interpolationTime = 0.5;
        this.cameraController.cameraSetup[first + area] = setup;
        area += 1;
    }
    this.m_wtFirstSetup = first;
    WardrobeTabsDebug("Camera: added setups " + ToString(first) + " to " + ToString(first + WardrobeTabsConfig.CameraAreas() - 1));
    return first;
}

// The mod's setups have no InventoryPaperdollZoomArea: V takes the pose of the area's vanilla
// setup while the camera uses the requested one (as the earlier PreviewZoom did).
@wrapMethod(inkInventoryPuppetPreviewGameController)
protected cb func OnSetCameraSetupEvent(index: Uint32, slotName: CName) -> Bool {
    let first: Int32 = this.m_wtFirstSetup;
    let at: Int32 = Cast<Int32>(index);
    this.m_wtSetup = at;
    if first > 0 && at >= first && at < first + WardrobeTabsConfig.CameraAreas() {
        return wrappedMethod(Cast<Uint32>(EnumInt(WardrobeTabsConfig.AreaCamera(at - first))), slotName);
    }
    return wrappedMethod(index, slotName);
}

// V on the wardrobe's preview. The screen's own GetGamePuppet() is empty: the preview is a
// separate inkInventoryPuppetPreviewGameController, which Equipment-EX records on its
// PaperdollHelper when it initializes.
@addMethod(inkPreviewGameController)
private func WardrobeTabsPreviewPuppet(screen: ref<WardrobeScreenController>) -> wref<gamePuppet> {
    let preview: wref<inkInventoryPuppetPreviewGameController> = PaperdollHelper.GetInstance(this.GetPlayerControlledObject().GetGame()).GetPreview();
    if IsDefined(preview) && IsDefined(preview.GetGamePuppet()) {
        return preview.GetGamePuppet();
    }
    return screen.GetGamePuppet();
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsStartTryOn(screen: ref<WardrobeScreenController>, item: wref<UIInventoryItem>) -> Void {
    let name: String = WardrobeTabsConfig.CleanName(GetLocalizedText(item.GetName()));
    let puppet: wref<gamePuppet> = this.WardrobeTabsPreviewPuppet(screen);
    if !IsDefined(puppet) || screen.m_outfitSystem.IsBlocked() {
        WardrobeTabsDebug("Try-on skipped for " + name + (IsDefined(puppet) ? ": outfit system blocked" : ": no preview puppet"));
        return;
    }
    let itemID: ItemID = item.GetID();
    if !screen.m_outfitSystem.IsEquippable(itemID) {
        WardrobeTabsDebug("Try-on skipped for " + name + ": not equippable");
        return;
    }
    let slotID: TweakDBID = screen.m_outfitSystem.GetItemSlot(itemID);
    // Another slot was being tried: back to the real look first.
    if IsDefined(screen.m_wtTrying) && screen.m_wtTrySlot != slotID {
        this.WardrobeTabsEndTryOn(screen);
    }
    GameInstance.GetTransactionSystem(puppet.GetGame()).RemoveItemFromSlot(puppet, slotID);
    screen.m_outfitSystem.EquipPuppetItem(puppet, itemID);
    screen.m_wtTrying = item;
    screen.m_wtTrySlot = slotID;
    WardrobeTabsDebug("Trying on " + name + " in " + TDBID.ToStringDEBUG(slotID));
    this.WardrobeTabsRedrawLook(screen);
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsEndTryOn(screen: ref<WardrobeScreenController>) -> Void {
    if !IsDefined(screen.m_wtTrying) && !TDBID.IsValid(screen.m_wtTrySlot) {
        return;
    }
    let puppet: wref<gamePuppet> = this.WardrobeTabsPreviewPuppet(screen);
    if IsDefined(puppet) {
        if screen.m_outfitSystem.IsActive() {
            screen.m_outfitSystem.EquipPuppetOutfit(puppet);
        } else {
            GameInstance.GetTransactionSystem(puppet.GetGame()).RemoveItemFromSlot(puppet, screen.m_wtTrySlot);
        }
    }
    screen.m_wtTrying = null;
    screen.m_wtTrySlot = TDBID.None();
    this.WardrobeTabsRedrawLook(screen);
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeTabsWatch(proxy: ref<inkAnimProxy>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) || !IsDefined(screen.m_inventoryGridDataSource) {
        return false;
    }
    if !screen.m_wtBuilt {
        this.WardrobeTabsBuild(screen);
    }
    this.WardrobeTabsWatchTryOn(screen);
    this.WardrobeTabsWatchLift(screen);
    this.WardrobeTabsWatchSearchClear(screen);
    if this.WardrobeTabsView().m_wtOutfitsSection {
        this.WardrobeTabsWatchOutfits(screen);
    }
    // A freshly populated source starts with slot data this mod has not tagged yet. After
    // WardrobeTabsApply the source holds item data only, which never matches.
    if screen.m_inventoryGridDataSource.GetArraySize() > 0u {
        let first: ref<InventoryGridSlotData> = screen.m_inventoryGridDataSource.GetItem(0u) as InventoryGridSlotData;
        if IsDefined(first) && first.m_wtTab == 0 {
            this.WardrobeTabsCapture(screen);
            return true;
        }
    }
    if ArraySize(screen.m_wtSlots) == 0 {
        return true;
    }

    // Search text and the equipped filter: Equipment-EX already filters the grid; the
    // counts are redone, the selection moves off a slot that no longer has a match, and
    // grouped cards pick a matching colour.
    let typed: String = IsDefined(screen.m_searchInput) ? UTF8StrLower(screen.m_searchInput.GetText()) : "";
    if NotEquals(typed, screen.m_wtTyped) {
        screen.m_wtTyped = typed;
        screen.m_wtTypedTicks = 0;
    } else if screen.m_wtTypedTicks < 1000 {
        screen.m_wtTypedTicks += 1;
    }
    let query: String = screen.m_wtTypedTicks >= WardrobeTabsConfig.SearchSettleTicks() ? typed : screen.m_wtQuery;
    let equippedOnly: Bool = Equals(screen.m_inventoryGridDataView.m_itemFilterType, ItemFilterCategory.Clothes);
    if NotEquals(query, screen.m_wtQuery) || NotEquals(equippedOnly, screen.m_wtEquippedOnly) {
        screen.m_wtQuery = query;
        screen.m_wtEquippedOnly = equippedOnly;
        this.WardrobeTabsFilterChanged(screen);
    }

    // Equipped items changed: the column, the WEARING tags and the cards' colours follow.
    if this.WardrobeTabsWornChanged(screen) && this.WardrobeTabsUpdateWorn(screen) {
        // Equipped items are no longer NEW; the refill below redraws their cards.
        for worn in screen.m_wtWorn {
            if IsDefined(worn) {
                this.WardrobeTabsClearNew(screen, worn.Item.GetID());
            }
        }
        if screen.m_wtEquippedOnly {
            this.WardrobeTabsUpdateMatches(screen);
        }
        this.WardrobeTabsApply(screen, false);
    }
    return true;
}

// Search text, EQUIPPED ONLY or the pack filter changed. The mod filters the grid itself in
// WardrobeTabsApply (Equipment-EX's name search would hide pack-name matches), so its view
// keeps an empty query. Counts and NEW dots are redone, and the selection moves off a slot
// that no longer has a match.
@addMethod(inkPreviewGameController)
private func WardrobeTabsFilterChanged(screen: ref<WardrobeScreenController>) -> Void {
    this.WardrobeTabsUpdateMatches(screen);
    this.WardrobeTabsUpdateNewSlots(screen);
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let selected: Int32 = this.WardrobeTabsSlotIndex(screen, view.m_wtSlot);
    if this.WardrobeTabsFiltering(screen) && (selected < 0 || screen.m_wtMatches[selected] == 0) {
        let index: Int32 = 0;
        while index < ArraySize(screen.m_wtMatches) && screen.m_wtMatches[index] == 0 {
            index += 1;
        }
        if index < ArraySize(screen.m_wtMatches) {
            view.m_wtSlot = screen.m_wtSlots[index].ItemData.SlotID;
            view.m_wtArea = screen.m_wtSlots[index].m_wtTab - 1;
        }
    }
    this.WardrobeTabsRevealChip(screen);
    this.WardrobeTabsApply(screen, true);
}

// A worn item's tile opens its slot; the + tile and a group header show the area's slots.
// A release only counts on the widget the press started on: Enter that confirms a popup on
// press would otherwise land its release on the button under the cursor (SAVE OUTFIT, which
// opened the popup again).
@addMethod(inkPreviewGameController)
protected cb func OnWardrobePress(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if IsDefined(screen) {
        screen.m_wtPressed = evt.GetTarget();
    }
    return false;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsPressedHere(screen: ref<WardrobeScreenController>, evt: ref<inkPointerEvent>) -> Bool {
    if screen.m_wtPressed != evt.GetTarget() {
        return false;
    }
    screen.m_wtPressed = null;
    return true;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeTileClick(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    // Middle mouse is vanilla's unequip_item action.
    let unequip: Bool = evt.IsAction(n"unequip_item");
    if !IsDefined(screen) || !evt.IsAction(n"click") && !unequip {
        return false;
    }
    if !this.WardrobeTabsPressedHere(screen, evt) {
        return false;
    }
    let target: wref<inkWidget> = evt.GetCurrentTarget();
    let tile: Int32 = 0;
    while tile < ArraySize(screen.m_wtTiles) {
        if screen.m_wtTiles[tile] == target {
            let slot: Int32 = screen.m_wtTileSlots[tile];
            if unequip {
                if slot >= 0 && !screen.m_outfitSystem.IsBlocked() {
                    this.PlaySound(n"ItemAdditional", n"OnUnequip");
                    // A listed item may be worn in a slot it was reassigned to; an item read
                    // from the player's slot has only that slot.
                    if IsDefined(screen.m_wtWorn[slot]) {
                        screen.m_outfitSystem.UnequipItem(screen.m_wtWorn[slot].Item.GetID());
                    } else {
                        screen.m_outfitSystem.UnequipSlot(screen.m_wtSlots[slot].ItemData.SlotID);
                    }
                }
                return true;
            }
            this.PlaySound(n"Button", n"OnPress");
            if slot >= 0 {
                this.WardrobeTabsSelect(screen, slot);
            } else {
                if slot == -2 {
                    this.WardrobeTabsSelectArea(screen, tile / WardrobeTabsConfig.GroupTiles());
                }
            }
            return true;
        }
        tile += 1;
    }
    return false;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeGroupClick(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) || !evt.IsAction(n"click") {
        return false;
    }
    if !this.WardrobeTabsPressedHere(screen, evt) {
        return false;
    }
    let target: wref<inkWidget> = evt.GetCurrentTarget();
    let group: Int32 = 0;
    while group < ArraySize(screen.m_wtGroupHeads) {
        if screen.m_wtGroupHeads[group] == target {
            this.PlaySound(n"Button", n"OnPress");
            this.WardrobeTabsSelectArea(screen, group);
            return true;
        }
        group += 1;
    }
    return false;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeButtonClick(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) || !evt.IsAction(n"click") {
        return false;
    }
    if !this.WardrobeTabsPressedHere(screen, evt) {
        return false;
    }
    let target: wref<inkWidget> = evt.GetCurrentTarget();
    let button: Int32 = 0;
    while button < ArraySize(screen.m_wtButtons) && screen.m_wtButtons[button] != target {
        button += 1;
    }
    let count: Int32 = ArraySize(screen.m_wtButtons);
    if button >= count {
        return false;
    }
    this.PlaySound(n"Button", n"OnPress");
    let view: ref<ViewManager> = this.WardrobeTabsView();
    if button <= WardrobeTabsConfig.OtherTab() {
        this.WardrobeTabsSelectArea(screen, button);
    } else if button == 7 {
        // As Equipment-EX's own filter icons do; the watcher sees the change.
        let category: ItemFilterCategory = screen.m_wtEquippedOnly ? ItemFilterCategory.AllItems : ItemFilterCategory.Clothes;
        screen.m_inventoryGridDataView.SetFilterType(category);
        screen.m_inventoryGridDataView.UpdateView();
    } else if button == 8 || button == 9 {
        screen.m_wtChipOffset += (button == 8 ? -1 : 1) * WardrobeTabsConfig.ChipsPerPage();
        this.WardrobeTabsRedraw(screen);
    } else if button == WardrobeTabsConfig.OutfitsButton() {
        view.m_wtOutfitsSection = !view.m_wtOutfitsSection;
        // OUTFITS shows the whole look; BACK returns to the area framed before.
        if view.m_wtOutfitsSection {
            screen.m_wtCameraResume = screen.m_wtCameraArea;
            this.WardrobeTabsCamera(screen, -1);
        } else if screen.m_wtCameraResume > 0 {
            this.WardrobeTabsCamera(screen, screen.m_wtCameraResume - 1);
        }
        this.WardrobeTabsRefresh(screen);
    } else if button == WardrobeTabsConfig.UpdateButton() {
        let linked: CName = screen.m_outfitSystem.m_wtLinked;
        if screen.m_wtLinkChanges >= 0 && this.WardrobeTabsOutfitAccess(screen) {
            screen.m_outfitSystem.SaveOutfit(linked, true);
            WardrobeTabsDebug("Outfit " + NameToString(linked) + " updated from the current look");
            this.WardrobeTabsRedraw(screen);
        }
    } else if button == WardrobeTabsConfig.RevertButton() {
        let linked: CName = screen.m_outfitSystem.m_wtLinked;
        if screen.m_wtLinkChanges >= 0 && this.WardrobeTabsOutfitAccess(screen) {
            screen.m_outfitSystem.LoadOutfit(linked);
        }
    } else if button == WardrobeTabsConfig.SaveOutfitButton() {
        if this.WardrobeTabsOutfitAccess(screen) {
            WardrobeTabsDebug("Save outfit popup opened");
            screen.m_outfitManager.ShowSaveOutfitPopup();
        }
    } else if button == WardrobeTabsConfig.NoOutfitButton() {
        if this.WardrobeTabsOutfitAccess(screen) && screen.m_outfitSystem.IsActive() {
            screen.m_outfitSystem.Deactivate();
        }
    } else if button == WardrobeTabsConfig.PackButton() {
        screen.m_wtPackOpen = !screen.m_wtPackOpen;
        this.WardrobeTabsRedraw(screen);
    } else if button >= WardrobeTabsConfig.ColumnButton(WardrobeTabsConfig.MinColumns()) {
        let columns: Int32 = WardrobeTabsConfig.MinColumns() + button - WardrobeTabsConfig.ColumnButton(WardrobeTabsConfig.MinColumns());
        if columns <= WardrobeTabsConfig.MaxColumns() && columns != WardrobeTabsColumns() {
            this.WardrobeTabsSetColumns(screen, columns);
        }
        this.WardrobeTabsRedraw(screen);
    } else if button > WardrobeTabsConfig.PackButton() {
        let row: Int32 = button - WardrobeTabsConfig.PackButton() - 1;
        screen.m_wtPackOpen = false;
        if row < ArraySize(screen.m_wtPackRowChoice) && screen.m_wtPackRowChoice[row] != view.m_wtPackChoice {
            view.m_wtPackChoice = screen.m_wtPackRowChoice[row];
            WardrobeTabsDebug("Pack filter: " + this.WardrobeTabsPackChoiceName(view.m_wtPackChoice));
            this.WardrobeTabsFilterChanged(screen);
        } else {
            this.WardrobeTabsRedraw(screen);
        }
    } else {
        let chip: Int32 = button - 10;
        if chip >= 0 && chip < ArraySize(screen.m_wtChipSlots) {
            this.WardrobeTabsSelect(screen, screen.m_wtChipSlots[chip]);
        }
    }
    return true;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeTabsHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) {
        return false;
    }
    let target: wref<inkWidget> = evt.GetCurrentTarget();
    if screen.m_wtHover != target {
        screen.m_wtHover = target;
        this.WardrobeTabsRedraw(screen);
    }
    return false;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeTabsHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) {
        return false;
    }
    let target: wref<inkWidget> = evt.GetCurrentTarget();
    if screen.m_wtHover == target {
        screen.m_wtHover = null;
        this.WardrobeTabsRedraw(screen);
    }
    return false;
}

// Outfit cell: click wears the outfit; Equipment-EX's delete key (drop_item) asks to delete
// it. A click on the cell's star is the star's alone.
@addMethod(inkPreviewGameController)
protected cb func OnWardrobeOutfitClick(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) {
        return false;
    }
    // One mouse release arrives as several events, one per input action. Only the click and
    // drop_item ones may use up the press check; v17-v36 checked first, so a release event of
    // another action used it up and the click that followed was ignored.
    let click: Bool = evt.IsAction(n"click");
    if !click && !evt.IsAction(n"drop_item") {
        return false;
    }
    let index: Int32 = this.WardrobeTabsOutfitIndex(screen, evt.GetCurrentTarget());
    if index < 0 || screen.m_wtOutfitStars[index] == evt.GetTarget() {
        return false;
    }
    let name: CName = screen.m_wtOutfitNames[index];
    if click {
        if !this.WardrobeTabsPressedHere(screen, evt) {
            return false;
        }
        if this.WardrobeTabsOutfitAccess(screen) && !screen.m_outfitSystem.IsEquipped(name) {
            this.PlaySound(n"Button", n"OnPress");
            let loaded: Bool = screen.m_outfitSystem.LoadOutfit(name);
            if loaded {
                WardrobeTabsDebug("Outfit " + NameToString(name) + " put on");
            } else {
                ModLog(n"WardrobeTabs", "Outfit " + NameToString(name) + " could not be put on");
            }
        }
        return true;
    }
    // Equipment-EX's delete key (drop_item) needs no press on the cell.
    if this.WardrobeTabsOutfitAccess(screen) {
        screen.m_outfitManager.ShowDeleteOutfitPopup(name);
    }
    return true;
}

// Button hints as on Equipment-EX's outfit list.
@addMethod(inkPreviewGameController)
protected cb func OnWardrobeOutfitHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) {
        return false;
    }
    let target: wref<inkWidget> = evt.GetCurrentTarget();
    let index: Int32 = this.WardrobeTabsOutfitIndex(screen, target);
    screen.m_wtHover = target;
    screen.m_buttonHints.RemoveButtonHint(n"click");
    screen.m_buttonHints.RemoveButtonHint(n"drop_item");
    if index >= 0 {
        screen.m_buttonHints.AddButtonHint(n"drop_item", GetLocalizedTextByKey(n"UI-Wardrobe-Deleteset"));
        if !screen.m_outfitSystem.IsEquipped(screen.m_wtOutfitNames[index]) {
            screen.m_buttonHints.AddButtonHint(n"click", GetLocalizedTextByKey(n"Gameplay-Devices-Interactions-Equip"));
        }
    }
    this.WardrobeTabsStyleOutfits(screen);
    return false;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeOutfitHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) {
        return false;
    }
    if screen.m_wtHover == evt.GetCurrentTarget() {
        screen.m_wtHover = null;
    }
    screen.m_buttonHints.RemoveButtonHint(n"click");
    screen.m_buttonHints.RemoveButtonHint(n"drop_item");
    this.WardrobeTabsStyleOutfits(screen);
    return false;
}

// Star: marks or unmarks the outfit as a favourite; favourites move to the front.
@addMethod(inkPreviewGameController)
protected cb func OnWardrobeStarClick(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) || !evt.IsAction(n"click") {
        return false;
    }
    let index: Int32 = this.WardrobeTabsOutfitIndex(screen, evt.GetCurrentTarget());
    if index < 0 {
        return false;
    }
    if !this.WardrobeTabsPressedHere(screen, evt) {
        return false;
    }
    let name: CName = screen.m_wtOutfitNames[index];
    if ArrayContains(screen.m_outfitSystem.m_wtFavourites, name) {
        ArrayRemove(screen.m_outfitSystem.m_wtFavourites, name);
    } else {
        ArrayPush(screen.m_outfitSystem.m_wtFavourites, name);
    }
    this.PlaySound(n"Button", n"OnPress");
    this.WardrobeTabsShowOutfits(screen);
    this.WardrobeTabsRedraw(screen);
    evt.Handle();
    return true;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeStarHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if IsDefined(screen) {
        screen.m_wtStarHover = evt.GetCurrentTarget();
        this.WardrobeTabsStyleOutfits(screen);
    }
    return false;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeStarHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if IsDefined(screen) && screen.m_wtStarHover == evt.GetCurrentTarget() {
        screen.m_wtStarHover = null;
        this.WardrobeTabsStyleOutfits(screen);
    }
    return false;
}
