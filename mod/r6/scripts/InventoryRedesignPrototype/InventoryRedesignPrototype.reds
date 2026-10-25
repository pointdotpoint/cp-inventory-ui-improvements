// Throwaway reference-based layout. All measurements use the game's 3840x2160 canvas.
// Keep category controllers and slot roots; replace only each slot's presentation.
module InventoryRedesignPrototype

public class RedesignInventoryReadyEvent extends Event {}

public class RedesignWardrobeCheckEvent extends Event {}

// Runtime-created widgets can exist before ink initializes their property manager.
public func RedesignUnbind(widget: wref<inkWidget>, property: CName) -> Void {
    if IsDefined(widget) && IsDefined(widget.propertyManager) {
        widget.UnbindProperty(property);
    }
}

public func RedesignTint(widget: wref<inkWidget>, color: HDRColor) -> Void {
    if IsDefined(widget) {
        RedesignUnbind(widget, n"tintColor");
        widget.SetTintColor(color);
    }
}

public func RedesignPlace(widget: wref<inkWidget>, left: Float, top: Float, scale: Float) -> Void {
    if !IsDefined(widget) {
        return;
    }
    widget.SetAnchor(inkEAnchor.TopCenter);
    widget.SetAnchorPoint(0.0, 0.0);
    widget.SetHAlign(inkEHorizontalAlign.Left);
    widget.SetVAlign(inkEVerticalAlign.Top);
    widget.SetMargin(new inkMargin(left, top, 0.0, 0.0));
    widget.SetRenderTransformPivot(0.0, 0.0);
    widget.SetScale(new Vector2(scale, scale));
}

// A flat surface replaces the stock angled atlas artwork. Slot roots retain their events.
public func RedesignSurface(parent: ref<inkCompoundWidget>, name: CName) -> ref<inkCanvas> {
    let surface: ref<inkCanvas> = new inkCanvas();
    surface.SetName(name);
    // Uniform grids give every root the widest cell; the visible tile stays fixed.
    surface.SetAnchor(inkEAnchor.TopLeft);
    surface.SetHAlign(inkEHorizontalAlign.Left);
    surface.SetVAlign(inkEVerticalAlign.Top);
    surface.SetSizeRule(inkESizeRule.Fixed);
    surface.SetFitToContent(false);
    surface.childOrder = inkEChildOrder.Forward;
    surface.SetInteractive(false);
    let fill: ref<inkRectangle> = new inkRectangle();
    fill.SetName(n"fill");
    fill.SetAnchor(inkEAnchor.Fill);
    fill.SetTintColor(new HDRColor(0.07, 0.003, 0.02, 1.0));
    fill.SetOpacity(0.94);
    fill.SetInteractive(false);
    fill.Reparent(surface);
    let frame: ref<inkCanvas> = new inkCanvas();
    frame.SetName(n"frame");
    frame.SetAnchor(inkEAnchor.Fill);
    frame.SetInteractive(false);
    // No border at rest; hover shows it (OnDisplayHoverOver).
    frame.SetOpacity(0.0);
    let i: Int32 = 0;
    while i < 4 {
        let edge: ref<inkRectangle> = new inkRectangle();
        edge.SetInteractive(false);
        edge.SetTintColor(new HDRColor(0.75, 0.06, 0.17, 1.0));
        if i < 2 {
            edge.SetAnchor(i == 0 ? inkEAnchor.TopFillHorizontaly : inkEAnchor.BottomFillHorizontaly);
            edge.SetSize(100.0, 2.0);
        } else {
            edge.SetAnchor(i == 2 ? inkEAnchor.LeftFillVerticaly : inkEAnchor.RightFillVerticaly);
            edge.SetSize(2.0, 100.0);
        }
        edge.Reparent(frame);
        i += 1;
    }
    frame.Reparent(surface);
    surface.Reparent(parent);
    return surface;
}

public func RedesignTintTree(widget: wref<inkWidget>, color: HDRColor) -> Void {
    if !IsDefined(widget) { return; }
    let compound: ref<inkCompoundWidget> = widget as inkCompoundWidget;
    if IsDefined(compound) {
        let i: Int32 = 0;
        while i < compound.GetNumChildren() {
            RedesignTintTree(compound.GetWidgetByIndex(i), color);
            i += 1;
        }
    } else {
        // Tinting both a parent and its children multiplies the color repeatedly.
        RedesignTint(widget, color);
    }
}

public func RedesignMove(widget: wref<inkWidget>, parent: ref<inkCompoundWidget>, left: Float, top: Float) -> Void {
    if !IsDefined(widget) { return; }
    if widget.GetParentWidget() != parent { widget.Reparent(parent); }
    widget.SetAnchor(inkEAnchor.TopLeft);
    widget.SetAnchorPoint(0.0, 0.0);
    widget.SetHAlign(inkEHorizontalAlign.Left);
    widget.SetVAlign(inkEVerticalAlign.Top);
    widget.SetMargin(new inkMargin(left, top, 0.0, 0.0));
}

@wrapMethod(gameuiInventoryGameController)
protected cb func OnSetUserData(userData: ref<IScriptable>) -> Bool {
    let result: Bool = wrappedMethod(userData);
    // Apply after other mods have added their controls during OnSetUserData.
    GameInstance.GetDelaySystem(this.GetPlayerControlledObject().GetGame()).DelayEventNextFrame(this, new RedesignInventoryReadyEvent());
    return result;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnRedesignInventoryReady(evt: ref<RedesignInventoryReadyEvent>) -> Bool {
    this.RedesignInventory();
    // FastInventory and PreviewPoses create these controls on the screen root, outside
    // default_wrapper, so they use screen coordinates. Together they form the action bar.
    let toggle: ref<inkWidget> = this.GetChildWidgetByPath(n"fastInventoryToggle");
    if IsDefined(toggle) {
        RedesignPlace(toggle, -1560.0, 1980.0, 0.9);
    }
    let poses: ref<inkWidget> = this.GetChildWidgetByPath(n"previewPoseButton");
    if IsDefined(poses) {
        RedesignPlace(poses, -1240.0, 1980.0, 0.9);
        RedesignTint(poses, new HDRColor(0.98, 0.78, 0.82, 1.0));
    }
    return true;
}

// Cyberware slots spawn asynchronously after the screen is built; style each as it arrives.
@wrapMethod(gameuiInventoryGameController)
protected cb func OnSlotSpawned(widget: ref<inkWidget>, userData: ref<IScriptable>) -> Bool {
    let result: Bool = wrappedMethod(widget, userData);
    this.RedesignInventoryStyle();
    return result;
}

// PopulateArea also runs later when asynchronous category events arrive.
@wrapMethod(gameuiInventoryGameController)
protected cb func OnEquipmentAreaCategoryCreated(e: ref<EquipmentAreaCategoryCreated>) -> Bool {
    let result: Bool = wrappedMethod(e);
    this.RedesignInventoryStyle();
    return result;
}

@wrapMethod(gameuiInventoryGameController)
private final func RefreshUI() -> Void {
    wrappedMethod();
    this.RedesignInventoryStyle();
}

@addMethod(gameuiInventoryGameController)
private func RedesignSection(path: CName, left: Float, top: Float, scale: Float) -> Void {
    let widget: ref<inkWidget> = this.GetChildWidgetByPath(path);
    if !IsDefined(widget) {
        ModLog(n"InventoryRedesignPrototype", "Missing section: " + NameToString(path));
        return;
    }
    RedesignPlace(widget, left, top, scale);
}

@addMethod(gameuiInventoryGameController)
private func RedesignInventory() -> Void {
    // Center-relative anchors keep the composition together on ultrawide displays.
    // default_wrapper starts about 265 units below the screen top, so these tops are
    // the mockup's screen positions minus 265 (cyberware/quick access have ~80 more
    // internal padding above their labels).
    this.RedesignSection(n"default_wrapper/weaponsContainer", -1560.0, 115.0, 1.0);
    this.RedesignSection(n"default_wrapper/cyberware_slots", -1560.0, 612.0, 1.0);
    this.RedesignSection(n"default_wrapper/quickslots", -1560.0, 940.0, 1.0);
    // Clothing reads head to toe: each container already stacks its two slots
    // vertically, so one column needs only the containers stacked, 344 units apart.
    this.RedesignSection(n"default_wrapper/headContainer", 680.0, 115.0, 1.0);
    this.RedesignSection(n"default_wrapper/chestContainer", 680.0, 459.0, 1.0);
    this.RedesignSection(n"default_wrapper/legsContainer", 680.0, 803.0, 1.0);
    this.RedesignSection(n"default_wrapper/outfitContainer", 680.0, 1230.0, 1.0);
    this.RedesignSection(n"default_wrapper/statsContainer", -1560.0, 1630.0, 0.7);
    this.RedesignLinks();
    // Scale the rendered surface without moving PreviewZoom's collider or saved camera.
    // Set an absolute value so reopening/refreshing never compounds the enlargement.
    let preview: wref<inkWidget> = this.PreviewViewSurface();
    if IsDefined(preview) {
        preview.SetRenderTransformPivot(0.5, 0.5);
        preview.SetScale(new Vector2(1.5, 1.5));
    }
    this.RedesignInventoryStyle();
    if IsDefined(this.m_buttonHintsController) {
        RedesignTintTree(this.m_buttonHintsController.GetRootWidget(), new HDRColor(0.98, 0.78, 0.82, 1.0));
    }
    ModLog(n"InventoryRedesignPrototype", "Inventory layout applied (prototype v7: links follow wardrobe and item modes)");
}

// Equipment-EX appends its Wardrobe button to menuLinks/btnsContainer. Wardrobe becomes
// the main button under the clothing column; Backpack, Crafting and Stats become a
// text bar along the bottom. Buttons keep their controllers and click callbacks.
@addMethod(gameuiInventoryGameController)
private func RedesignLinks() -> Void {
    let wrapper: ref<inkCompoundWidget> = inkWidgetRef.Get(this.m_defaultWrapper) as inkCompoundWidget;
    let list: ref<inkCompoundWidget> = this.GetChildWidgetByPath(n"default_wrapper/menuLinks/btnsContainer") as inkCompoundWidget;
    if !IsDefined(wrapper) || !IsDefined(list) || IsDefined(wrapper.GetWidget(n"redesignLinkBar")) {
        return;
    }
    let bar: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    bar.SetName(n"redesignLinkBar");
    bar.SetChildMargin(new inkMargin(0.0, 0.0, 56.0, 0.0));
    bar.Reparent(wrapper);
    RedesignPlace(bar, -560.0, 1700.0, 1.0);
    let links: array<ref<inkWidget>>;
    let wardrobe: ref<inkWidget>;
    let i: Int32 = 0;
    while i < list.GetNumChildren() {
        let child: ref<inkWidget> = list.GetWidgetByIndex(i);
        let name: CName = child.GetName();
        if Equals(name, n"HyperlinkButton_Backpack") || Equals(name, n"HyperlinkButton_Crafting") || Equals(name, n"HyperlinkButton_Stats") {
            ArrayPush(links, child);
        } else {
            if child.IsVisible() && IsDefined(child.GetController() as MenuItemController) {
                wardrobe = child;
            }
        }
        i += 1;
    }
    for link in links {
        link.Reparent(bar);
        this.RedesignTextLink(link as inkCompoundWidget);
    }
    this.m_redesignLinkBar = bar;
    if IsDefined(wardrobe) {
        wardrobe.Reparent(wrapper);
        RedesignPlace(wardrobe, 680.0, 1490.0, 0.85);
        this.m_redesignWardrobe = wardrobe;
        // Equipment-EX's own OnClick opens the wardrobe; this one hides the links under it.
        wardrobe.RegisterToCallback(n"OnClick", this, n"OnRedesignWardrobeClick");
    } else {
        ModLog(n"InventoryRedesignPrototype", "Wardrobe button not found; Equipment-EX may not have added it");
    }
    let menuLinks: ref<inkWidget> = this.GetChildWidgetByPath(n"default_wrapper/menuLinks");
    if IsDefined(menuLinks) {
        menuLinks.SetVisible(false);
    }
}

// The moved links left menuLinks, which is what default_wrapper_outro fades, so they stayed
// visible under the wardrobe and the item chooser. They follow those screens here instead.
@addField(gameuiInventoryGameController)
private let m_redesignLinkBar: wref<inkWidget>;

@addField(gameuiInventoryGameController)
private let m_redesignWardrobe: wref<inkWidget>;

@addMethod(gameuiInventoryGameController)
protected cb func OnRedesignWardrobeClick(evt: ref<inkPointerEvent>) -> Bool {
    if evt.IsAction(n"click") {
        // Checked a frame later: the wardrobe may not open (Equipment-EX's requirement popup).
        GameInstance.GetDelaySystem(this.GetPlayerControlledObject().GetGame()).DelayEventNextFrame(this, new RedesignWardrobeCheckEvent());
    }
    return false;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnRedesignWardrobeCheck(evt: ref<RedesignWardrobeCheckEvent>) -> Bool {
    if IsDefined(this.GetChildWidgetByPath(n"wardrobe")) {
        this.RedesignShowLinks(false);
    }
    return true;
}

// Vanilla calls this on every mode change with Center for the default screen; Equipment-EX
// calls it with Center when the wardrobe closes.
@wrapMethod(gameuiInventoryGameController)
private final func PlaySlidePaperdollAnimation(position: PaperdollPositionAnimation, opt hide: Bool) -> Void {
    wrappedMethod(position, hide);
    this.RedesignShowLinks(Equals(position, PaperdollPositionAnimation.Center));
}

@addMethod(gameuiInventoryGameController)
private func RedesignShowLinks(visible: Bool) -> Void {
    let widgets: array<wref<inkWidget>> = [this.m_redesignLinkBar, this.m_redesignWardrobe];
    // Hidden at once, since a transparent widget still takes clicks; shown with a fade.
    for widget in widgets {
        if IsDefined(widget) && !visible {
            widget.SetVisible(false);
        } else if IsDefined(widget) && !widget.IsVisible() {
            widget.SetOpacity(0.0);
            widget.SetVisible(true);
            let fade: ref<inkAnimTransparency> = new inkAnimTransparency();
            fade.SetDuration(0.3);
            fade.SetStartTransparency(0.0);
            fade.SetEndTransparency(1.0);
            fade.SetType(inkanimInterpolationType.Linear);
            fade.SetMode(inkanimInterpolationMode.EasyIn);
            let anim: ref<inkAnimDef> = new inkAnimDef();
            anim.AddInterpolator(fade);
            widget.PlayAnimation(anim);
        }
    }
}

// Strip a hyperlink button to its label: no frames, icon or minimum width.
@addMethod(gameuiInventoryGameController)
private func RedesignTextLink(button: ref<inkCompoundWidget>) -> Void {
    if !IsDefined(button) { return; }
    let flex: ref<inkCompoundWidget> = button.GetWidget(n"flexContainer") as inkCompoundWidget;
    if !IsDefined(flex) { return; }
    let i: Int32 = 0;
    while i < flex.GetNumChildren() {
        let part: ref<inkWidget> = flex.GetWidgetByIndex(i);
        if !Equals(part.GetName(), n"container") {
            part.SetVisible(false);
        }
        i += 1;
    }
    let container: ref<inkCompoundWidget> = flex.GetWidget(n"container") as inkCompoundWidget;
    if IsDefined(container) && container.GetNumChildren() > 0 {
        container.GetWidgetByIndex(0).SetVisible(false);
    }
    let label: ref<inkText> = button.GetWidgetByPathName(n"flexContainer/container/txtValue") as inkText;
    if IsDefined(label) {
        label.SetFontSize(40);
        label.SetLetterCase(textLetterCase.OriginalCase);
        label.SetFitToContent(true);
        RedesignTint(label, new HDRColor(0.75, 0.55, 0.60, 1.0));
    }
    button.SetSize(220.0, 60.0);
    button.RegisterToCallback(n"OnHoverOver", this, n"OnRedesignLinkHoverOver");
    button.RegisterToCallback(n"OnHoverOut", this, n"OnRedesignLinkHoverOut");
}

@addMethod(gameuiInventoryGameController)
protected cb func OnRedesignLinkHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    let button: ref<inkCompoundWidget> = evt.GetCurrentTarget() as inkCompoundWidget;
    if IsDefined(button) {
        RedesignTint(button.GetWidgetByPathName(n"flexContainer/container/txtValue"), new HDRColor(1.0, 0.88, 0.91, 1.0));
    }
    return false;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnRedesignLinkHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    let button: ref<inkCompoundWidget> = evt.GetCurrentTarget() as inkCompoundWidget;
    if IsDefined(button) {
        RedesignTint(button.GetWidgetByPathName(n"flexContainer/container/txtValue"), new HDRColor(0.75, 0.55, 0.60, 1.0));
    }
    return false;
}

@addMethod(gameuiInventoryGameController)
private func RedesignInventoryStyle() -> Void {
    let wrapper: ref<inkWidget> = inkWidgetRef.Get(this.m_defaultWrapper);
    if IsDefined(wrapper) {
        this.RedesignWalk(wrapper);
    }
    this.RedesignClothingHeaders();
}

// One "Clothing" title replaces the Head, Upper Body and Lower Body labels; each slot
// is named beside its tile instead. Outfit keeps its own label.
@addMethod(gameuiInventoryGameController)
private func RedesignClothingHeaders() -> Void {
    let title: ref<inkText> = this.GetChildWidgetByPath(n"default_wrapper/headContainer/absolutePosition/label") as inkText;
    if IsDefined(title) {
        title.SetText("Clothing");
    }
    let chest: ref<inkWidget> = this.GetChildWidgetByPath(n"default_wrapper/chestContainer/absolutePosition/label");
    if IsDefined(chest) { chest.SetVisible(false); }
    let legs: ref<inkWidget> = this.GetChildWidgetByPath(n"default_wrapper/legsContainer/absolutePosition/label");
    if IsDefined(legs) { legs.SetVisible(false); }
    // 16-unit gaps between the two slots of a pair match the gaps between pairs.
    let paths: array<CName> = [n"default_wrapper/headContainer/gridsWrapper", n"default_wrapper/chestContainer/gridsWrapper", n"default_wrapper/legsContainer/gridsWrapper"];
    for path in paths {
        let grids: ref<inkCompoundWidget> = this.GetChildWidgetByPath(path) as inkCompoundWidget;
        if IsDefined(grids) {
            grids.SetChildMargin(new inkMargin(0.0, 0.0, 0.0, 16.0));
        }
    }
}

@addMethod(gameuiInventoryGameController)
private func RedesignWalk(widget: wref<inkWidget>) -> Void {
    // The preview collider and its render surface belong to PreviewZoom (PreviewPoses).
    if Equals(widget.GetName(), n"paperDoll") {
        return;
    }
    let item: ref<InventoryItemDisplayController> = widget.GetController() as InventoryItemDisplayController;
    if IsDefined(item) {
        // Clothing rows are 180x156 with the slot name beside them; cyberware and quick
        // access are 200x200. Their icons carry more padding than weapon art, so boost them.
        let row: String = RedesignClothingRowName(item.GetEquipmentArea());
        if Equals(item.GetEquipmentArea(), gamedataEquipmentArea.Outfit) || StrLen(row) > 0 {
            item.RedesignInventoryTile(180.0, 156.0, 1.6);
            item.RedesignRowLabel(row);
        } else {
            item.RedesignInventoryTile(200.0, 200.0, 1.3);
        }
        return;
    }
    if Equals(widget.GetName(), n"weaponGrid") {
        let grid: ref<inkCompoundWidget> = widget as inkCompoundWidget;
        if IsDefined(grid) {
            grid.SetChildMargin(new inkMargin(0.0, 0.0, 0.0, 19.2));
            let i: Int32 = 0;
            while i < grid.GetNumChildren() {
                let tile: ref<InventoryItemDisplayController> = grid.GetWidgetByIndex(i).GetController() as InventoryItemDisplayController;
                if IsDefined(tile) {
                    tile.RedesignInventoryTile(i < 2 ? 224.0 : 467.2, 211.2, 1.0);
                    tile.GetRootWidget().SetTranslation(i == 1 ? 243.2 : 0.0, i == 0 ? 0.0 : -230.4);
                }
                i += 1;
            }
        }
        return;
    }
    let name: CName = widget.GetName();
    let text: ref<inkText> = widget as inkText;
    if IsDefined(text) {
        RedesignTint(text, new HDRColor(0.98, 0.78, 0.82, 1.0));
        if Equals(name, n"label") || Equals(name, n"label_stats") {
            text.SetFontSize(42);
            text.SetLetterCase(textLetterCase.OriginalCase);
        }
    }
    // Restyle only decorative backgrounds; rarity, locks and selection remain live.
    if Equals(name, n"background") || Equals(name, n"background_leftBg") {
        RedesignTint(widget, new HDRColor(0.10, 0.005, 0.025, 1.0));
    }
    if Equals(name, n"frame") || Equals(name, n"background_leftFrame") || Equals(name, n"divider") {
        RedesignTint(widget, new HDRColor(0.65, 0.04, 0.13, 1.0));
    }
    let compound: ref<inkCompoundWidget> = widget as inkCompoundWidget;
    if IsDefined(compound) {
        let i: Int32 = 0;
        while i < compound.GetNumChildren() {
            this.RedesignWalk(compound.GetWidgetByIndex(i));
            i += 1;
        }
    }
}

public func RedesignClothingRowName(area: gamedataEquipmentArea) -> String {
    switch area {
        case gamedataEquipmentArea.Head: return "Head";
        case gamedataEquipmentArea.Face: return "Face";
        case gamedataEquipmentArea.OuterChest: return "Outer torso";
        case gamedataEquipmentArea.InnerChest: return "Inner torso";
        case gamedataEquipmentArea.Legs: return "Legs";
        case gamedataEquipmentArea.Feet: return "Feet";
        default: return "";
    }
}

@addField(InventoryItemDisplayController)
private let m_redesignSurface: ref<inkCanvas>;

@addField(InventoryItemDisplayController)
private let m_redesignRowLabel: ref<inkText>;

// Slot name to the right of the tile, outside its bounds; the grid does not clip.
@addMethod(InventoryItemDisplayController)
public func RedesignRowLabel(text: String) -> Void {
    let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
    if !IsDefined(root) || StrLen(text) == 0 { return; }
    if !IsDefined(this.m_redesignRowLabel) {
        let label: ref<inkText> = new inkText();
        label.SetName(n"redesignRowLabel");
        label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        label.SetFontStyle(n"Semi-Bold");
        label.SetFontSize(40);
        label.SetFitToContent(true);
        label.SetInteractive(false);
        label.SetAnchor(inkEAnchor.CenterLeft);
        label.SetAnchorPoint(0.0, 0.5);
        label.SetMargin(new inkMargin(212.0, 0.0, 0.0, 0.0));
        label.Reparent(root);
        this.m_redesignRowLabel = label;
    }
    this.m_redesignRowLabel.SetText(text);
    RedesignTint(this.m_redesignRowLabel, new HDRColor(1.0, 0.85, 0.88, 1.0));
}

@addMethod(InventoryItemDisplayController)
public func RedesignInventoryTile(width: Float, height: Float, iconBoost: Float) -> Void {
    let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
    if !IsDefined(root) { return; }
    root.SetFitToContent(false);
    root.SetSize(width, height);
    if !IsDefined(this.m_redesignSurface) {
        // Keep the slot root/controller and append its replacement presentation.
        // The original angled artwork stays attached, transparent and noninteractive.
        this.m_redesignSurface = RedesignSurface(root, n"redesignTile");
        let i: Int32 = 0;
        while i < root.GetNumChildren() {
            let child: ref<inkWidget> = root.GetWidgetByIndex(i);
            if child != this.m_redesignSurface {
                RedesignUnbind(child, n"opacity");
                child.SetOpacity(0.0);
                child.SetInteractive(false);
            }
            i += 1;
        }
        // Native state/lock/input updates now address the new wrapper, and still bubble
        // to the original controller on the slot root.
        this.m_redesignSurface.SetInteractive(true);
        this.m_widgetWrapper = inkWidgetRef.Create(this.m_redesignSurface);
    }
    let surface: ref<inkCanvas> = this.m_redesignSurface;
    surface.SetSize(width, height);
    surface.SetOpacity(this.IsLocked() ? (this.m_visibleWhenLocked ? 0.55 : 0.0) : 1.0);
    this.RedesignTileImage(inkWidgetRef.Get(this.m_itemImage), width, height, iconBoost);
    this.RedesignTileImage(inkWidgetRef.Get(this.m_itemFallbackImage), width, height, iconBoost);
    this.RedesignTileImage(inkWidgetRef.Get(this.m_itemEmptyImage), width, height, iconBoost);
    RedesignMove(inkWidgetRef.Get(this.m_itemRarity), surface, 10.0, 14.0);
    let rarity: ref<inkWidget> = inkWidgetRef.Get(this.m_itemRarity);
    if IsDefined(rarity) {
        rarity.SetFitToContent(false);
        rarity.SetSize(4.0, height - 28.0);
    }
    RedesignTint(inkWidgetRef.Get(this.m_itemEmptyImage), new HDRColor(0.75, 0.22, 0.30, 1.0));
    RedesignMove(inkWidgetRef.Get(this.m_quantityWrapper), surface, 22.0, height - 48.0);
    RedesignTintTree(inkWidgetRef.Get(this.m_quantityWrapper), new HDRColor(1.0, 0.85, 0.88, 1.0));
    RedesignMove(inkWidgetRef.Get(this.m_lockIcon), surface, width - 48.0, 14.0);
    RedesignMove(inkWidgetRef.Get(this.m_equippedMarker), surface, width - 48.0, height - 48.0);
    RedesignMove(inkWidgetRef.Get(this.m_iconTransmog), surface, width - 48.0, height - 48.0);
    RedesignMove(inkWidgetRef.Get(this.m_newItemsWrapper), surface, width - 48.0, 14.0);
    RedesignMove(inkWidgetRef.Get(this.m_requirementsWrapper), surface, 22.0, 14.0);
}

@addMethod(InventoryItemDisplayController)
private func RedesignTileImage(widget: wref<inkWidget>, width: Float, height: Float, boost: Float) -> Void {
    if !IsDefined(widget) { return; }
    if widget.GetParentWidget() != this.m_redesignSurface { widget.Reparent(this.m_redesignSurface); }
    widget.SetAnchor(inkEAnchor.Centered);
    widget.SetAnchorPoint(0.5, 0.5);
    widget.SetHAlign(inkEHorizontalAlign.Center);
    widget.SetVAlign(inkEVerticalAlign.Center);
    widget.SetMargin(new inkMargin(0.0, -12.0, 0.0, 0.0));
    widget.SetRenderTransformPivot(0.5, 0.5);
    let size: Vector2 = widget.GetSize();
    if size.X > 0.0 && size.Y > 0.0 {
        let scale: Float = boost * MinF((width - 40.0) / size.X, (height - 64.0) / size.Y);
        widget.SetScale(new Vector2(scale, scale));
    }
}

@wrapMethod(InventoryItemDisplayController)
protected cb func OnDisplayHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    if IsDefined(this.m_redesignSurface) {
        let frame: ref<inkWidget> = this.m_redesignSurface.GetWidget(n"frame");
        RedesignTintTree(frame, new HDRColor(0.89, 0.23, 0.33, 1.0));
        if IsDefined(frame) { frame.SetOpacity(1.0); }
    }
    return result;
}

@wrapMethod(InventoryItemDisplayController)
protected cb func OnDisplayHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    if IsDefined(this.m_redesignSurface) {
        let frame: ref<inkWidget> = this.m_redesignSurface.GetWidget(n"frame");
        if IsDefined(frame) { frame.SetOpacity(0.0); }
    }
    return result;
}
