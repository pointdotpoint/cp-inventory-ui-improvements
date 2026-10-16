// WardrobeTabs: reorganises the Equipment-EX wardrobe into tabs. Requires Equipment-EX.
// - Section tabs in the panel header: AVAILABLE CLOTHING | OUTFITS. OUTFITS shows the
//   outfit list in the right panel, which frees the left of the screen for V.
// - Under AVAILABLE CLOTHING, body-area tabs filter the item grid. Unmapped slots go to
//   an OTHER tab. Prototype: mouse click only.
//
// Two constraints shape this file:
// - Equipment-EX's grid classes are module-private, so this file joins its module.
// - redscript cannot wrap or add methods on classes defined in scripts, only fields. All
//   behaviour therefore hangs off the vanilla base class of the wardrobe screen, and the
//   item list is narrowed by pruning the data source instead of hooking the filter.
module EquipmentEx

public abstract class WardrobeTabsConfig {
    public static func Labels() -> array<String> = ["HEAD", "BODY", "ARMS", "LEGS", "FEET", "OTHER"];

    public static func OutfitsLabel() -> String = "OUTFITS";

    // Horizontal shift of the V preview into the space the outfit list used to take.
    public static func PreviewShift() -> Float = -560.0;

    // Catch-all for slots that are not in Equipment-EX's known areas, e.g. slots added by
    // other mods or by future Equipment-EX versions. Only shown when it has items.
    public static func OtherTab() -> Int32 = 5;

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
}

// Kept on the view manager so the selection survives closing the wardrobe.
// The default (false) opens the wardrobe on AVAILABLE CLOTHING.
@addField(ViewManager)
public let m_wtOutfitsSection: Bool;

@addField(ViewManager)
public let m_wtActiveTab: Int32;

// Tab index + 1, resolved once per slot. 0 marks slot data the mod has not seen yet,
// which is how a repopulated grid is recognised.
@addField(InventoryGridSlotData)
public let m_wtTab: Int32;

@addField(WardrobeScreenController)
public let m_wtTabs: array<ref<inkText>>;

@addField(WardrobeScreenController)
public let m_wtTabBar: wref<inkWidget>;

@addField(WardrobeScreenController)
public let m_wtOutfitsTitle: wref<inkText>;

@addField(WardrobeScreenController)
public let m_wtClothingTitle: wref<inkText>;

@addField(WardrobeScreenController)
public let m_wtAllItems: array<ref<IScriptable>>;

@addField(WardrobeScreenController)
public let m_wtWatcher: ref<inkAnimProxy>;

@addField(WardrobeScreenController)
public let m_wtGrid: wref<inkWidget>;

@addField(WardrobeScreenController)
public let m_wtOutfitsHost: wref<inkWidget>;

// Widgets that only make sense for clothing: filters, their label, Equipment-EX's
// settings/expand/collapse buttons and the body-area tab bar.
@addField(WardrobeScreenController)
public let m_wtClothingOnly: array<wref<inkWidget>>;

@wrapMethod(inkPreviewGameController)
protected cb func OnInitialize() -> Bool {
    wrappedMethod();
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if IsDefined(screen) {
        this.WardrobeTabsInstallGrid();
        // Equipment-EX calls super.OnInitialize() before creating its outfit list, grid and
        // header buttons, so building here would be too early. The watcher's first tick
        // builds the tabs once everything exists.
        this.WardrobeTabsStartWatcher(screen);
    }
}

// Install before Equipment-EX captures the grid controller and binds its data source.
@addMethod(inkPreviewGameController)
private func WardrobeTabsInstallGrid() -> Void {
    let area: ref<inkCompoundWidget> = this.GetChildWidgetByPath(n"wrapper/wrapper/vendorPanel/inventoryContainer/stash_scroll_area_cache/scrollArea") as inkCompoundWidget;
    if !IsDefined(area) || !GameInstance.GetResourceDepot().ResourceExists(r"wardrobe_tabs\\gui\\grid.inkwidget") {
        ModLog(n"WardrobeTabs", "Eight-column grid unavailable; retaining original grid");
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
        ModLog(n"WardrobeTabs", "Eight-column grid v1 installed before data binding (168 x 151.5 cells)");
    } else {
        ModLog(n"WardrobeTabs", "Eight-column grid spawn failed; retaining original grid");
        if IsDefined(grid) {
            area.RemoveChild(grid);
        }
    }
}

// The native grid measures the 168-unit cell; its asynchronously spawned artwork is 75% size.
@wrapMethod(VendorItemVirtualController)
protected cb func OnSpawned(widget: ref<inkWidget>, userData: ref<IScriptable>) -> Bool {
    if IsDefined(this as InventoryGridItemController) && Equals(this.GetRootWidget().GetName(), n"wardrobeEightColumnItem") {
        widget.SetAnchor(inkEAnchor.TopLeft);
        widget.SetAnchorPoint(new Vector2(0.0, 0.0));
        widget.SetHAlign(inkEHorizontalAlign.Left);
        widget.SetVAlign(inkEVerticalAlign.Top);
        widget.SetRenderTransformPivot(new Vector2(0.0, 0.0));
        widget.SetScale(new Vector2(0.75, 0.75));
    }
    return wrappedMethod(widget, userData);
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
        ArrayClear(screen.m_wtTabs);
        ArrayClear(screen.m_wtClothingOnly);
    }
    wrappedMethod();
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsMakeLabel(text: String, fontSize: Int32) -> ref<inkText> {
    let label: ref<inkText> = new inkText();
    label.SetText(text);
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    label.SetLetterCase(textLetterCase.UpperCase);
    label.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    label.BindProperty(n"fontWeight", n"MainColors.BodyFontWeight");
    label.SetFontSize(fontSize);
    label.SetFitToContent(true);
    label.SetInteractive(true);
    return label;
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsBuild(screen: ref<WardrobeScreenController>) -> Void {
    let panel: ref<inkCompoundWidget> = this.GetChildWidgetByPath(n"wrapper/wrapper/vendorPanel") as inkCompoundWidget;
    if !IsDefined(panel) {
        return;
    }
    let header: ref<inkCompoundWidget> = panel.GetWidget(n"vendorHeader") as inkCompoundWidget;
    let headerWrapper: ref<inkCompoundWidget> = panel.GetWidgetByPathName(n"vendorHeader/vendoHeaderWrapper") as inkCompoundWidget;

    // Section tabs: the existing AVAILABLE CLOTHING title followed by an OUTFITS title.
    let nameWrapper: ref<inkCompoundWidget> = panel.GetWidgetByPathName(n"vendorHeader/vendoHeaderWrapper/vendorNameWrapper") as inkCompoundWidget;
    let clothingTitle: ref<inkText> = panel.GetWidgetByPathName(n"vendorHeader/vendoHeaderWrapper/vendorNameWrapper/value") as inkText;
    if IsDefined(nameWrapper) && IsDefined(clothingTitle) {
        let sections: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        sections.SetName(n"wardrobeSections");
        sections.SetFitToContent(true);
        sections.SetChildMargin(new inkMargin(0.0, 0.0, 64.0, 0.0));
        sections.Reparent(nameWrapper);

        let outfitsTitle: ref<inkText> = this.WardrobeTabsMakeLabel(WardrobeTabsConfig.OutfitsLabel(), 50);
        outfitsTitle.SetMargin(clothingTitle.GetMargin());
        clothingTitle.Reparent(sections);
        outfitsTitle.Reparent(sections);
        clothingTitle.SetInteractive(true);

        outfitsTitle.RegisterToCallback(n"OnRelease", this, n"OnWardrobeSectionClick");
        clothingTitle.RegisterToCallback(n"OnRelease", this, n"OnWardrobeSectionClick");
        screen.m_wtOutfitsTitle = outfitsTitle;
        screen.m_wtClothingTitle = clothingTitle;
    }

    // Body-area tabs, inside the header below the filters row.
    let bar: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    bar.SetName(n"wardrobeTabs");
    bar.SetFitToContent(true);
    bar.SetHAlign(inkEHorizontalAlign.Left);
    bar.SetMargin(new inkMargin(0.0, 14.0, 0.0, 0.0));
    bar.SetChildMargin(new inkMargin(0.0, 0.0, 56.0, 0.0));
    bar.Reparent(header);
    screen.m_wtTabBar = bar;

    for label in WardrobeTabsConfig.Labels() {
        let tab: ref<inkText> = this.WardrobeTabsMakeLabel(label, 40);
        tab.Reparent(bar);
        tab.RegisterToCallback(n"OnRelease", this, n"OnWardrobeTabClick");
        ArrayPush(screen.m_wtTabs, tab);
    }
    screen.m_wtTabs[WardrobeTabsConfig.OtherTab()].SetVisible(false);

    ArrayPush(screen.m_wtClothingOnly, bar);
    ArrayPush(screen.m_wtClothingOnly, panel.GetWidgetByPathName(n"vendorHeader/inkHorizontalPanelWidget2"));
    if IsDefined(headerWrapper) {
        ArrayPush(screen.m_wtClothingOnly, headerWrapper.GetWidget(n"filtersorting_txt"));
        // Equipment-EX appends its settings/expand/collapse buttons as the last child.
        ArrayPush(screen.m_wtClothingOnly, headerWrapper.GetWidgetByIndex(headerWrapper.GetNumChildren() - 1));
    }

    // The grid container sits 62 units below the header; the tab row takes that space.
    let grid: ref<inkWidget> = panel.GetWidget(n"inventoryContainer");
    if IsDefined(grid) {
        grid.SetMargin(new inkMargin(0.0, 8.0, 0.0, 204.0));
        grid.SetAffectsLayoutWhenHidden(false);
    }
    screen.m_wtGrid = grid;

    // Host for the outfit list, occupying the grid's place in the panel.
    let host: ref<inkCanvas> = new inkCanvas();
    host.SetName(n"wardrobeOutfitsHost");
    host.SetSize(1352.0, 1414.0);
    host.SetHAlign(inkEHorizontalAlign.Left);
    host.SetVAlign(inkEVerticalAlign.Fill);
    host.SetMargin(new inkMargin(0.0, 24.0, 0.0, 204.0));
    host.SetAffectsLayoutWhenHidden(false);
    host.Reparent(panel);
    screen.m_wtOutfitsHost = host;

    let manager: ref<inkCompoundWidget> = screen.m_outfitManager.GetRootCompoundWidget();
    if IsDefined(manager) {
        manager.Reparent(host);
        // The section tab replaces the list's own WARDROBE OUTFITS title.
        let listHeader: ref<inkWidget> = manager.GetWidget(n"header");
        if IsDefined(listHeader) {
            listHeader.SetVisible(false);
        }
        // The list was laid out for the left column; fit it to the grid's box instead.
        let list: ref<inkWidget> = manager.GetWidget(n"scroll_wrapper");
        if IsDefined(list) {
            list.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));
            list.SetSize(1352.0, 1414.0);
        }
    }

    let preview: ref<inkWidget> = this.GetChildWidgetByPath(n"wrapper/preview");
    if IsDefined(preview) {
        preview.SetTranslation(WardrobeTabsConfig.PreviewShift(), 0.0);
    }

    this.WardrobeTabsRefresh(screen);
}

// Equipment-EX rebuilds the grid's data source at times no vanilla method observes,
// so a looping animation polls for a rebuilt source.
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
private func WardrobeTabsHighlight(label: wref<inkText>, active: Bool) -> Void {
    if IsDefined(label) {
        label.BindProperty(n"tintColor", active ? n"MainColors.Blue" : n"MainColors.Red");
        label.SetOpacity(active ? 1.0 : 0.6);
    }
}

@addMethod(inkPreviewGameController)
private func WardrobeTabsRefresh(screen: ref<WardrobeScreenController>) -> Void {
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let clothing: Bool = !view.m_wtOutfitsSection;

    this.WardrobeTabsHighlight(screen.m_wtOutfitsTitle, !clothing);
    this.WardrobeTabsHighlight(screen.m_wtClothingTitle, clothing);

    let index: Int32 = 0;
    while index < ArraySize(screen.m_wtTabs) {
        this.WardrobeTabsHighlight(screen.m_wtTabs[index], index == view.m_wtActiveTab);
        index += 1;
    }

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
}

// Replaces the grid's source with the active tab's slots and items.
@addMethod(inkPreviewGameController)
private func WardrobeTabsApply(screen: ref<WardrobeScreenController>) -> Void {
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let otherTab: Int32 = WardrobeTabsConfig.OtherTab();
    let hasOther: Bool = false;
    for entry in screen.m_wtAllItems {
        let slot: ref<InventoryGridSlotData> = entry as InventoryGridSlotData;
        if IsDefined(slot) {
            if slot.m_wtTab == 0 {
                slot.m_wtTab = WardrobeTabsConfig.TabOfSlot(slot.ItemData.SlotID) + 1;
            }
            if slot.m_wtTab - 1 == otherTab {
                hasOther = true;
            }
        }
    }
    if ArraySize(screen.m_wtTabs) > otherTab {
        screen.m_wtTabs[otherTab].SetVisible(hasOther);
    }
    if !hasOther && view.m_wtActiveTab == otherTab {
        view.m_wtActiveTab = 0;
        this.WardrobeTabsRefresh(screen);
    }

    let kept: array<ref<IScriptable>>;
    for entry in screen.m_wtAllItems {
        let uiSlot: ref<InventoryGridSlotData> = entry as InventoryGridSlotData;
        if !IsDefined(uiSlot) {
            let uiItem: ref<InventoryGridItemData> = entry as InventoryGridItemData;
            if IsDefined(uiItem) {
                uiSlot = uiItem.Parent;
            }
        }
        if IsDefined(uiSlot) && uiSlot.m_wtTab - 1 == view.m_wtActiveTab {
            ArrayPush(kept, entry);
        }
    }
    screen.m_inventoryGridDataSource.Reset(kept);
    screen.m_inventoryGridDataView.UpdateView();
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeTabsWatch(proxy: ref<inkAnimProxy>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) || !IsDefined(screen.m_inventoryGridDataSource) {
        return false;
    }
    if ArraySize(screen.m_wtTabs) == 0 {
        this.WardrobeTabsBuild(screen);
    }
    // A freshly populated source starts with slot data this mod has not tagged yet.
    if screen.m_inventoryGridDataSource.GetArraySize() == 0u {
        return false;
    }
    let first: ref<InventoryGridSlotData> = screen.m_inventoryGridDataSource.GetItem(0u) as InventoryGridSlotData;
    if IsDefined(first) && first.m_wtTab == 0 {
        screen.m_wtAllItems = screen.m_inventoryGridDataSource.GetArray();
        this.WardrobeTabsApply(screen);
    }
    return true;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeSectionClick(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) || !evt.IsAction(n"click") {
        return false;
    }
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let outfits: Bool = evt.GetTarget() == screen.m_wtOutfitsTitle;
    if NotEquals(outfits, view.m_wtOutfitsSection) {
        view.m_wtOutfitsSection = outfits;
        this.PlaySound(n"Button", n"OnPress");
        this.WardrobeTabsRefresh(screen);
    }
    return true;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeTabClick(evt: ref<inkPointerEvent>) -> Bool {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) || !evt.IsAction(n"click") {
        return false;
    }
    let view: ref<ViewManager> = this.WardrobeTabsView();
    let target: wref<inkWidget> = evt.GetTarget();
    let index: Int32 = 0;
    while index < ArraySize(screen.m_wtTabs) {
        if screen.m_wtTabs[index] == target && index != view.m_wtActiveTab {
            view.m_wtActiveTab = index;
            this.PlaySound(n"Button", n"OnPress");
            screen.m_inventoryScrollController.SetScrollPosition(0.0);
            this.WardrobeTabsApply(screen);
            this.WardrobeTabsRefresh(screen);
        }
        index += 1;
    }
    return true;
}
