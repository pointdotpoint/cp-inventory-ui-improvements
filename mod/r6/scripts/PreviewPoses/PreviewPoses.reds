// PreviewPoses: lets V's preview on the inventory and wardrobe screens take photo mode poses.
// A POSES button opens a panel on the right of the current screen: pose packs and animation
// packs in a rail on the left, the selected pack's poses as a paged grid on the right, and a
// search box over both. Picking a pose applies it immediately and leaves the panel open.
// The preview already on screen is reused.
//
// The patched player_paperdoll.animgraph (built by tools/build_pose_graph.py) has a switch
// below its Output node that reads the anim feature "WardrobePose". Index 0 is the vanilla
// pose; 1..N follow the list in tools/poses_female.txt, loaded from PreviewPoses.list tweaks.
// PreviewPoses.archive.xl attaches those animation sets to the player templates.
//
// The selector lives in the screen's own widget tree, not in the preview's: the preview panel
// draws V's render over anything placed inside it.

import Codeware.UI.*

public class AnimFeature_WardrobePose extends AnimFeature {
    public let pose: Float;
}

public class PreviewPosePack {
    public let poses: array<Int32>;
}

// Remembers the chosen pose and links the selector to whichever preview is currently open.
// The choice is stored in the save game by animation name, so it survives game restarts
// (once the game has been saved) and changes to the order of the pose list.
//
// Everything here is instance code on purpose: static functions returning arrays from a
// helper class came back empty in game in this setup.
public class PreviewPosesState extends ScriptableSystem {
    public let m_pose: Int32;
    private persistent let m_savedAnimation: CName;
    // Framing per screen (see PreviewView.reds). Plain persistent values: a persistent
    // reference to a helper object crashed the script compiler here.
    public persistent let m_invViewValid: Bool;
    public persistent let m_invZoomValid: Bool;
    public persistent let m_invZoom: Int32;
    public persistent let m_invLeft: Float;
    public persistent let m_invTop: Float;
    public persistent let m_invRotationValid: Bool;
    public persistent let m_invYaw: Float;
    public persistent let m_invPreviewHidden: Bool;
    public persistent let m_wardViewValid: Bool;
    public persistent let m_wardZoom: Int32;
    public persistent let m_wardLeft: Float;
    public persistent let m_wardTop: Float;
    // Unused legacy facing selector. Inventory now stores continuous yaw separately.
    // Kept so saves that stored it load unchanged.
    public persistent let m_facing: Int32;
    public let m_inventory: wref<gameuiInventoryGameController>;
    private let m_restored: Bool;
    public let m_preview: wref<inkPuppetPreviewGameController>;
    public let m_inventoryPreview: wref<inkPuppetPreviewGameController>;
    // The inventory's puppet preview, whose camera the wardrobe zooms too (PreviewZoom.reds).
    public let m_cameraPreview: wref<inkInventoryPuppetPreviewGameController>;
    // POSES button on the screen, and CLOSE on the browser column.
    public let m_button: wref<inkText>;
    private let m_close: wref<inkText>;
    // Pose browser panel, opened by the button: packs in a rail on the left, the selected
    // pack's poses as a paged grid on the right.
    private let m_listPanel: wref<inkWidget>;
    private let m_search: ref<HubTextInput>;
    private let m_query: String;
    private let m_railArea: wref<inkWidget>;
    private let m_railItems: array<wref<inkCanvas>>;
    private let m_railLabels: array<wref<inkText>>;
    private let m_railCounts: array<wref<inkText>>;
    private let m_railBackgrounds: array<wref<inkRectangle>>;
    private let m_railBars: array<wref<inkRectangle>>;
    private let m_railThumb: wref<inkRectangle>;
    private let m_gridArea: wref<inkWidget>;
    private let m_tiles: array<wref<inkCanvas>>;
    private let m_tileLabels: array<wref<inkText>>;
    private let m_tileBackgrounds: array<wref<inkRectangle>>;
    private let m_tileBars: array<wref<inkRectangle>>;
    private let m_tileFrames: array<wref<inkCanvas>>;
    private let m_caption: wref<inkText>;
    private let m_pageText: wref<inkText>;
    private let m_prevPage: wref<inkText>;
    private let m_nextPage: wref<inkText>;
    private let m_footer: wref<inkText>;
    private let m_hover: wref<inkWidget>;
    private let m_wheelOnRail: Bool;
    private let m_coveredWidgets: array<wref<inkWidget>>;
    private let m_coveredVisibility: array<Bool>;
    // Rail entries from the top: pack indices, or a section header (SectionPoses /
    // SectionAnimations). m_railOffset is the first entry shown.
    private let m_rail: array<Int32>;
    private let m_railOffset: Int32;
    private let m_collapsedSections: array<Int32>;
    private let m_sectionCounts: array<Int32>;
    // Per pack, how many of its poses match the search (all of them without one).
    private let m_packMatches: array<Int32>;
    private let m_packIsAnimation: array<Bool>;
    // The pack shown in the grid, its matching poses, and the page of them on screen.
    private let m_selectedPack: Int32;
    private let m_grid: array<Int32>;
    private let m_page: Int32;
    private let m_lowerNames: array<String>;
    // Screen controller that owns the current selector widgets.
    private let m_owner: wref<IScriptable>;
    private let m_catalog: ref<PreviewPosesCatalog>;
    private let m_names: array<String>;
    private let m_namesLoaded: Bool;
    private let m_packPoses: array<ref<PreviewPosePack>>;
    private let m_packLabels: array<String>;

    public static func Get(game: GameInstance) -> ref<PreviewPosesState> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"PreviewPosesState") as PreviewPosesState;
    }

    private func Catalog() -> ref<PreviewPosesCatalog> {
        if !IsDefined(this.m_catalog) {
            this.m_catalog = new PreviewPosesCatalog();
        }
        return this.m_catalog;
    }

    // Display names come from photo mode's own pose records, so they match its menu and
    // the game language. Poses without a record fall back to a cleaned-up animation name.
    private func PoseName(index: Int32) -> String {
        let catalog: ref<PreviewPosesCatalog> = this.Catalog();
        let count: Int32 = catalog.Count();
        if ArraySize(this.m_names) != count {
            ArrayResize(this.m_names, count);
            this.m_names[0] = "DEFAULT";
            this.m_namesLoaded = false;
        }
        if NotEquals(this.m_names[index], "") {
            return this.m_names[index];
        }
        // Index the catalog once: searching must not scan every record for every pose.
        if !this.m_namesLoaded {
            let indices: ref<inkIntHashMap> = new inkIntHashMap();
            let poseIndex: Int32 = 1;
            while poseIndex < count {
                indices.Insert(NameToHash(catalog.Animation(poseIndex)), poseIndex);
                poseIndex += 1;
            }
            let records: array<ref<TweakDBRecord>> = TweakDBInterface.GetRecords(n"PhotoModePose");
            for record in records {
                let pose: ref<PhotoModePose_Record> = record as PhotoModePose_Record;
                if IsDefined(pose) {
                    let key: Uint64 = NameToHash(pose.AnimationName());
                    if indices.KeyExist(key) {
                        poseIndex = indices.Get(key);
                        if Equals(this.m_names[poseIndex], "") {
                            this.m_names[poseIndex] = GetLocalizedTextByKey(pose.DisplayName());
                        }
                    }
                }
            }
            this.m_namesLoaded = true;
        }
        if Equals(this.m_names[index], "") {
            this.m_names[index] = this.FallbackName(catalog.Animation(index));
        }
        return this.m_names[index];
    }

    private func FallbackName(animation: CName) -> String {
        let text: String = NameToString(animation);
        text = this.StripPrefix(text, "photomode__v_female__natural__");
        text = this.StripPrefix(text, "photomode__v__natural__");
        text = this.StripPrefix(text, "photomode__v_female__");
        text = this.StripPrefix(text, "idle_");
        text = this.StripPrefix(text, "action_");
        return StrReplaceAll(StrReplaceAll(text, "__", " "), "_", " ");
    }

    private func StripPrefix(text: String, prefix: String) -> String {
        return StrBeginsWith(text, prefix) ? StrRight(text, StrLen(text) - StrLen(prefix)) : text;
    }

    // Pack names are category display names. A name that is a localization key is shown
    // as its text when the game has a translation for it.
    private func PackLabel(packIndex: Int32) -> String {
        let catalog: ref<PreviewPosesCatalog> = this.Catalog();
        if ArraySize(this.m_packLabels) != catalog.PackCount() {
            ArrayClear(this.m_packLabels);
            let index: Int32 = 0;
            let count: Int32 = catalog.PackCount();
            while index < count {
                ArrayPush(this.m_packLabels, this.ResolvePackName(catalog.PackName(index)));
                index += 1;
            }
        }
        if packIndex < 0 || packIndex >= ArraySize(this.m_packLabels) {
            return "";
        }
        return this.m_packLabels[packIndex];
    }

    private func ResolvePackName(name: String) -> String {
        if Equals(name, "") {
            return "";
        }
        let text: String = GetLocalizedTextByKey(StringToName(name));
        if NotEquals(text, "") && NotEquals(text, name) {
            return text;
        }
        return name;
    }

    // Resolves the saved animation name to its current pose number, once per session.
    private func Restore() -> Void {
        this.m_restored = true;
        this.m_pose = 0;
        if Equals(this.m_savedAnimation, n"None") || Equals(this.m_savedAnimation, n"") {
            return;
        }
        let catalog: ref<PreviewPosesCatalog> = this.Catalog();
        let index: Int32 = 1;
        while index < catalog.Count() {
            if Equals(catalog.Animation(index), this.m_savedAnimation) {
                this.m_pose = index;
                return;
            }
            index += 1;
        }
    }

    public func Refresh() -> Void {
        if !this.m_restored {
            this.Restore();
        }
        let count: Int32 = this.Catalog().Count();
        if this.m_pose < 0 || this.m_pose >= count {
            this.m_pose = 0;
        }
        if IsDefined(this.m_preview) {
            let puppet: wref<gamePuppet> = this.m_preview.GetGamePuppet();
            if IsDefined(puppet) {
                let feature: ref<AnimFeature_WardrobePose> = new AnimFeature_WardrobePose();
                feature.pose = Cast<Float>(this.m_pose);
                AnimationControllerComponent.ApplyFeature(puppet, n"WardrobePose", feature);
            }
        }
        if IsDefined(this.m_button) {
            this.m_button.SetText("POSES    " + this.PoseName(this.m_pose));
        }
        if IsDefined(this.m_listPanel) && this.m_listPanel.IsVisible() {
            this.RedrawList();
        }
    }

    // The POSES button toggles the panel and CLOSE hides it. A rail pack shows its poses in
    // the grid, a rail section header folds that section, and a tile applies its pose and
    // leaves the panel open.
    public func Step(target: wref<inkWidget>) -> Void {
        if target == this.m_button {
            this.ToggleList();
            return;
        }
        if target == this.m_close {
            this.CloseList();
            return;
        }
        if target == this.m_prevPage {
            this.TurnPage(-1);
            return;
        }
        if target == this.m_nextPage {
            this.TurnPage(1);
            return;
        }
        let item: Int32 = this.RailIndex(target);
        if item >= 0 {
            let entry: Int32 = this.m_railOffset + item;
            if entry < ArraySize(this.m_rail) {
                let value: Int32 = this.m_rail[entry];
                if value < 0 {
                    if ArrayContains(this.m_collapsedSections, value) {
                        ArrayRemove(this.m_collapsedSections, value);
                    } else {
                        ArrayPush(this.m_collapsedSections, value);
                    }
                    this.ApplyFilter();
                } else {
                    this.m_selectedPack = value;
                    this.FillGrid();
                    this.m_page = 0;
                }
                this.ClampOffsets();
                this.RedrawList();
            }
            return;
        }
        let tile: Int32 = this.TileIndex(target);
        if tile >= 0 {
            let entry: Int32 = this.m_page * this.PageSize() + tile;
            if entry < ArraySize(this.m_grid) {
                this.Select(this.m_grid[entry]);
            }
        }
    }

    private func Select(pose: Int32) -> Void {
        this.m_pose = pose;
        this.m_savedAnimation = this.Catalog().Animation(pose);
        this.Refresh();
    }

    // Hover restyles the entry under the cursor and decides what the wheel scrolls.
    public func Hover(target: wref<inkWidget>, over: Bool) -> Void {
        if !IsDefined(this.m_listPanel) {
            return;
        }
        if !over {
            if this.m_hover == target {
                this.m_hover = null;
                this.RedrawList();
            }
            return;
        }
        if target == this.m_railArea || this.RailIndex(target) >= 0 {
            this.m_wheelOnRail = true;
        } else {
            if target == this.m_gridArea || this.TileIndex(target) >= 0 {
                this.m_wheelOnRail = false;
            }
        }
        this.m_hover = target;
        this.RedrawList();
    }

    // ----- pose browser -----
    // Sizes are 4K reference units. The rail lists the packs in two foldable sections,
    // pose packs and animations; the grid shows the selected pack a page at a time.

    private func RailRows() -> Int32 {
        return 26;
    }

    private func GridColumns() -> Int32 {
        return 2;
    }

    private func GridRows() -> Int32 {
        return 15;
    }

    private func PageSize() -> Int32 {
        return this.GridColumns() * this.GridRows();
    }

    private func SectionPoses() -> Int32 {
        return -1;
    }

    private func SectionAnimations() -> Int32 {
        return -2;
    }

    // The last pack holds the vanilla default pose and any uncategorized poses.
    private func DefaultPack() -> Int32 {
        return this.Catalog().PackCount();
    }

    private func RailIndex(target: wref<inkWidget>) -> Int32 {
        let index: Int32 = 0;
        while index < ArraySize(this.m_railItems) {
            if target == this.m_railItems[index] {
                return index;
            }
            index += 1;
        }
        return -1;
    }

    private func TileIndex(target: wref<inkWidget>) -> Int32 {
        let index: Int32 = 0;
        while index < ArraySize(this.m_tiles) {
            if target == this.m_tiles[index] {
                return index;
            }
            index += 1;
        }
        return -1;
    }

    // Packs PhotoModeUIImprovements makes from AMM animations are named "Animations: <type>".
    // They go in the ANIMATIONS section, without the prefix.
    private func EnsurePacks() -> Void {
        if ArraySize(this.m_packPoses) > 0 {
            return;
        }
        let catalog: ref<PreviewPosesCatalog> = this.Catalog();
        let count: Int32 = catalog.PackCount();
        let pack: Int32 = 0;
        while pack <= count {
            ArrayPush(this.m_packPoses, new PreviewPosePack());
            ArrayPush(this.m_packIsAnimation, pack < count && StrBeginsWith(catalog.PackName(pack), "Animations: "));
            pack += 1;
        }
        let pose: Int32 = 0;
        while pose < catalog.Count() {
            pack = catalog.Pack(pose);
            if pack < 0 || pack >= count { pack = count; }
            ArrayPush(this.m_packPoses[pack].poses, pose);
            pose += 1;
        }
    }

    private func RailLabel(pack: Int32) -> String {
        if pack == this.DefaultPack() {
            return "DEFAULT";
        }
        let label: String = this.PackLabel(pack);
        return this.m_packIsAnimation[pack] ? this.StripPrefix(label, "Animations: ") : label;
    }

    // Lowercased pose names for the search, made the first time each one is needed.
    private func LowerName(pose: Int32) -> String {
        let count: Int32 = this.Catalog().Count();
        if ArraySize(this.m_lowerNames) != count {
            ArrayClear(this.m_lowerNames);
            ArrayResize(this.m_lowerNames, count);
        }
        if Equals(this.m_lowerNames[pose], "") {
            this.m_lowerNames[pose] = UTF8StrLower(this.PoseName(pose));
        }
        return this.m_lowerNames[pose];
    }

    private func Query() -> String {
        return IsDefined(this.m_search) ? UTF8StrLower(this.m_search.GetText()) : "";
    }

    private func ToggleList() -> Void {
        if IsDefined(this.m_listPanel) && this.m_listPanel.IsVisible() {
            this.CloseList();
        } else {
            this.OpenList();
        }
    }

    // Opens on the current pose: its pack selected, the page that holds it, and the rail
    // scrolled so the pack is in view.
    private func OpenList() -> Void {
        if !IsDefined(this.m_listPanel) && IsDefined(this.m_button) {
            this.BuildBrowser(this.m_button.GetParentWidget() as inkCompoundWidget, this.m_owner);
        }
        if !IsDefined(this.m_listPanel) {
            return;
        }
        if IsDefined(this.m_search) {
            this.m_search.SetText("");
        }
        this.m_query = "";
        this.EnsurePacks();
        let pack: Int32 = this.Catalog().Pack(this.m_pose);
        if pack < 0 || pack >= this.DefaultPack() {
            pack = this.DefaultPack();
        } else {
            ArrayRemove(this.m_collapsedSections,
                this.m_packIsAnimation[pack] ? this.SectionAnimations() : this.SectionPoses());
        }
        this.m_selectedPack = pack;
        this.ApplyFilter();
        let index: Int32 = ArrayFindFirst(this.m_grid, this.m_pose);
        this.m_page = index > 0 ? index / this.PageSize() : 0;
        this.ScrollRailToSelected();
        this.ClampOffsets();
        this.m_hover = null;
        this.RedrawList();
        this.CoverEquipment(true);
        this.m_listPanel.SetVisible(true);
    }

    private func ScrollRailToSelected() -> Void {
        let index: Int32 = ArrayFindFirst(this.m_rail, this.m_selectedPack);
        if index < 0 {
            return;
        }
        if index < this.m_railOffset || index >= this.m_railOffset + this.RailRows() {
            this.m_railOffset = index - 4;
        }
    }

    // Called when the inventory or wardrobe screen closes. This system outlives every screen,
    // so it must not keep the screen's widgets or the search box controller alive.
    public func ReleaseScreen(owner: ref<IScriptable>) -> Void {
        // When switching screens the next one may already have built its selector.
        if this.m_owner != owner {
            return;
        }
        this.CloseList();
        if IsDefined(this.m_listPanel) {
            let parent: ref<inkCompoundWidget> = this.m_listPanel.GetParentWidget() as inkCompoundWidget;
            if IsDefined(parent) { parent.RemoveChild(this.m_listPanel); }
        }
        if IsDefined(this.m_button) { this.m_button.SetVisible(false); }
        this.m_owner = null;
        this.m_search = null;
        this.m_listPanel = null;
        this.m_railArea = null;
        this.m_gridArea = null;
        this.m_railThumb = null;
        ArrayClear(this.m_railItems);
        ArrayClear(this.m_railLabels);
        ArrayClear(this.m_railCounts);
        ArrayClear(this.m_railBackgrounds);
        ArrayClear(this.m_railBars);
        ArrayClear(this.m_tiles);
        ArrayClear(this.m_tileLabels);
        ArrayClear(this.m_tileBackgrounds);
        ArrayClear(this.m_tileBars);
        ArrayClear(this.m_tileFrames);
        this.m_caption = null;
        this.m_pageText = null;
        this.m_prevPage = null;
        this.m_nextPage = null;
        this.m_footer = null;
        this.m_hover = null;
        this.m_button = null;
        this.m_close = null;
        this.m_preview = null;
    }

    public func CloseList() -> Void {
        this.CoverEquipment(false);
        if IsDefined(this.m_listPanel) {
            this.m_listPanel.SetVisible(false);
        }
    }

    // The search narrows both sides: the rail keeps packs whose name or poses match, and the
    // grid keeps matching poses (all of them when the pack's own name matches).
    public func OnSearchChanged() -> Void {
        let query: String = this.Query();
        if Equals(query, this.m_query) {
            return;
        }
        this.m_query = query;
        if NotEquals(query, "") {
            ArrayClear(this.m_collapsedSections);
        }
        this.ApplyFilter();
        this.m_page = 0;
        this.m_railOffset = 0;
        this.ScrollRailToSelected();
        this.ClampOffsets();
        this.RedrawList();
    }

    // One notch scrolls the rail three entries, or turns one page of the grid.
    public func ScrollList(notches: Int32) -> Void {
        if !IsDefined(this.m_listPanel) || !this.m_listPanel.IsVisible() {
            return;
        }
        if this.m_wheelOnRail {
            this.m_railOffset += notches * 3;
            this.ClampOffsets();
            this.RedrawList();
        } else {
            this.TurnPage(notches);
        }
    }

    private func PageCount() -> Int32 {
        let count: Int32 = (ArraySize(this.m_grid) + this.PageSize() - 1) / this.PageSize();
        return count > 0 ? count : 1;
    }

    private func TurnPage(step: Int32) -> Void {
        this.m_page += step;
        this.ClampOffsets();
        this.RedrawList();
    }

    private func ClampOffsets() -> Void {
        let maxRail: Int32 = ArraySize(this.m_rail) - this.RailRows();
        if this.m_railOffset > maxRail { this.m_railOffset = maxRail; }
        if this.m_railOffset < 0 { this.m_railOffset = 0; }
        if this.m_page >= this.PageCount() { this.m_page = this.PageCount() - 1; }
        if this.m_page < 0 { this.m_page = 0; }
    }

    private func CoverEquipment(hidden: Bool) -> Void {
        if !hidden {
            let i: Int32 = 0;
            while i < ArraySize(this.m_coveredWidgets) {
                if IsDefined(this.m_coveredWidgets[i]) {
                    this.m_coveredWidgets[i].SetVisible(this.m_coveredVisibility[i]);
                }
                i += 1;
            }
            ArrayClear(this.m_coveredWidgets);
            ArrayClear(this.m_coveredVisibility);
            return;
        }
        if ArraySize(this.m_coveredWidgets) > 0 || !IsDefined(this.m_inventory)
            || this.m_owner != this.m_inventory {
            return;
        }
        let root: ref<inkCompoundWidget> = this.m_inventory.GetRootCompoundWidget();
        if !IsDefined(root) { return; }
        let paths: array<CName>;
        ArrayPush(paths, n"default_wrapper/headContainer");
        ArrayPush(paths, n"default_wrapper/chestContainer");
        ArrayPush(paths, n"default_wrapper/legsContainer");
        ArrayPush(paths, n"default_wrapper/outfitContainer");
        ArrayPush(paths, n"default_wrapper/menuLinks");
        for path in paths {
            let widget: wref<inkWidget> = root.GetWidgetByPathName(path);
            if IsDefined(widget) {
                ArrayPush(this.m_coveredWidgets, widget);
                ArrayPush(this.m_coveredVisibility, widget.IsVisible());
                widget.SetVisible(false);
            }
        }
    }

    // Rebuilds the rail and the selected pack's grid from the search and the folded
    // sections. A selected pack with no match left moves to the first pack that has one.
    private func ApplyFilter() -> Void {
        this.EnsurePacks();
        let query: String = this.Query();
        let searching: Bool = NotEquals(query, "");
        let packCount: Int32 = ArraySize(this.m_packPoses);
        ArrayClear(this.m_packMatches);
        let pack: Int32 = 0;
        while pack < packCount {
            let matches: Int32 = 0;
            if !searching || StrContains(UTF8StrLower(this.RailLabel(pack)), query) {
                matches = ArraySize(this.m_packPoses[pack].poses);
            } else {
                for pose in this.m_packPoses[pack].poses {
                    if StrContains(this.LowerName(pose), query) { matches += 1; }
                }
            }
            ArrayPush(this.m_packMatches, matches);
            pack += 1;
        }
        ArrayClear(this.m_rail);
        ArrayClear(this.m_sectionCounts);
        ArrayResize(this.m_sectionCounts, 2);
        if this.m_packMatches[this.DefaultPack()] > 0 {
            ArrayPush(this.m_rail, this.DefaultPack());
        }
        this.AddSection(this.SectionPoses(), false);
        this.AddSection(this.SectionAnimations(), true);
        if this.m_selectedPack < 0 || this.m_selectedPack >= packCount
            || this.m_packMatches[this.m_selectedPack] == 0 {
            this.m_selectedPack = this.FirstMatchingPack();
        }
        this.FillGrid();
    }

    private func AddSection(section: Int32, animations: Bool) -> Void {
        let collapsed: Bool = ArrayContains(this.m_collapsedSections, section);
        let packs: Int32 = 0;
        let pack: Int32 = 0;
        while pack < this.DefaultPack() {
            if Equals(this.m_packIsAnimation[pack], animations) && this.m_packMatches[pack] > 0 {
                if packs == 0 { ArrayPush(this.m_rail, section); }
                packs += 1;
                if !collapsed { ArrayPush(this.m_rail, pack); }
            }
            pack += 1;
        }
        this.m_sectionCounts[-section - 1] = packs;
    }

    // Folded sections still count: their packs are only hidden from the rail.
    private func FirstMatchingPack() -> Int32 {
        for value in this.m_rail {
            if value >= 0 { return value; }
        }
        let pack: Int32 = 0;
        while pack < ArraySize(this.m_packMatches) {
            if this.m_packMatches[pack] > 0 { return pack; }
            pack += 1;
        }
        return -1;
    }

    private func FillGrid() -> Void {
        ArrayClear(this.m_grid);
        let pack: Int32 = this.m_selectedPack;
        if pack < 0 || pack >= ArraySize(this.m_packPoses) {
            return;
        }
        let query: String = this.Query();
        let all: Bool = Equals(query, "") || StrContains(UTF8StrLower(this.RailLabel(pack)), query);
        for pose in this.m_packPoses[pack].poses {
            if all || StrContains(this.LowerName(pose), query) {
                ArrayPush(this.m_grid, pose);
            }
        }
    }

    // Colors follow the game's MainColors palette.
    private func Red() -> HDRColor { return new HDRColor(1.176, 0.381, 0.348, 1.0); }
    private func ActiveRed() -> HDRColor { return new HDRColor(1.370, 0.444, 0.405, 1.0); }
    private func MildRed() -> HDRColor { return new HDRColor(0.682, 0.231, 0.212, 1.0); }
    private func DarkRed() -> HDRColor { return new HDRColor(0.263, 0.086, 0.094, 1.0); }
    private func HoverRed() -> HDRColor { return new HDRColor(0.412, 0.086, 0.090, 1.0); }
    private func Blue() -> HDRColor { return new HDRColor(0.369, 0.965, 1.0, 1.0); }
    private func MildBlue() -> HDRColor { return new HDRColor(0.204, 0.569, 0.592, 1.0); }
    private func FaintBlue() -> HDRColor { return new HDRColor(0.090, 0.173, 0.180, 1.0); }

    private func RedrawList() -> Void {
        if !IsDefined(this.m_listPanel) {
            return;
        }
        this.RedrawRail();
        this.RedrawGrid();
    }

    private func RedrawRail() -> Void {
        let i: Int32 = 0;
        while i < ArraySize(this.m_railItems) {
            let entry: Int32 = this.m_railOffset + i;
            let item: wref<inkCanvas> = this.m_railItems[i];
            let visible: Bool = entry < ArraySize(this.m_rail);
            item.SetVisible(visible);
            if visible {
                let value: Int32 = this.m_rail[entry];
                let hovered: Bool = this.m_hover == item;
                let label: wref<inkText> = this.m_railLabels[i];
                let count: wref<inkText> = this.m_railCounts[i];
                let bg: wref<inkRectangle> = this.m_railBackgrounds[i];
                if value < 0 {
                    let folded: Bool = ArrayContains(this.m_collapsedSections, value);
                    label.SetText((folded ? "+  " : "-  ")
                        + (value == this.SectionPoses() ? "POSE PACKS" : "ANIMATIONS"));
                    label.SetFontSize(26);
                    label.SetMargin(new inkMargin(12.0, 0.0, 72.0, 0.0));
                    label.SetTintColor(hovered ? this.Red() : this.MildRed());
                    count.SetText(ToString(this.m_sectionCounts[-value - 1]));
                    count.SetTintColor(this.MildRed());
                    this.m_railBars[i].SetVisible(false);
                    bg.SetTintColor(this.HoverRed());
                    bg.SetOpacity(hovered ? 0.5 : 0.0);
                } else {
                    let selected: Bool = value == this.m_selectedPack;
                    label.SetText(this.RailLabel(value));
                    label.SetFontSize(28);
                    label.SetMargin(new inkMargin(26.0, 0.0, 72.0, 0.0));
                    label.SetTintColor(selected ? this.Blue() : (hovered ? this.ActiveRed() : this.Red()));
                    count.SetText(ToString(this.m_packMatches[value]));
                    count.SetTintColor(selected ? this.MildBlue() : this.MildRed());
                    this.m_railBars[i].SetVisible(selected);
                    bg.SetTintColor(selected ? this.FaintBlue() : this.HoverRed());
                    bg.SetOpacity(selected ? 0.7 : (hovered ? 0.5 : 0.0));
                }
            }
            i += 1;
        }
        // Scroll thumb on the divider, sized to the share of the rail in view.
        let total: Int32 = ArraySize(this.m_rail);
        let rows: Int32 = this.RailRows();
        let height: Float = 1440.0;
        this.m_railThumb.SetVisible(total > rows);
        if total > rows {
            let thumb: Float = MaxF(60.0, height * Cast<Float>(rows) / Cast<Float>(total));
            let top: Float = (height - thumb) * Cast<Float>(this.m_railOffset) / Cast<Float>(total - rows);
            this.m_railThumb.SetSize(4.0, thumb);
            this.m_railThumb.SetMargin(new inkMargin(441.0, 240.0 + top, 0.0, 0.0));
        }
    }

    private func RedrawGrid() -> Void {
        let i: Int32 = 0;
        while i < ArraySize(this.m_tiles) {
            let entry: Int32 = this.m_page * this.PageSize() + i;
            let tile: wref<inkCanvas> = this.m_tiles[i];
            let visible: Bool = entry < ArraySize(this.m_grid);
            tile.SetVisible(visible);
            if visible {
                let pose: Int32 = this.m_grid[entry];
                let selected: Bool = pose == this.m_pose;
                let hovered: Bool = this.m_hover == tile;
                this.SetTileText(this.m_tileLabels[i], this.PoseName(pose));
                this.m_tileLabels[i].SetTintColor(selected ? this.Blue() : (hovered ? this.ActiveRed() : this.Red()));
                let bg: wref<inkRectangle> = this.m_tileBackgrounds[i];
                bg.SetTintColor(selected ? this.FaintBlue() : (hovered ? this.HoverRed() : this.DarkRed()));
                bg.SetOpacity(selected || hovered ? 0.9 : 0.55);
                let accent: HDRColor = selected ? this.Blue() : (hovered ? this.Red() : this.MildRed());
                this.m_tileBars[i].SetTintColor(accent);
                this.m_tileBars[i].SetOpacity(selected || hovered ? 1.0 : 0.6);
                let frame: wref<inkCanvas> = this.m_tileFrames[i];
                let edge: Int32 = 0;
                while edge < frame.GetNumChildren() {
                    frame.GetWidgetByIndex(edge).SetTintColor(accent);
                    edge += 1;
                }
                frame.SetOpacity(selected || hovered ? 1.0 : 0.7);
            }
            i += 1;
        }
        let pages: Int32 = this.PageCount();
        let hasPack: Bool = this.m_selectedPack >= 0;
        this.m_caption.SetText(hasPack ? this.RailLabel(this.m_selectedPack) : "");
        this.m_pageText.SetText(ToString(this.m_page + 1) + " / " + ToString(pages));
        this.m_pageText.SetVisible(pages > 1);
        this.m_prevPage.SetVisible(pages > 1);
        this.m_nextPage.SetVisible(pages > 1);
        this.m_prevPage.SetOpacity(this.m_page > 0 ? 1.0 : 0.35);
        this.m_nextPage.SetOpacity(this.m_page + 1 < pages ? 1.0 : 0.35);
        let count: Int32 = ArraySize(this.m_grid);
        this.m_footer.SetText(count == 0 ? "NO MATCHING POSES"
            : ToString(count) + (count == 1 ? " POSE" : " POSES")
                + "  |  WHEEL OVER POSES TURNS PAGES, OVER PACKS SCROLLS THEM");
    }

    private func BuildBrowser(parent: wref<inkCompoundWidget>, target: ref<IScriptable>) -> Void {
        let width: Float = 1280.0;
        let panel: ref<inkCanvas> = new inkCanvas();
        panel.SetName(n"previewPoseBrowser");
        panel.SetAnchor(inkEAnchor.TopCenter);
        panel.SetSize(width, 1780.0);
        panel.SetMargin(new inkMargin(560.0, 260.0, 0.0, 0.0));
        panel.childOrder = inkEChildOrder.Forward;
        panel.SetInteractive(true);
        panel.Reparent(parent);
        panel.RegisterToCallback(n"OnAxis", target, n"OnPreviewPoseScroll");

        let background: ref<inkRectangle> = new inkRectangle();
        background.SetAnchor(inkEAnchor.Fill);
        background.SetTintColor(new HDRColor(0.055, 0.005, 0.02, 1.0));
        background.SetOpacity(1.0);
        background.SetInteractive(false);
        background.Reparent(panel);
        let accent: ref<inkRectangle> = new inkRectangle();
        accent.SetAnchor(inkEAnchor.TopFillHorizontaly);
        accent.SetSize(width, 5.0);
        accent.SetTintColor(this.Red());
        accent.SetInteractive(false);
        accent.Reparent(panel);
        this.AddFrame(panel, this.MildRed(), 2.0).SetOpacity(0.8);

        let title: ref<inkText> = this.MakeText("POSE PACKS", false, target);
        title.SetFontSize(46);
        title.SetMargin(new inkMargin(32.0, 24.0, 0.0, 0.0));
        title.Reparent(panel);
        let close: ref<inkText> = this.MakeText("CLOSE", true, target);
        close.SetFontSize(36);
        close.SetAnchor(inkEAnchor.TopRight);
        close.SetAnchorPoint(1.0, 0.0);
        close.SetMargin(new inkMargin(0.0, 28.0, 32.0, 0.0));
        close.Reparent(panel);
        this.m_close = close;

        let search: ref<HubTextInput> = HubTextInput.Create();
        search.SetName(n"previewPoseSearch");
        search.SetDefaultText("SEARCH POSES OR PACKS");
        search.SetLetterCase(textLetterCase.UpperCase);
        search.SetMaxLength(64);
        search.SetWidth(width - 64.0);
        search.RegisterToCallback(n"OnInput", target, n"OnPreviewPoseSearch");
        search.Reparent(panel);
        search.GetRootWidget().SetMargin(new inkMargin(32.0, 96.0, 0.0, 0.0));
        this.m_search = search;

        this.BuildRail(panel, target);
        this.BuildGrid(panel, target);

        let footer: ref<inkText> = this.MakeText("", false, target, true);
        footer.SetFontSize(26);
        footer.SetTintColor(this.MildRed());
        footer.SetMargin(new inkMargin(32.0, 1708.0, 0.0, 0.0));
        footer.Reparent(panel);
        this.m_footer = footer;
        panel.SetVisible(false);
        this.m_listPanel = panel;
        ModLog(n"PreviewPoses", "Pose browser v3: pack rail and paged pose grid");
    }

    // Rail: 400 wide at the panel's left edge, one entry every 54 units.
    private func BuildRail(panel: ref<inkCanvas>, target: ref<IScriptable>) -> Void {
        let rail: ref<inkCanvas> = new inkCanvas();
        rail.SetName(n"previewPoseRail");
        rail.SetAnchor(inkEAnchor.TopLeft);
        rail.SetSize(400.0, 1440.0);
        rail.SetMargin(new inkMargin(32.0, 240.0, 0.0, 0.0));
        rail.childOrder = inkEChildOrder.Forward;
        rail.Reparent(panel);
        // An interactive backdrop, so hovering between entries still counts as the rail.
        let area: ref<inkRectangle> = new inkRectangle();
        area.SetAnchor(inkEAnchor.Fill);
        area.SetTintColor(new HDRColor(0.085, 0.012, 0.032, 1.0));
        area.SetInteractive(true);
        area.RegisterToCallback(n"OnHoverOver", target, n"OnPreviewPoseHoverOver");
        area.Reparent(rail);
        this.m_railArea = area;
        ArrayClear(this.m_railItems);
        ArrayClear(this.m_railLabels);
        ArrayClear(this.m_railCounts);
        ArrayClear(this.m_railBackgrounds);
        ArrayClear(this.m_railBars);
        let row: Int32 = 0;
        while row < this.RailRows() {
            let item: ref<inkCanvas> = new inkCanvas();
            item.SetAnchor(inkEAnchor.TopLeft);
            item.SetSize(400.0, 50.0);
            item.SetMargin(new inkMargin(0.0, Cast<Float>(row) * 54.0, 0.0, 0.0));
            item.childOrder = inkEChildOrder.Forward;
            item.SetInteractive(true);
            item.RegisterToCallback(n"OnRelease", target, n"OnPreviewPoseClick");
            item.RegisterToCallback(n"OnHoverOver", target, n"OnPreviewPoseHoverOver");
            item.RegisterToCallback(n"OnHoverOut", target, n"OnPreviewPoseHoverOut");
            item.Reparent(rail);
            let bg: ref<inkRectangle> = new inkRectangle();
            bg.SetAnchor(inkEAnchor.Fill);
            bg.SetInteractive(false);
            bg.Reparent(item);
            let bar: ref<inkRectangle> = new inkRectangle();
            bar.SetAnchor(inkEAnchor.LeftFillVerticaly);
            bar.SetSize(6.0, 50.0);
            bar.SetTintColor(this.Blue());
            bar.SetInteractive(false);
            bar.Reparent(item);
            let label: ref<inkText> = this.MakeText("", false, target, true);
            label.SetFitToContent(false);
            label.SetAnchor(inkEAnchor.Fill);
            label.SetOverflowPolicy(textOverflowPolicy.DotsEnd);
            label.SetVerticalAlignment(textVerticalAlignment.Center);
            label.SetInteractive(false);
            label.Reparent(item);
            let count: ref<inkText> = this.MakeText("", false, target, true);
            count.SetFontSize(24);
            count.SetAnchor(inkEAnchor.CenterRight);
            count.SetAnchorPoint(1.0, 0.5);
            count.SetMargin(new inkMargin(0.0, 0.0, 14.0, 0.0));
            count.SetInteractive(false);
            count.Reparent(item);
            ArrayPush(this.m_railItems, item);
            ArrayPush(this.m_railLabels, label);
            ArrayPush(this.m_railCounts, count);
            ArrayPush(this.m_railBackgrounds, bg);
            ArrayPush(this.m_railBars, bar);
            row += 1;
        }
        let divider: ref<inkRectangle> = new inkRectangle();
        divider.SetAnchor(inkEAnchor.TopLeft);
        divider.SetSize(2.0, 1440.0);
        divider.SetMargin(new inkMargin(442.0, 240.0, 0.0, 0.0));
        divider.SetTintColor(this.MildRed());
        divider.SetOpacity(0.4);
        divider.SetInteractive(false);
        divider.Reparent(panel);
        let thumb: ref<inkRectangle> = new inkRectangle();
        thumb.SetAnchor(inkEAnchor.TopLeft);
        thumb.SetTintColor(this.Red());
        thumb.SetOpacity(0.8);
        thumb.SetInteractive(false);
        thumb.Reparent(panel);
        this.m_railThumb = thumb;
    }

    // Grid: right of the rail, a caption row with the pack name and page arrows, then
    // GridRows() rows of GridColumns() tiles.
    private func BuildGrid(panel: ref<inkCanvas>, target: ref<IScriptable>) -> Void {
        let width: Float = 792.0;
        let grid: ref<inkCanvas> = new inkCanvas();
        grid.SetName(n"previewPoseGrid");
        grid.SetAnchor(inkEAnchor.TopLeft);
        grid.SetSize(width, 1440.0);
        grid.SetMargin(new inkMargin(456.0, 240.0, 0.0, 0.0));
        grid.childOrder = inkEChildOrder.Forward;
        grid.Reparent(panel);
        // Same color as the panel: only there so hovering between tiles counts as the grid.
        let area: ref<inkRectangle> = new inkRectangle();
        area.SetAnchor(inkEAnchor.Fill);
        area.SetTintColor(new HDRColor(0.055, 0.005, 0.02, 1.0));
        area.SetInteractive(true);
        area.RegisterToCallback(n"OnHoverOver", target, n"OnPreviewPoseHoverOver");
        area.Reparent(grid);
        this.m_gridArea = area;

        let caption: ref<inkText> = this.MakeText("", false, target, true);
        caption.SetFitToContent(false);
        caption.SetSize(width - 260.0, 60.0);
        caption.SetFontSize(36);
        caption.SetTintColor(this.Red());
        caption.SetOverflowPolicy(textOverflowPolicy.DotsEnd);
        caption.Reparent(grid);
        this.m_caption = caption;
        let next: ref<inkText> = this.MakeText(">", true, target);
        next.SetFontSize(40);
        next.SetAnchor(inkEAnchor.TopRight);
        next.SetAnchorPoint(1.0, 0.0);
        next.SetMargin(new inkMargin(0.0, 4.0, 8.0, 0.0));
        next.Reparent(grid);
        this.m_nextPage = next;
        let page: ref<inkText> = this.MakeText("", false, target, true);
        page.SetFontSize(30);
        page.SetTintColor(this.Red());
        page.SetAnchor(inkEAnchor.TopRight);
        page.SetAnchorPoint(1.0, 0.0);
        page.SetMargin(new inkMargin(0.0, 10.0, 64.0, 0.0));
        page.Reparent(grid);
        this.m_pageText = page;
        let prev: ref<inkText> = this.MakeText("<", true, target);
        prev.SetFontSize(40);
        prev.SetAnchor(inkEAnchor.TopRight);
        prev.SetAnchorPoint(1.0, 0.0);
        prev.SetMargin(new inkMargin(0.0, 4.0, 200.0, 0.0));
        prev.Reparent(grid);
        this.m_prevPage = prev;

        ArrayClear(this.m_tiles);
        ArrayClear(this.m_tileLabels);
        ArrayClear(this.m_tileBackgrounds);
        ArrayClear(this.m_tileBars);
        ArrayClear(this.m_tileFrames);
        let tileWidth: Float = (width - 12.0) / Cast<Float>(this.GridColumns());
        let index: Int32 = 0;
        while index < this.PageSize() {
            let tile: ref<inkCanvas> = new inkCanvas();
            tile.SetAnchor(inkEAnchor.TopLeft);
            tile.SetSize(tileWidth, 78.0);
            tile.SetMargin(new inkMargin(Cast<Float>(index % this.GridColumns()) * (tileWidth + 12.0),
                72.0 + Cast<Float>(index / this.GridColumns()) * 90.0, 0.0, 0.0));
            tile.childOrder = inkEChildOrder.Forward;
            tile.SetInteractive(true);
            tile.RegisterToCallback(n"OnRelease", target, n"OnPreviewPoseClick");
            tile.RegisterToCallback(n"OnHoverOver", target, n"OnPreviewPoseHoverOver");
            tile.RegisterToCallback(n"OnHoverOut", target, n"OnPreviewPoseHoverOut");
            tile.Reparent(grid);
            let bg: ref<inkRectangle> = new inkRectangle();
            bg.SetAnchor(inkEAnchor.Fill);
            bg.SetInteractive(false);
            bg.Reparent(tile);
            let frame: ref<inkCanvas> = this.AddFrame(tile, this.MildRed(), 2.0);
            let bar: ref<inkRectangle> = new inkRectangle();
            bar.SetAnchor(inkEAnchor.LeftFillVerticaly);
            bar.SetSize(6.0, 78.0);
            bar.SetInteractive(false);
            bar.Reparent(tile);
            let label: ref<inkText> = this.MakeText("", false, target, true);
            // A fixed box: with Fill and DotsEnd long names wrapped to a third line that ran
            // out of the tile. SetTileText picks a size that fits; the last line is cut.
            label.SetFitToContent(false);
            label.SetAnchor(inkEAnchor.CenterLeft);
            label.SetAnchorPoint(0.0, 0.5);
            label.SetMargin(new inkMargin(22.0, 0.0, 0.0, 0.0));
            label.SetSize(tileWidth - 34.0, 70.0);
            label.SetFontSize(28);
            label.SetWrapping(true, tileWidth - 34.0);
            label.SetOverflowPolicy(textOverflowPolicy.DotsEndLastLine);
            label.SetVerticalAlignment(textVerticalAlignment.Center);
            label.SetInteractive(false);
            label.Reparent(tile);
            ArrayPush(this.m_tiles, tile);
            ArrayPush(this.m_tileLabels, label);
            ArrayPush(this.m_tileBackgrounds, bg);
            ArrayPush(this.m_tileBars, bar);
            ArrayPush(this.m_tileFrames, frame);
            index += 1;
        }
    }

    // The largest size whose estimated lines fit the 70-unit box, as photo mode's grid does:
    // about 0.5 x size per upper-case character, 1.25 x size per line, with slack for word
    // wrapping. 18 allows three lines; anything longer is cut on the last one.
    private func SetTileText(label: ref<inkText>, text: String) -> Void {
        let width: Float = label.GetWidth();
        let chars: Float = Cast<Float>(StrLen(text));
        let sizes: array<Int32> = [28, 24, 21, 18];
        let chosen: Int32 = 18;
        for size in sizes {
            let perLine: Float = width / (0.5 * Cast<Float>(size));
            let lines: Float = Cast<Float>(CeilF(chars * 1.15 / perLine));
            if chosen == 18 && lines * 1.25 * Cast<Float>(size) <= 70.0 {
                chosen = size;
            }
        }
        label.SetFontSize(chosen);
        label.SetText(text);
    }

    // Four edge rectangles in a Fill canvas. Tint does not reach children, so callers
    // recolor the edges themselves.
    private func AddFrame(parent: ref<inkCompoundWidget>, color: HDRColor, thickness: Float) -> ref<inkCanvas> {
        let frame: ref<inkCanvas> = new inkCanvas();
        frame.SetAnchor(inkEAnchor.Fill);
        frame.SetInteractive(false);
        frame.Reparent(parent);
        let anchors: array<inkEAnchor>;
        ArrayPush(anchors, inkEAnchor.TopFillHorizontaly);
        ArrayPush(anchors, inkEAnchor.BottomFillHorizontaly);
        ArrayPush(anchors, inkEAnchor.LeftFillVerticaly);
        ArrayPush(anchors, inkEAnchor.RightFillVerticaly);
        let edge: Int32 = 0;
        while edge < 4 {
            let rect: ref<inkRectangle> = new inkRectangle();
            rect.SetAnchor(anchors[edge]);
            rect.SetSize(thickness, thickness);
            rect.SetTintColor(color);
            rect.SetInteractive(false);
            rect.Reparent(frame);
            edge += 1;
        }
        return frame;
    }

    private func MakeText(text: String, interactive: Bool, target: ref<IScriptable>, opt plain: Bool) -> ref<inkText> {
        let label: ref<inkText> = new inkText();
        label.SetText(text);
        label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        label.SetLetterCase(textLetterCase.UpperCase);
        if !plain {
            label.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
            label.BindProperty(n"tintColor", interactive ? n"MainColors.Blue" : n"MainColors.Red");
            label.BindProperty(n"fontWeight", n"MainColors.BodyFontWeight");
        }
        label.SetFontSize(44);
        label.SetFitToContent(true);
        label.SetVAlign(inkEVerticalAlign.Center);
        if interactive {
            label.SetInteractive(true);
            label.RegisterToCallback(n"OnRelease", target, n"OnPreviewPoseClick");
        }
        return label;
    }

    // Screen-space position in 4K reference units, top-left anchored: the empty area below
    // the inventory's QUICK ACCESS row, and the matching spot on the wardrobe.
    public func BuildSelector(parent: wref<inkCompoundWidget>, target: ref<IScriptable>) -> Void {
        if !IsDefined(parent) {
            return;
        }
        let preview: wref<inkPuppetPreviewGameController> = this.m_preview;
        this.ReleaseScreen(this.m_owner);
        this.m_preview = preview;
        this.m_owner = target;
        let button: ref<inkText> = parent.GetWidget(n"previewPoseButton") as inkText;
        if !IsDefined(button) {
            button = this.MakeText("POSES", true, target);
            button.SetName(n"previewPoseButton");
            button.SetAnchor(inkEAnchor.TopLeft);
            button.SetMargin(new inkMargin(600.0, 1850.0, 0.0, 0.0));
            button.Reparent(parent);
        }
        button.SetVisible(true);
        this.m_button = button;

        this.Refresh();
    }
}

// Inventory: the selector goes into the inventory screen itself.
@wrapMethod(gameuiInventoryGameController)
protected cb func OnSetUserData(userData: ref<IScriptable>) -> Bool {
    let result: Bool = wrappedMethod(userData);
    PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).BuildSelector(this.GetRootCompoundWidget(), this);
    return result;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewPoseClick(evt: ref<inkPointerEvent>) -> Bool {
    if !evt.IsAction(n"click") {
        return false;
    }
    this.PlaySound(n"Button", n"OnPress");
    PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).Step(evt.GetTarget());
    return true;
}

// Both screens: track the live preview and apply the pose once its puppet exists.
// On the wardrobe the preview controller is the whole screen, so the selector goes there.
@wrapMethod(inkPuppetPreviewGameController)
protected cb func OnPreviewInitialized() -> Bool {
    let result: Bool = wrappedMethod();
    let isInventory: Bool = IsDefined(this as inkInventoryPuppetPreviewGameController);
    let isWardrobe: Bool = this.IsA(n"EquipmentEx.WardrobeScreenController");
    if isInventory || isWardrobe {
        let state: ref<PreviewPosesState> = PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame());
        state.m_preview = this;
        if isWardrobe {
            state.BuildSelector(this.GetRootCompoundWidget(), this);
        } else {
            state.m_inventoryPreview = this;
            state.Refresh();
        }
    }
    return result;
}

@if(ModuleExists("EquipmentEx"))
@wrapMethod(gameuiInventoryGameController)
protected func HideWardrobeScreen() -> Bool {
    let result: Bool = wrappedMethod();
    if result {
        let state: ref<PreviewPosesState> = PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame());
        state.m_preview = state.m_inventoryPreview;
        state.BuildSelector(this.GetRootCompoundWidget(), this);
    }
    return result;
}

@addMethod(inkPuppetPreviewGameController)
protected cb func OnPreviewPoseClick(evt: ref<inkPointerEvent>) -> Bool {
    if !evt.IsAction(n"click") {
        return false;
    }
    this.PlaySound(n"Button", n"OnPress");
    PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).Step(evt.GetTarget());
    return true;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewPoseSearch(widget: wref<inkWidget>) -> Bool {
    PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).OnSearchChanged();
    return true;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewPoseScroll(evt: ref<inkPointerEvent>) -> Bool {
    if evt.IsAction(n"mouse_wheel") && evt.GetAxisData() != 0.0 {
        PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).ScrollList(evt.GetAxisData() > 0.0 ? -1 : 1);
        return true;
    }
    return false;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewPoseHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).Hover(evt.GetCurrentTarget(), true);
    return false;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewPoseHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).Hover(evt.GetCurrentTarget(), false);
    return false;
}

@addMethod(inkPuppetPreviewGameController)
protected cb func OnPreviewPoseHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).Hover(evt.GetCurrentTarget(), true);
    return false;
}

@addMethod(inkPuppetPreviewGameController)
protected cb func OnPreviewPoseHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).Hover(evt.GetCurrentTarget(), false);
    return false;
}

@addMethod(inkPuppetPreviewGameController)
protected cb func OnPreviewPoseSearch(widget: wref<inkWidget>) -> Bool {
    PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).OnSearchChanged();
    return true;
}

@addMethod(inkPuppetPreviewGameController)
protected cb func OnPreviewPoseScroll(evt: ref<inkPointerEvent>) -> Bool {
    if evt.IsAction(n"mouse_wheel") && evt.GetAxisData() != 0.0 {
        PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).ScrollList(evt.GetAxisData() > 0.0 ? -1 : 1);
        return true;
    }
    return false;
}

// Release the selector when its screen closes (see PreviewPosesState.ReleaseScreen).
@wrapMethod(gameuiInventoryGameController)
protected cb func OnUninitialize() -> Bool {
    let state: ref<PreviewPosesState> = PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame());
    if IsDefined(state.m_preview) {
        state.m_preview.PreviewViewCaptureInventory(state);
        PreviewViewLog("saved inventory view zoom=" + ToString(state.m_invZoom)
            + " left=" + ToString(state.m_invLeft) + " top=" + ToString(state.m_invTop)
            + " yaw=" + ToString(state.m_invYaw));
    }
    state.ReleaseScreen(this);
    state.m_inventoryPreview = null;
    state.m_inventory = null;
    return wrappedMethod();
}
