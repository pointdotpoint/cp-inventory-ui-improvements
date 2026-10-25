// WardrobeTabs: reorganises the Equipment-EX wardrobe (layout B in prototype/wardrobe-mockups).
// Requires Equipment-EX.
// - Body column, left of V: one group per body area with a tile per worn item and a + tile.
// - Drawer (the item panel): a header with the selected slot's name, a subtitle, search,
//   HEAD..FEET area tabs and GROUP COLOURS / EQUIPPED ONLY toggles; a sidebar left of the
//   grid with the area's slots; the grid as seven-column named cards, one per item family when colours are grouped, with
//   colour dots; and the outfit bar along the bottom (current look, OUTFITS, SAVE AS OUTFIT).
//   Equipment-EX's slot headers and its own header row are hidden. Mouse only.
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
    // display (224 x 202) scaled to 168 x 151.5, then the name and the colour dots.
    public static func CardArtScale() -> Float = 0.75;
    public static func CardArtLeft() -> Float = 12.0;
    public static func CardArtWidth() -> Float = 168.0;
    public static func CardNameTop() -> Float = 160.0;
    public static func CardNameWidth() -> Float = 172.0;
    // Colour grouping (one card per item family, colour dots, GROUP COLOURS toggle) is off:
    // item names follow too many patterns to guess families reliably.
    public static func ColourGrouping() -> Bool = false;
    // Watcher ticks (0.05 s each) the search text must stay unchanged before it filters.
    public static func SearchSettleTicks() -> Int32 = 3;
    public static func CardDots() -> Int32 = 6;
    // Dots sit under a one-line name and end 14 above the next row.
    public static func CardDotSize() -> Float = 18.0;

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

    // Item families are guessed from names: a trailing "(...)" is the colour, as in
    // "NIKE AIR JORDAN 4 (BLACK - BLUE)", else a short tail after the last " - ", as in
    // "APOCALYPSE GLOVE (RIGHT) - BLACK". Anything else is a family of its own.
    public static func FamilyName(name: String) -> String {
        if StrEndsWith(name, ")") && StrFindLast(name, "(") > 0 {
            return WardrobeTabsConfig.TrimEnd(StrBeforeLast(name, "("));
        }
        if StrFindLast(name, " - ") > 0 {
            let tail: String = StrAfterLast(name, " - ");
            if WardrobeTabsConfig.Words(tail) <= 3 {
                return WardrobeTabsConfig.TrimEnd(StrBeforeLast(name, " - "));
            }
        }
        return name;
    }

    public static func VariantName(name: String) -> String {
        if StrEndsWith(name, ")") && StrFindLast(name, "(") > 0 {
            let inner: String = StrAfterLast(name, "(");
            return StrLeft(inner, StrLen(inner) - 1);
        }
        if StrFindLast(name, " - ") > 0 {
            let tail: String = StrAfterLast(name, " - ");
            if WardrobeTabsConfig.Words(tail) <= 3 {
                return tail;
            }
        }
        return name;
    }

    public static func Words(text: String) -> Int32 {
        let count: Int32 = 1;
        let rest: String = text;
        while StrFindFirst(rest, " ") >= 0 {
            rest = StrAfterFirst(rest, " ");
            count += 1;
        }
        return count;
    }

    public static func TrimEnd(text: String) -> String {
        let result: String = text;
        while StrLen(result) > 0 && (StrEndsWith(result, " ") || StrEndsWith(result, "-")) {
            result = StrLeft(result, StrLen(result) - 1);
        }
        return result;
    }

    // Dot colour from the first colour word in a variant name; grey when there is none.
    public static func VariantColor(variant: String) -> HDRColor {
        let text: String = UTF8StrLower(variant);
        let best: Int32 = 1000000;
        let color: HDRColor = new HDRColor(0.55, 0.52, 0.54, 1.0);
        let at: Int32;
        at = StrFindFirst(text, "black"); if at >= 0 && at < best { best = at; color = new HDRColor(0.10, 0.10, 0.11, 1.0); }
        at = StrFindFirst(text, "white"); if at >= 0 && at < best { best = at; color = new HDRColor(0.92, 0.92, 0.92, 1.0); }
        at = StrFindFirst(text, "red"); if at >= 0 && at < best { best = at; color = new HDRColor(0.80, 0.16, 0.18, 1.0); }
        at = StrFindFirst(text, "blue"); if at >= 0 && at < best { best = at; color = new HDRColor(0.20, 0.40, 0.90, 1.0); }
        at = StrFindFirst(text, "green"); if at >= 0 && at < best { best = at; color = new HDRColor(0.25, 0.75, 0.30, 1.0); }
        at = StrFindFirst(text, "pink"); if at >= 0 && at < best { best = at; color = new HDRColor(0.95, 0.45, 0.70, 1.0); }
        at = StrFindFirst(text, "purple"); if at >= 0 && at < best { best = at; color = new HDRColor(0.55, 0.30, 0.85, 1.0); }
        at = StrFindFirst(text, "yellow"); if at >= 0 && at < best { best = at; color = new HDRColor(0.95, 0.85, 0.20, 1.0); }
        at = StrFindFirst(text, "orange"); if at >= 0 && at < best { best = at; color = new HDRColor(0.95, 0.55, 0.15, 1.0); }
        at = StrFindFirst(text, "gold"); if at >= 0 && at < best { best = at; color = new HDRColor(0.85, 0.68, 0.25, 1.0); }
        at = StrFindFirst(text, "silver"); if at >= 0 && at < best { best = at; color = new HDRColor(0.78, 0.80, 0.84, 1.0); }
        at = StrFindFirst(text, "chrome"); if at >= 0 && at < best { best = at; color = new HDRColor(0.78, 0.80, 0.84, 1.0); }
        at = StrFindFirst(text, "grey"); if at >= 0 && at < best { best = at; color = new HDRColor(0.50, 0.50, 0.52, 1.0); }
        at = StrFindFirst(text, "gray"); if at >= 0 && at < best { best = at; color = new HDRColor(0.50, 0.50, 0.52, 1.0); }
        at = StrFindFirst(text, "brown"); if at >= 0 && at < best { best = at; color = new HDRColor(0.45, 0.28, 0.16, 1.0); }
        at = StrFindFirst(text, "beige"); if at >= 0 && at < best { best = at; color = new HDRColor(0.85, 0.78, 0.64, 1.0); }
        at = StrFindFirst(text, "cream"); if at >= 0 && at < best { best = at; color = new HDRColor(0.90, 0.86, 0.74, 1.0); }
        at = StrFindFirst(text, "teal"); if at >= 0 && at < best { best = at; color = new HDRColor(0.16, 0.65, 0.63, 1.0); }
        at = StrFindFirst(text, "cyan"); if at >= 0 && at < best { best = at; color = new HDRColor(0.30, 0.90, 0.95, 1.0); }
        at = StrFindFirst(text, "camo"); if at >= 0 && at < best { best = at; color = new HDRColor(0.40, 0.44, 0.29, 1.0); }
        at = StrFindFirst(text, "olive"); if at >= 0 && at < best { best = at; color = new HDRColor(0.40, 0.44, 0.29, 1.0); }
        at = StrFindFirst(text, "navy"); if at >= 0 && at < best { best = at; color = new HDRColor(0.12, 0.16, 0.40, 1.0); }
        return color;
    }
}

// The items of one family in one slot, in Equipment-EX's order. Items point back with a weak
// ref; the screen keeps families alive.
public class WardrobeTabsFamily {
    public let name: String;
    public let items: array<wref<InventoryGridItemData>>;
    public let variants: array<String>;
    // Set while the grid shows this family as one card.
    public let grouped: Bool;
    public let stamp: Int32;
}

// Sent by a card's colour dot to the wardrobe screen.
public class WardrobeTabsVariantEvent extends Event {
    public let item: wref<InventoryGridItemData>;
}

// Kept on the view manager so the choices survive closing the wardrobe.
@addField(ViewManager)
public let m_wtOutfitsSection: Bool;

@addField(ViewManager)
public let m_wtSlot: TweakDBID;

@addField(ViewManager)
public let m_wtArea: Int32;

// Colours are grouped unless this is set.
@addField(ViewManager)
public let m_wtUngrouped: Bool;

// Area index + 1, resolved once per slot. 0 marks slot data the mod has not seen yet,
// which is how a repopulated grid is recognised.
@addField(InventoryGridSlotData)
public let m_wtTab: Int32;

@addField(InventoryGridItemData)
public let m_wtFamily: wref<WardrobeTabsFamily>;

@addField(WardrobeScreenController)
public let m_wtBuilt: Bool;

@addField(WardrobeScreenController)
public let m_wtAllItems: array<ref<IScriptable>>;

@addField(WardrobeScreenController)
public let m_wtFamilies: array<ref<WardrobeTabsFamily>>;

@addField(WardrobeScreenController)
public let m_wtStamp: Int32;

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

// Buttons: area tabs (0..5), GROUP COLOURS (6), EQUIPPED ONLY (7), chip paging (8, 9),
// slot chips (10..), SAVE AS OUTFIT and OUTFITS (last two). Each has a background, a
// label and an optional count.
@addField(WardrobeScreenController)
public let m_wtButtons: array<wref<inkCanvas>>;

@addField(WardrobeScreenController)
public let m_wtButtonBgs: array<wref<inkRectangle>>;

@addField(WardrobeScreenController)
public let m_wtButtonTexts: array<wref<inkText>>;

@addField(WardrobeScreenController)
public let m_wtButtonCounts: array<wref<inkText>>;

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
    let grid: ref<inkWidget> = this.SpawnFromExternal(area, r"wardrobe_tabs\\gui\\grid.inkwidget", n"Root");
    if IsDefined(grid) && IsDefined(grid.GetController() as inkVirtualGridController) {
        area.RemoveChild(original);
        grid.SetName(n"vendor_virtualgrid");
        grid.SetMargin(new inkMargin(0.0, 0.0, 0.0, WardrobeTabsConfig.BarHeight() + 10.0));
        ModLog(n"WardrobeTabs", "Card grid v3 installed before data binding (7 columns, 192 x 216 cells)");
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
        widget.SetMargin(new inkMargin(WardrobeTabsConfig.CardArtLeft(), 4.0, 0.0, 0.0));
        widget.SetRenderTransformPivot(new Vector2(0.0, 0.0));
        widget.SetScale(new Vector2(WardrobeTabsConfig.CardArtScale(), WardrobeTabsConfig.CardArtScale()));
    }
    return wrappedMethod(widget, userData);
}

// Card cells are recycled while scrolling: name, WEARING tag and dots follow the data.
@wrapMethod(VendorItemVirtualController)
public final func OnDataChanged(value: Variant) -> Void {
    wrappedMethod(value);
    if IsDefined(this as InventoryGridItemController) && Equals(this.GetRootWidget().GetName(), n"wardrobeCardItem") {
        this.WardrobeTabsDecorateCard();
    }
}

@addMethod(VendorItemVirtualController)
private func WardrobeTabsCardFamily() -> wref<WardrobeTabsFamily> {
    let data: ref<InventoryGridItemData> = this.m_newData as InventoryGridItemData;
    if !IsDefined(data) || !IsDefined(data.m_wtFamily) || !data.m_wtFamily.grouped || ArraySize(data.m_wtFamily.items) < 2 {
        return null;
    }
    return data.m_wtFamily;
}

@addMethod(VendorItemVirtualController)
private func WardrobeTabsDecorateCard() -> Void {
    let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
    if !IsDefined(root) {
        return;
    }
    let left: Float = WardrobeTabsConfig.CardArtLeft() + 2.0;
    let label: ref<inkText> = root.GetWidget(n"wardrobeCardName") as inkText;
    if !IsDefined(label) {
        label = new inkText();
        label.SetName(n"wardrobeCardName");
        label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        label.SetLetterCase(textLetterCase.UpperCase);
        label.SetFontSize(20);
        label.SetAnchor(inkEAnchor.TopLeft);
        label.SetFitToContent(false);
        label.SetMargin(new inkMargin(left, WardrobeTabsConfig.CardNameTop(), 0.0, 0.0));
        label.SetWrapping(true, WardrobeTabsConfig.CardNameWidth());
        label.SetOverflowPolicy(textOverflowPolicy.DotsEndLastLine);
        label.SetInteractive(false);
        label.Reparent(root);

        let tag: ref<inkCanvas> = new inkCanvas();
        tag.SetName(n"wardrobeCardTag");
        tag.SetAnchor(inkEAnchor.TopLeft);
        tag.SetSize(84.0, 24.0);
        tag.SetMargin(new inkMargin(WardrobeTabsConfig.CardArtLeft() + WardrobeTabsConfig.CardArtWidth() - 90.0, 9.0, 0.0, 0.0));
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
        tagText.SetFontSize(16);
        tagText.SetText("WEARING");
        tagText.SetAnchor(inkEAnchor.Centered);
        tagText.SetAnchorPoint(0.5, 0.5);
        tagText.SetTintColor(new HDRColor(0.02, 0.03, 0.04, 1.0));
        tagText.SetInteractive(false);
        tagText.Reparent(tag);

        let dots: ref<inkCanvas> = new inkCanvas();
        dots.SetName(n"wardrobeCardDots");
        dots.SetAnchor(inkEAnchor.TopLeft);
        dots.SetSize(WardrobeTabsConfig.CardNameWidth(), 24.0);
        dots.SetMargin(new inkMargin(left, WardrobeTabsConfig.CardNameTop() + 26.0, 0.0, 0.0));
        dots.childOrder = inkEChildOrder.Forward;
        dots.Reparent(root);
        let index: Int32 = 0;
        while index < WardrobeTabsConfig.CardDots() {
            let dot: ref<inkCanvas> = new inkCanvas();
            dot.SetAnchor(inkEAnchor.TopLeft);
            dot.SetSize(WardrobeTabsConfig.CardDotSize(), WardrobeTabsConfig.CardDotSize());
            dot.SetMargin(new inkMargin(Cast<Float>(index) * (WardrobeTabsConfig.CardDotSize() + 6.0), 0.0, 0.0, 0.0));
            dot.childOrder = inkEChildOrder.Forward;
            dot.SetInteractive(true);
            dot.RegisterToCallback(n"OnRelease", this, n"OnWardrobeDotClick");
            dot.RegisterToCallback(n"OnHoverOver", this, n"OnWardrobeDotHoverOver");
            dot.RegisterToCallback(n"OnHoverOut", this, n"OnWardrobeDotHoverOut");
            dot.Reparent(dots);
            let ring: ref<inkRectangle> = new inkRectangle();
            ring.SetAnchor(inkEAnchor.Fill);
            ring.SetTintColor(new HDRColor(0.369, 0.965, 1.0, 1.0));
            ring.SetInteractive(false);
            ring.Reparent(dot);
            let fill: ref<inkRectangle> = new inkRectangle();
            fill.SetAnchor(inkEAnchor.Fill);
            fill.SetMargin(new inkMargin(3.0, 3.0, 3.0, 3.0));
            fill.SetInteractive(false);
            fill.Reparent(dot);
            index += 1;
        }
        let more: ref<inkText> = new inkText();
        more.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        more.SetFontSize(16);
        more.SetAnchor(inkEAnchor.TopLeft);
        more.SetMargin(new inkMargin(Cast<Float>(WardrobeTabsConfig.CardDots()) * (WardrobeTabsConfig.CardDotSize() + 6.0), -2.0, 0.0, 0.0));
        more.SetTintColor(new HDRColor(0.682, 0.231, 0.212, 1.0));
        more.SetInteractive(false);
        more.Reparent(dots);
    }
    let tag: ref<inkWidget> = root.GetWidget(n"wardrobeCardTag");
    let dots: ref<inkCompoundWidget> = root.GetWidget(n"wardrobeCardDots") as inkCompoundWidget;
    let data: ref<InventoryGridItemData> = this.m_newData as InventoryGridItemData;
    if !IsDefined(data) {
        label.SetText("");
        tag.SetVisible(false);
        dots.SetVisible(false);
        return;
    }
    let family: wref<WardrobeTabsFamily> = this.WardrobeTabsCardFamily();
    let wearing: Bool = data.Item.IsEquipped();
    if IsDefined(family) {
        for item in family.items {
            if IsDefined(item) && item.Item.IsEquipped() {
                wearing = true;
            }
        }
    }
    tag.SetVisible(wearing);
    label.SetText(IsDefined(family) ? family.name : WardrobeTabsConfig.ItemName(data));
    label.SetWrapping(!IsDefined(family), WardrobeTabsConfig.CardNameWidth());
    label.SetSize(WardrobeTabsConfig.CardNameWidth(), IsDefined(family) ? 24.0 : 50.0);
    label.SetTintColor(wearing ? new HDRColor(0.369, 0.965, 1.0, 1.0) : new HDRColor(1.176, 0.381, 0.348, 1.0));
    dots.SetVisible(IsDefined(family));
    if IsDefined(family) {
        let count: Int32 = ArraySize(family.items);
        let index: Int32 = 0;
        while index < WardrobeTabsConfig.CardDots() {
            let dot: ref<inkCompoundWidget> = dots.GetWidgetByIndex(index) as inkCompoundWidget;
            dot.SetVisible(index < count);
            if index < count {
                let item: wref<InventoryGridItemData> = family.items[index];
                dot.GetWidgetByIndex(0).SetVisible(IsDefined(item) && item.Item.IsEquipped());
                dot.GetWidgetByIndex(1).SetTintColor(WardrobeTabsConfig.VariantColor(family.variants[index]));
            }
            index += 1;
        }
        let more: ref<inkText> = dots.GetWidgetByIndex(WardrobeTabsConfig.CardDots()) as inkText;
        more.SetText(count > WardrobeTabsConfig.CardDots() ? "+" + ToString(count - WardrobeTabsConfig.CardDots()) : "");
    }
}

@addMethod(VendorItemVirtualController)
private func WardrobeTabsDotIndex(target: wref<inkWidget>) -> Int32 {
    let dots: ref<inkCompoundWidget> = this.GetRootCompoundWidget().GetWidget(n"wardrobeCardDots") as inkCompoundWidget;
    let index: Int32 = 0;
    while index < WardrobeTabsConfig.CardDots() {
        if dots.GetWidgetByIndex(index) == target {
            return index;
        }
        index += 1;
    }
    return -1;
}

@addMethod(VendorItemVirtualController)
protected cb func OnWardrobeDotClick(evt: ref<inkPointerEvent>) -> Bool {
    let family: wref<WardrobeTabsFamily> = this.WardrobeTabsCardFamily();
    let index: Int32 = this.WardrobeTabsDotIndex(evt.GetCurrentTarget());
    if !evt.IsAction(n"click") || !IsDefined(family) || index < 0 || index >= ArraySize(family.items) {
        return false;
    }
    let request: ref<WardrobeTabsVariantEvent> = new WardrobeTabsVariantEvent();
    request.item = family.items[index];
    this.QueueEvent(request);
    evt.Handle();
    return true;
}

// Hovering a dot shows its colour's name in place of the family name.
@addMethod(VendorItemVirtualController)
protected cb func OnWardrobeDotHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    let family: wref<WardrobeTabsFamily> = this.WardrobeTabsCardFamily();
    let index: Int32 = this.WardrobeTabsDotIndex(evt.GetCurrentTarget());
    if IsDefined(family) && index >= 0 && index < ArraySize(family.variants) {
        let label: ref<inkText> = this.GetRootCompoundWidget().GetWidget(n"wardrobeCardName") as inkText;
        label.SetText(family.variants[index]);
    }
    return false;
}

@addMethod(VendorItemVirtualController)
protected cb func OnWardrobeDotHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    let family: wref<WardrobeTabsFamily> = this.WardrobeTabsCardFamily();
    if IsDefined(family) {
        let label: ref<inkText> = this.GetRootCompoundWidget().GetWidget(n"wardrobeCardName") as inkText;
        label.SetText(family.name);
    }
    return false;
}

@wrapMethod(inkPreviewGameController)
protected cb func OnUninitialize() -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if IsDefined(screen) {
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
        ArrayClear(screen.m_wtFamilies);
        ArrayClear(screen.m_wtClothingOnly);
        ArrayClear(screen.m_wtGroupHeads);
        ArrayClear(screen.m_wtTiles);
        ArrayClear(screen.m_wtButtons);
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
    ArrayPush(screen.m_wtButtons, button);
    ArrayPush(screen.m_wtButtonBgs, bg);
    ArrayPush(screen.m_wtButtonTexts, label);
    ArrayPush(screen.m_wtButtonCounts, count);
    return button;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsBuild(screen: ref<WardrobeScreenController>) -> Void {
    screen.m_wtBuilt = true;
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
        grid.SetSize(WardrobeTabsConfig.ContainerWidth() + gridLeft, grid.GetSize().Y);
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
    host.SetSize(1352.0, 1414.0);
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
            list.SetSize(1352.0, 1414.0 - WardrobeTabsConfig.BarHeight() - 30.0);
        }
    }

    let preview: ref<inkWidget> = this.GetChildWidgetByPath(n"wrapper/preview");
    if IsDefined(preview) {
        preview.SetTranslation(WardrobeTabsConfig.PreviewShift(), 0.0);
    }
    // PreviewPoses' zoom collider (PreviewZoom.reds) follows V, clear of the drawer.
    let collider: ref<inkWidget> = this.GetChildWidgetByPath(n"previewZoomCollider");
    if IsDefined(collider) {
        collider.SetTranslation(WardrobeTabsConfig.PreviewShift(), 0.0);
    }

    ArrayClear(screen.m_wtButtons);
    ArrayClear(screen.m_wtButtonBgs);
    ArrayClear(screen.m_wtButtonTexts);
    ArrayClear(screen.m_wtButtonCounts);
    this.WardrobeTabsBuildHeader(screen, header, headerWrapper);
    if IsDefined(grid) {
        this.WardrobeTabsBuildSidebar(screen, grid);
        this.WardrobeTabsBuildBar(screen, grid);
    }
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
    ModLog(n"WardrobeTabs", "Body column and drawer v9 built");
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
    // Kept as button 6 so the indices below stay put; hidden while grouping is off.
    let groupColours: ref<inkCanvas> = this.WardrobeTabsMakeButton(screen, overlay, "GROUP COLOURS", width - 620.0, 148.0, 300.0, 62.0);
    if WardrobeTabsConfig.ColourGrouping() {
        ArrayPush(screen.m_wtClothingOnly, groupColours);
    } else {
        groupColours.SetVisible(false);
    }
    ArrayPush(screen.m_wtClothingOnly, this.WardrobeTabsMakeButton(screen, overlay, "EQUIPPED ONLY", width - 310.0, 148.0, 300.0, 62.0));
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
    let look: ref<inkText> = this.WardrobeTabsMakeText(26, 640.0);
    look.SetMargin(new inkMargin(24.0, 66.0, 0.0, 0.0));
    look.SetTintColor(new HDRColor(0.682, 0.231, 0.212, 1.0));
    look.Reparent(bar);
    screen.m_wtLook = look;
    // OUTFITS, then SAVE AS OUTFIT: the last two buttons.
    this.WardrobeTabsMakeButton(screen, bar, "OUTFITS", width - 380.0 - 280.0, 22.0, 260.0, 76.0);
    this.WardrobeTabsMakeButton(screen, bar, "SAVE AS OUTFIT", width - 380.0, 22.0, 356.0, 76.0);
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

// Splits a freshly populated source into its slots and tags each slot with its area.
@addMethod(inkPreviewGameController)
private func WardrobeTabsCapture(screen: ref<WardrobeScreenController>) -> Void {
    screen.m_wtAllItems = screen.m_inventoryGridDataSource.GetArray();
    ArrayClear(screen.m_wtSlots);
    ArrayClear(screen.m_wtFamilies);
    for entry in screen.m_wtAllItems {
        let slot: ref<InventoryGridSlotData> = entry as InventoryGridSlotData;
        if IsDefined(slot) {
            if slot.m_wtTab == 0 {
                slot.m_wtTab = WardrobeTabsConfig.TabOfSlot(slot.ItemData.SlotID) + 1;
            }
            ArrayPush(screen.m_wtSlots, slot);
        }
    }
    this.WardrobeTabsUpdateWorn(screen);
    this.WardrobeTabsUpdateMatches(screen);
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
                    ModLog(n"WardrobeTabs", screen.m_wtSlots[at].ItemData.CategoryName + ": worn item added to the item list: " + WardrobeTabsConfig.ItemName(added));
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
        ModLog(n"WardrobeTabs", "Worn items not in the item lists, shown from their slots: " + log);
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
    if NotEquals(screen.m_wtQuery, "") {
        if !item.m_wtSearchReady {
            item.m_wtSearchName = UTF8StrLower(GetLocalizedText(item.Item.m_data.Name));
            item.m_wtSearchReady = true;
        }
        return StrContains(item.m_wtSearchName, screen.m_wtQuery);
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
    return screen.m_wtEquippedOnly || NotEquals(screen.m_wtQuery, "");
}

// Shows the selected slot's items in the grid: every item, or one card per family with
// the worn colour (else the first matching one) standing for the rest. Excluding the slot
// data drops its header; clearing IsCollapsed keeps its items visible whatever Equipment-EX
// remembers for it. Without a scroll reset the position is kept across the rebuild.
@addMethod(inkPreviewGameController)
private func WardrobeTabsApply(screen: ref<WardrobeScreenController>, resetScroll: Bool) -> Void {
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let index: Int32 = this.WardrobeTabsSlotIndex(screen, view.m_wtSlot);
    let grouped: Bool = WardrobeTabsConfig.ColourGrouping() && !view.m_wtUngrouped;
    let kept: array<ref<IScriptable>>;
    screen.m_wtStamp += 1;
    if index >= 0 {
        let slot: ref<InventoryGridSlotData> = screen.m_wtSlots[index];
        slot.IsCollapsed = false;
        if grouped {
            this.WardrobeTabsBuildFamilies(screen, slot);
        }
        for child in slot.Children {
            let family: wref<WardrobeTabsFamily> = child.m_wtFamily;
            if !grouped || !IsDefined(family) || ArraySize(family.items) < 2 {
                if IsDefined(family) { family.grouped = false; }
                ArrayPush(kept, child);
            } else {
                if family.stamp != screen.m_wtStamp {
                    family.stamp = screen.m_wtStamp;
                    family.grouped = true;
                    ArrayPush(kept, this.WardrobeTabsRepresentative(screen, family));
                }
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

// Sorts one slot's items into families, from the names they have now. Only the shown slot
// needs families; other slots' items keep stale links that nothing reads.
@addMethod(inkPreviewGameController)
private func WardrobeTabsBuildFamilies(screen: ref<WardrobeScreenController>, slot: ref<InventoryGridSlotData>) -> Void {
    ArrayClear(screen.m_wtFamilies);
    let families: ref<inkHashMap> = new inkHashMap();
    let largest: Int32 = 0;
    let example: String = "";
    for child in slot.Children {
        let name: String = WardrobeTabsConfig.ItemName(child);
        let familyName: String = WardrobeTabsConfig.FamilyName(name);
        let key: Uint64 = NameToHash(StringToName(UTF8StrLower(familyName)));
        let family: ref<WardrobeTabsFamily> = families.Get(key) as WardrobeTabsFamily;
        if !IsDefined(family) {
            family = new WardrobeTabsFamily();
            family.name = familyName;
            families.Insert(key, family);
            ArrayPush(screen.m_wtFamilies, family);
        }
        ArrayPush(family.items, child);
        ArrayPush(family.variants, WardrobeTabsConfig.VariantName(name));
        child.m_wtFamily = family;
        if ArraySize(family.items) > largest {
            largest = ArraySize(family.items);
            example = familyName;
        }
    }
    ModLog(n"WardrobeTabs", slot.ItemData.CategoryName + ": " + ToString(ArraySize(slot.Children)) + " items in "
        + ToString(ArraySize(screen.m_wtFamilies)) + " families; largest \"" + example + "\" (" + ToString(largest) + ")");
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsRepresentative(screen: ref<WardrobeScreenController>, family: wref<WardrobeTabsFamily>) -> ref<InventoryGridItemData> {
    let first: ref<InventoryGridItemData>;
    for item in family.items {
        if IsDefined(item) && this.WardrobeTabsMatches(screen, item) {
            if item.Item.IsEquipped() {
                return item;
            }
            if !IsDefined(first) {
                first = item;
            }
        }
    }
    if IsDefined(first) {
        return first;
    }
    let fallback: ref<InventoryGridItemData> = family.items[0];
    return fallback;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsRedraw(screen: ref<WardrobeScreenController>) -> Void {
    let selected: Int32 = this.WardrobeTabsSlotIndex(screen, this.WardrobeTabsView().m_wtSlot);
    this.WardrobeTabsRedrawBody(screen, selected);
    this.WardrobeTabsRedrawHeader(screen, selected);
    this.WardrobeTabsRedrawButtons(screen, selected);
    this.WardrobeTabsRedrawLook(screen);
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
// share matching a search or filter, and what is worn there.
@addMethod(inkPreviewGameController)
private func WardrobeTabsRedrawHeader(screen: ref<WardrobeScreenController>, selected: Int32) -> Void {
    if !IsDefined(screen.m_wtTitle) {
        return;
    }
    let view: ref<ViewManager> = this.WardrobeTabsView();
    if view.m_wtOutfitsSection {
        let names: array<CName> = screen.m_outfitSystem.GetOutfits();
        let saved: Int32 = ArraySize(names);
        screen.m_wtTitle.SetText("OUTFITS");
        screen.m_wtSubtitle.SetText(ToString(saved) + (saved == 1 ? " SAVED OUTFIT" : " SAVED OUTFITS"));
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
    let text: String;
    if WardrobeTabsConfig.ColourGrouping() && !view.m_wtUngrouped {
        screen.m_wtStamp += 1;
        let families: Int32 = 0;
        for child in slot.Children {
            if IsDefined(child.m_wtFamily) && child.m_wtFamily.stamp != screen.m_wtStamp {
                child.m_wtFamily.stamp = screen.m_wtStamp;
                families += 1;
            }
        }
        text = ToString(families) + " ITEMS IN " + ToString(total) + " COLOURS";
    } else {
        text = ToString(total) + " ITEMS";
    }
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
    // Header, sidebar and bar buttons all exist only when the grid container was found.
    if buttons < 10 + WardrobeTabsConfig.ChipsPerPage() + 2 {
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
        screen.m_wtButtons[area].SetOpacity(ArraySize(slots) > 0 ? 1.0 : 0.4);
        this.WardrobeTabsStyleButton(screen, area, area == view.m_wtArea);
        area += 1;
    }
    this.WardrobeTabsStyleButton(screen, 6, !view.m_wtUngrouped);
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
        if entry < ArraySize(slots) {
            let index: Int32 = slots[entry];
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
    // Bar: OUTFITS (with the saved count) and SAVE AS OUTFIT.
    let outfits: Int32 = buttons - 2;
    let saved: array<CName> = screen.m_outfitSystem.GetOutfits();
    screen.m_wtButtonTexts[outfits].SetText("OUTFITS (" + ToString(ArraySize(saved)) + ")");
    this.WardrobeTabsStyleButton(screen, outfits, !clothing);
    this.WardrobeTabsStyleButton(screen, buttons - 1, false);
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

// "Saved as <outfit>" when the worn items match a saved outfit.
@addMethod(inkPreviewGameController)
private func WardrobeTabsRedrawLook(screen: ref<WardrobeScreenController>) -> Void {
    if !IsDefined(screen.m_wtLook) {
        return;
    }
    let outfits: array<CName> = screen.m_outfitSystem.GetOutfits();
    for outfit in outfits {
        if screen.m_outfitSystem.IsEquipped(outfit) {
            screen.m_wtLook.SetText("SAVED AS " + NameToString(outfit));
            return;
        }
    }
    screen.m_wtLook.SetText(ArraySize(outfits) == 0 ? "NO SAVED OUTFITS YET" : "NOT SAVED AS AN OUTFIT");
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
    let selected: Int32 = this.WardrobeTabsSlotIndex(screen, view.m_wtSlot);
    if ArrayContains(slots, selected) && !view.m_wtOutfitsSection {
        view.m_wtArea = area;
        this.WardrobeTabsRevealChip(screen);
        this.WardrobeTabsRedraw(screen);
        return;
    }
    this.WardrobeTabsSelect(screen, slots[0]);
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
        let searchOnly: Bool = NotEquals(query, screen.m_wtQuery) && Equals(equippedOnly, screen.m_wtEquippedOnly);
        if NotEquals(query, screen.m_wtQuery) && screen.m_wtSearchOwned {
            screen.m_inventoryGridDataView.SetSearchQuery(query);
        }
        screen.m_wtQuery = query;
        screen.m_wtEquippedOnly = equippedOnly;
        this.WardrobeTabsUpdateMatches(screen);
        let view: ref<ViewManager> = this.WardrobeTabsView();
        let selected: Int32 = this.WardrobeTabsSlotIndex(screen, view.m_wtSlot);
        let moved: Bool = false;
        if this.WardrobeTabsFiltering(screen) && (selected < 0 || screen.m_wtMatches[selected] == 0) {
            let index: Int32 = 0;
            while index < ArraySize(screen.m_wtMatches) && screen.m_wtMatches[index] == 0 {
                index += 1;
            }
            if index < ArraySize(screen.m_wtMatches) {
                view.m_wtSlot = screen.m_wtSlots[index].ItemData.SlotID;
                view.m_wtArea = screen.m_wtSlots[index].m_wtTab - 1;
                moved = true;
            }
        }
        this.WardrobeTabsRevealChip(screen);
        if searchOnly && !moved {
            // Same slot: the grid already holds its items, so filtering them is enough
            // (no refill, which rebinds every card).
            if screen.m_wtSearchOwned {
                screen.m_inventoryGridDataView.UpdateView();
            }
            screen.m_inventoryScrollController.SetScrollPosition(0.0);
            this.WardrobeTabsRedraw(screen);
        } else {
            this.WardrobeTabsApply(screen, true);
        }
    }

    // Equipped items changed: the column, the WEARING tags and the cards' colours follow.
    if this.WardrobeTabsWornChanged(screen) && this.WardrobeTabsUpdateWorn(screen) {
        if screen.m_wtEquippedOnly {
            this.WardrobeTabsUpdateMatches(screen);
        }
        this.WardrobeTabsApply(screen, false);
    }
    return true;
}

// Colour dot on a card: equip that colour.
@addMethod(inkPreviewGameController)
protected cb func OnWardrobeTabsVariant(evt: ref<WardrobeTabsVariantEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) || !IsDefined(evt.item) || screen.m_outfitSystem.IsBlocked() {
        return false;
    }
    let itemID: ItemID = evt.item.Item.GetID();
    if !screen.m_outfitSystem.IsEquipped(itemID) {
        this.PlaySound(n"Button", n"OnPress");
        screen.m_outfitSystem.EquipItem(itemID);
    }
    return true;
}

// A worn item's tile opens its slot; the + tile and a group header show the area's slots.
@addMethod(inkPreviewGameController)
protected cb func OnWardrobeTileClick(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    // Middle mouse is vanilla's unequip_item action.
    let unequip: Bool = evt.IsAction(n"unequip_item");
    if !IsDefined(screen) || !evt.IsAction(n"click") && !unequip {
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
    } else if button == 6 && WardrobeTabsConfig.ColourGrouping() {
        view.m_wtUngrouped = !view.m_wtUngrouped;
        this.WardrobeTabsApply(screen, true);
    } else if button == 7 {
        // As Equipment-EX's own filter icons do; the watcher sees the change.
        let category: ItemFilterCategory = screen.m_wtEquippedOnly ? ItemFilterCategory.AllItems : ItemFilterCategory.Clothes;
        screen.m_inventoryGridDataView.SetFilterType(category);
        screen.m_inventoryGridDataView.UpdateView();
    } else if button == 8 || button == 9 {
        screen.m_wtChipOffset += (button == 8 ? -1 : 1) * WardrobeTabsConfig.ChipsPerPage();
        this.WardrobeTabsRedraw(screen);
    } else if button == count - 2 {
        view.m_wtOutfitsSection = !view.m_wtOutfitsSection;
        this.WardrobeTabsRefresh(screen);
    } else if button == count - 1 {
        screen.m_outfitManager.ShowSaveOutfitPopup();
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
