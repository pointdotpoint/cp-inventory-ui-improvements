// PreviewZoom: zoom, move and reset for V's preview on the inventory and wardrobe screens.
// Ported from VFocus (module BetterVZoom), keeping only what this project relied on, so
// PreviewPoses needs no other preview mod:
//   Mouse wheel over V       zoom (modifier + wheel moves and turns V, PreviewMove.reds)
//   Middle mouse + drag      move V
//   V                        reset the view (zoom, position, PreviewMove's turns and scale)
//   Pad R3 / L3, held        zoom in / out; both together reset
// Not ported: VFocus's button hints, WASD and right-stick panning, Triangle unequip-all and its
// backpack and Virtual Atelier screens.
//
// Zoom steps are extra camera setups 12..23 on the inventory preview (0..11 stay vanilla's
// equipment-area cameras). They are tuned for the wide, portrait render target in
// PreviewZoom.archive (tools/build_preview_target.py). The surface showing the render is
// enlarged to 4000 x 8000 so a moved or zoomed V is not cropped. Moving changes that surface's
// margin, never paperDoll's: paperDoll holds the collider, which would drift away from V.
// Equipment-EX's wardrobe shows the inventory's puppet render on its own image, so its zoom
// goes to the inventory's puppet preview controller.

public abstract class PreviewZoomConfig {
    public static func Steps() -> Int32 = 12
    public static func FirstSetup() -> Int32 = 12

    // Camera distance per step, farthest first.
    public static func Zoom(step: Int32) -> Float {
        switch step {
            case 0: return -1.0;
            case 1: return 3.0;
            case 2: return 2.75;
            case 3: return 2.5;
            case 4: return 2.25;
            case 5: return 2.0;
            case 6: return 1.75;
            case 7: return 1.5;
            case 8: return 1.25;
            case 9: return 1.0;
            case 10: return 0.75;
        }
        return 0.5;
    }

    public static func SurfaceWidth() -> Float = 4000.0
    public static func SurfaceHeight() -> Float = 8000.0
    // Surface top margin on the inventory: free view, and the equipment-area views.
    public static func InventoryTop() -> Float = -500.0
    public static func InventoryAreaTop() -> Float = -200.0
    public static func WardrobeLeft() -> Float = -300.0
    public static func WardrobeTop() -> Float = -300.0
    // Wardrobe input area around V. WardrobeTabs moves it with V (SetTranslation); at 1200
    // wide it reached into WardrobeTabs' slot sidebar and took its clicks.
    public static func WardrobeColliderWidth() -> Float = 1000.0

    public static func PanKey() -> EInputKey = EInputKey.IK_MiddleMouse
    public static func ResetKey() -> EInputKey = EInputKey.IK_V
    // Pad zoom repeats while held: first repeat, then each next one, in seconds.
    public static func RepeatDelay() -> Float = 0.35
    public static func RepeatInterval() -> Float = 0.12
}

// Pad thumbsticks: R3 zooms in, L3 out, both together reset.
public class PreviewZoomPad {
    public let m_left: Bool;
    public let m_right: Bool;
    public let m_chord: Bool;
    // Held zoom direction, 0 when none.
    public let m_hold: Int32;

    public static func IsThumb(key: EInputKey) -> Bool {
        return Equals(key, EInputKey.IK_Pad_RightThumb) || Equals(key, EInputKey.IK_Pad_LeftThumb);
    }

    // 2 reset, 1 zoom in, -1 zoom out, 0 nothing. Presses do nothing while disabled.
    public func Key(key: EInputKey, action: EInputAction, enabled: Bool) -> Int32 {
        let right: Bool = Equals(key, EInputKey.IK_Pad_RightThumb);
        if Equals(action, EInputAction.IACT_Press) {
            if !enabled { return 0; }
            if right { this.m_right = true; } else { this.m_left = true; }
            if this.m_left && this.m_right {
                this.m_chord = true;
                this.m_hold = 0;
                return 2;
            }
            if this.m_chord { return 0; }
            this.m_hold = right ? 1 : -1;
            return this.m_hold;
        }
        if Equals(action, EInputAction.IACT_Release) {
            if right { this.m_right = false; } else { this.m_left = false; }
            if this.m_hold == (right ? 1 : -1) { this.m_hold = 0; }
            if !this.m_left && !this.m_right { this.m_chord = false; }
        }
        return 0;
    }

    public func Clear() -> Void {
        this.m_left = false;
        this.m_right = false;
        this.m_chord = false;
        this.m_hold = 0;
    }
}

// Menus run while the game is paused, so a one-shot ink animation is the timer.
public func PreviewZoomTimer(widget: ref<inkWidget>, duration: Float) -> ref<inkAnimProxy> {
    let interpolator: ref<inkAnimTransparency> = new inkAnimTransparency();
    interpolator.SetDuration(duration);
    interpolator.SetStartTransparency(widget.GetOpacity());
    interpolator.SetEndTransparency(widget.GetOpacity());
    let definition: ref<inkAnimDef> = new inkAnimDef();
    definition.AddInterpolator(interpolator);
    return widget.PlayAnimation(definition);
}

public func PreviewZoomCameraEvent(step: Int32) -> ref<gameuiPuppetPreview_SetCameraSetupEvent> {
    let evt: ref<gameuiPuppetPreview_SetCameraSetupEvent> = new gameuiPuppetPreview_SetCameraSetupEvent();
    evt.setupIndex = Cast<Uint32>(PreviewZoomConfig.FirstSetup() + step);
    return evt;
}

public class PreviewZoomSurfaceEvent extends Event {}

// Queued on the inventory when the wardrobe closes; runs on two frames, after Equipment-EX
// has finished tearing the wardrobe down.
public class PreviewZoomReturnEvent extends Event {
    public let pass: Int32;
}

// --- Inventory puppet preview: the zoom camera setups -------------------------------------

@wrapMethod(inkInventoryPuppetPreviewGameController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();
    let setup: gameuiPuppetPreviewCameraSetup;
    setup.slotName = n"UISlotPreview_UpperBody";
    setup.interpolationTime = 0.5;
    let first: Int32 = PreviewZoomConfig.FirstSetup();
    ArrayResize(this.cameraController.cameraSetup, first + PreviewZoomConfig.Steps());
    let step: Int32 = 0;
    while step < PreviewZoomConfig.Steps() {
        setup.cameraZoom = PreviewZoomConfig.Zoom(step);
        this.cameraController.cameraSetup[first + step] = setup;
        step += 1;
    }
    // The wardrobe has no camera of its own; it zooms this one.
    let player: wref<GameObject> = this.GetPlayerControlledObject();
    if IsDefined(player) {
        PreviewPosesState.Get(player.GetGame()).m_cameraPreview = this;
    }
    return result;
}

// The zoom setups have no InventoryPaperdollZoomArea; give V the Head area's animation pose
// while the camera still uses the requested setup.
@wrapMethod(inkInventoryPuppetPreviewGameController)
protected cb func OnSetCameraSetupEvent(index: Uint32, slotName: CName) -> Bool {
    if index >= Cast<Uint32>(PreviewZoomConfig.FirstSetup()) {
        return wrappedMethod(Cast<Uint32>(EnumInt(InventoryPaperdollZoomArea.Head)), slotName);
    }
    return wrappedMethod(index, slotName);
}

// --- Inventory screen ---------------------------------------------------------------------

@addField(gameuiInventoryGameController)
public let m_pzZoom: Int32;

@addField(gameuiInventoryGameController)
private let m_pzCollider: wref<inkWidget>;

@addField(gameuiInventoryGameController)
private let m_pzHovered: Bool;

@addField(gameuiInventoryGameController)
private let m_pzPanHeld: Bool;

// The first mouse move after pressing the pan key is a jump; skip it.
@addField(gameuiInventoryGameController)
private let m_pzSkipMove: Bool;

@addField(gameuiInventoryGameController)
private let m_pzKeysRegistered: Bool;

@addField(gameuiInventoryGameController)
private let m_pzPad: ref<PreviewZoomPad>;

@addField(gameuiInventoryGameController)
private let m_pzRepeat: ref<inkAnimProxy>;

@wrapMethod(gameuiInventoryGameController)
protected cb func OnSetUserData(userData: ref<IScriptable>) -> Bool {
    let result: Bool = wrappedMethod(userData);
    this.m_pzZoom = 0;
    this.m_pzPanHeld = false;
    this.m_pzPad = new PreviewZoomPad();
    if !this.m_pzKeysRegistered {
        GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnPreviewZoomKey", true);
        this.m_pzKeysRegistered = true;
    }
    this.PreviewZoomAttachCollider();
    GameInstance.GetDelaySystem(this.GetPlayerControlledObject().GetGame()).DelayEventNextFrame(this, new PreviewZoomSurfaceEvent());
    return result;
}

@wrapMethod(gameuiInventoryGameController)
protected cb func OnUninitialize() -> Bool {
    if this.m_pzKeysRegistered {
        GameInstance.GetCallbackSystem().UnregisterCallback(n"Input/Key", this, n"OnPreviewZoomKey");
        this.m_pzKeysRegistered = false;
    }
    this.PreviewZoomDetachCollider();
    this.PreviewZoomStopRepeat();
    this.m_pzPanHeld = false;
    return wrappedMethod();
}

// Attaches the controls to the paperDoll currently on screen. Public so a mod that replaces
// the preview after the screen opened (FastInventory) can attach them to the new one.
@addMethod(gameuiInventoryGameController)
public func PreviewZoomAttach() -> Void {
    this.PreviewZoomAttachCollider();
    this.PreviewZoomApplySurface();
}

@addMethod(gameuiInventoryGameController)
private func PreviewZoomAttachCollider() -> Void {
    this.PreviewZoomDetachCollider();
    let paperDoll: ref<inkCompoundWidget> = inkWidgetRef.Get(this.m_paperDollWidget) as inkCompoundWidget;
    let collider: wref<inkWidget> = IsDefined(paperDoll) ? paperDoll.GetWidgetByPathName(n"canvas/collider") : null;
    if !IsDefined(collider) { return; }
    collider.SetInteractive(true);
    collider.RegisterToCallback(n"OnEnter", this, n"OnPreviewZoomEnter");
    collider.RegisterToCallback(n"OnLeave", this, n"OnPreviewZoomLeave");
    collider.RegisterToCallback(n"OnRelative", this, n"OnPreviewZoomRelative");
    this.m_pzCollider = collider;
}

@addMethod(gameuiInventoryGameController)
private func PreviewZoomDetachCollider() -> Void {
    if IsDefined(this.m_pzCollider) {
        this.m_pzCollider.UnregisterFromCallback(n"OnEnter", this, n"OnPreviewZoomEnter");
        this.m_pzCollider.UnregisterFromCallback(n"OnLeave", this, n"OnPreviewZoomLeave");
        this.m_pzCollider.UnregisterFromCallback(n"OnRelative", this, n"OnPreviewZoomRelative");
    }
    this.m_pzCollider = null;
    this.m_pzHovered = false;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewZoomSurface(evt: ref<PreviewZoomSurfaceEvent>) -> Bool {
    this.PreviewZoomApplySurface();
    return true;
}

// paperDoll, its canvas and the surface all become centred 4000 x 8000 boxes.
@addMethod(gameuiInventoryGameController)
private func PreviewZoomApplySurface() -> Void {
    let paperDoll: ref<inkCompoundWidget> = inkWidgetRef.Get(this.m_paperDollWidget) as inkCompoundWidget;
    if !IsDefined(paperDoll) { return; }
    PreviewZoomEnlarge(paperDoll);
    let canvas: wref<inkWidget> = paperDoll.GetWidgetByPathName(n"canvas");
    if IsDefined(canvas) { PreviewZoomEnlarge(canvas); }
    let surface: wref<inkWidget> = this.PreviewViewSurface();
    if IsDefined(surface) {
        PreviewZoomEnlarge(surface);
        let margin: inkMargin = surface.GetMargin();
        margin.top = PreviewZoomConfig.InventoryTop();
        surface.SetMargin(margin);
    }
}

public func PreviewZoomEnlarge(widget: wref<inkWidget>) -> Void {
    widget.SetFitToContent(false);
    widget.SetSizeRule(inkESizeRule.Fixed);
    widget.SetSize(PreviewZoomConfig.SurfaceWidth(), PreviewZoomConfig.SurfaceHeight());
    widget.SetAnchor(inkEAnchor.Centered);
    widget.SetAnchorPoint(0.5, 0.5);
    widget.SetHAlign(inkEHorizontalAlign.Center);
    widget.SetVAlign(inkEVerticalAlign.Center);
}

// Free view uses zoom step 0 and the higher framing; equipment-area views keep vanilla's
// cameras, which are framed for a lower surface.
@wrapMethod(gameuiInventoryGameController)
private final func StartModeTransitionAnimation(opt displayData: InventoryItemDisplayData) -> Void {
    wrappedMethod(displayData);
    let free: Bool = this.PreviewViewInDefaultMode();
    let surface: wref<inkWidget> = this.PreviewViewSurface();
    if IsDefined(surface) {
        let margin: inkMargin = surface.GetMargin();
        margin.top = free ? PreviewZoomConfig.InventoryTop() : PreviewZoomConfig.InventoryAreaTop();
        surface.SetMargin(margin);
    }
    if free {
        this.m_pzZoom = 0;
        this.QueueEvent(PreviewZoomCameraEvent(0));
    }
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewZoomEnter(evt: ref<inkPointerEvent>) -> Bool {
    this.m_pzHovered = true;
    return false;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewZoomLeave(evt: ref<inkPointerEvent>) -> Bool {
    this.m_pzHovered = false;
    return false;
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewZoomRelative(evt: ref<inkPointerEvent>) -> Bool {
    if this.m_pzPanHeld && (evt.IsAction(n"mouse_x") || evt.IsAction(n"mouse_y")) {
        if this.m_pzSkipMove {
            this.m_pzSkipMove = false;
            return false;
        }
        PreviewZoomPan(this.PreviewViewSurface(), evt);
        // X and Y arrive as separate events; consuming X can keep Y from arriving.
        return false;
    }
    if !this.m_pzHovered || !this.PreviewViewInDefaultMode()
        || !evt.IsAction(n"mouse_wheel") || evt.GetAxisData() == 0.0 {
        return false;
    }
    let preview: wref<inkPuppetPreviewGameController> = PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).m_inventoryPreview;
    if !IsDefined(preview) || !preview.PreviewMoveWheel(evt, this.PreviewViewSurface()) {
        this.PreviewZoomStep(evt.GetAxisData() > 0.0 ? 1 : -1);
    }
    evt.Consume();
    return true;
}

public func PreviewZoomPan(surface: wref<inkWidget>, evt: ref<inkPointerEvent>) -> Void {
    if !IsDefined(surface) { return; }
    let margin: inkMargin = surface.GetMargin();
    if evt.IsAction(n"mouse_x") {
        margin.left += evt.GetAxisData();
    } else {
        margin.top -= evt.GetAxisData();
    }
    surface.SetMargin(margin);
}

@addMethod(gameuiInventoryGameController)
private func PreviewZoomStep(direction: Int32) -> Void {
    this.m_pzZoom = Clamp(this.m_pzZoom + direction, 0, PreviewZoomConfig.Steps() - 1);
    this.QueueEvent(PreviewZoomCameraEvent(this.m_pzZoom));
    this.PreviewViewSaveZoom();
}

@addMethod(gameuiInventoryGameController)
private cb func OnPreviewZoomKey(evt: ref<KeyInputEvent>) -> Void {
    let key: EInputKey = evt.GetKey();
    let action: EInputAction = evt.GetAction();
    let free: Bool = this.PreviewViewInDefaultMode();
    if PreviewZoomPad.IsThumb(key) {
        let result: Int32 = this.m_pzPad.Key(key, action, free);
        if result == 2 {
            this.PreviewZoomStopRepeat();
            this.PreviewZoomReset();
        } else {
            if result != 0 {
                this.PreviewZoomStep(result);
                this.PreviewZoomStartRepeat(PreviewZoomConfig.RepeatDelay());
            }
        }
        return;
    }
    if Equals(key, PreviewZoomConfig.ResetKey()) {
        if Equals(action, EInputAction.IACT_Press) && free {
            this.PreviewZoomReset();
        }
        return;
    }
    if Equals(key, PreviewZoomConfig.PanKey()) {
        if Equals(action, EInputAction.IACT_Press) {
            this.m_pzPanHeld = this.m_pzHovered && free;
            this.m_pzSkipMove = this.m_pzPanHeld;
        } else {
            if Equals(action, EInputAction.IACT_Release) { this.m_pzPanHeld = false; }
        }
    }
}

@addMethod(gameuiInventoryGameController)
private func PreviewZoomStartRepeat(delay: Float) -> Void {
    this.PreviewZoomStopRepeat();
    this.m_pzRepeat = PreviewZoomTimer(this.GetRootWidget(), delay);
    this.m_pzRepeat.RegisterToCallback(inkanimEventType.OnFinish, this, n"OnPreviewZoomRepeat");
}

@addMethod(gameuiInventoryGameController)
private func PreviewZoomStopRepeat() -> Void {
    if IsDefined(this.m_pzRepeat) {
        this.m_pzRepeat.UnregisterFromAllCallbacks(inkanimEventType.OnFinish);
        this.m_pzRepeat.Stop();
        this.m_pzRepeat = null;
    }
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewZoomRepeat(proxy: ref<inkAnimProxy>) -> Bool {
    this.m_pzRepeat = null;
    if !IsDefined(this.m_pzPad) || this.m_pzPad.m_hold == 0 || !this.PreviewViewInDefaultMode() {
        return false;
    }
    this.PreviewZoomStep(this.m_pzPad.m_hold);
    this.PreviewZoomStartRepeat(PreviewZoomConfig.RepeatInterval());
    return true;
}

// Zoom step 0, surface back to its default position, PreviewMove's turns and scale undone.
// An explicit reset is remembered (PreviewView.reds); the reset after the wardrobe is not.
@addMethod(gameuiInventoryGameController)
public func PreviewZoomReset() -> Void {
    let surface: wref<inkWidget> = this.PreviewViewSurface();
    if IsDefined(surface) {
        let margin: inkMargin = surface.GetMargin();
        margin.left = 0.0;
        margin.top = PreviewZoomConfig.InventoryTop();
        surface.SetMargin(margin);
    }
    this.m_pzZoom = 0;
    this.QueueEvent(PreviewZoomCameraEvent(0));
    if !this.m_pvAutomaticReset { this.PreviewViewSaveZoom(); }
    let preview: wref<inkPuppetPreviewGameController> = PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).m_inventoryPreview;
    if IsDefined(preview) { preview.PreviewMoveReset(surface); }
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewZoomReturn(evt: ref<PreviewZoomReturnEvent>) -> Bool {
    this.m_pvAutomaticReset = true;
    this.PreviewZoomReset();
    this.m_pvAutomaticReset = false;
    this.PreviewViewRestoreZoom();
    if evt.pass < 1 {
        let next: ref<PreviewZoomReturnEvent> = new PreviewZoomReturnEvent();
        next.pass = evt.pass + 1;
        GameInstance.GetDelaySystem(this.GetPlayerControlledObject().GetGame()).DelayEventNextFrame(this, next);
    }
    return true;
}

// --- Wardrobe (Equipment-EX) --------------------------------------------------------------

@addField(inkPreviewGameController)
public let m_pzWardrobe: Bool;

@addField(inkPreviewGameController)
public let m_pzWardrobeZoom: Int32;

// The image showing V on the wardrobe.
@addField(inkPreviewGameController)
public let m_pzWardrobeImage: wref<inkWidget>;

@addField(inkPreviewGameController)
private let m_pzWardrobeCollider: wref<inkWidget>;

@addField(inkPreviewGameController)
private let m_pzWardrobeHovered: Bool;

@addField(inkPreviewGameController)
private let m_pzWardrobePanHeld: Bool;

@addField(inkPreviewGameController)
private let m_pzWardrobeSkipMove: Bool;

@addField(inkPreviewGameController)
private let m_pzWardrobePad: ref<PreviewZoomPad>;

@addField(inkPreviewGameController)
private let m_pzWardrobeRepeat: ref<inkAnimProxy>;

public class PreviewZoomWardrobeEvent extends Event {}

// Equipment-EX's wardrobe reuses the inventory's portrait render on its own image. That image
// gets the same enlarged geometry, and a fixed collider of ours takes the input: panning moves
// the image, so a hitbox on the image itself would run away from V.
@wrapMethod(inkPreviewGameController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();
    let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
    if !IsDefined(root) || !PreviewZoomIsWardrobe(root) {
        return result;
    }
    let image: wref<inkWidget> = root.GetWidgetByPathName(n"wrapper/preview");
    if !IsDefined(image) { image = root.GetWidgetByPathName(n"wardrobe/wrapper/preview"); }
    if !IsDefined(image) { image = root.GetWidgetByPathName(n"Root/wardrobe/wrapper/wrapper/preview"); }
    if !IsDefined(image) {
        PreviewViewLog("wardrobe: preview image not found, zoom controls off");
        return result;
    }
    PreviewZoomEnlarge(image);
    image.SetMargin(new inkMargin(PreviewZoomConfig.WardrobeLeft(), PreviewZoomConfig.WardrobeTop(), 0.0, 0.0));
    image.SetInteractive(false);

    let collider: wref<inkWidget> = root.GetWidgetByPathName(n"previewZoomCollider");
    if !IsDefined(collider) {
        let created: ref<inkCanvas> = new inkCanvas();
        created.SetName(n"previewZoomCollider");
        created.Reparent(root, root.GetNumChildren());
        collider = created;
    }
    // Last root child, so it wins hit-testing over Equipment-EX's full-screen outfit_manager
    // in its region around V.
    root.ReorderChild(collider, root.GetNumChildren());
    collider.SetInteractive(true);
    collider.SetFitToContent(false);
    collider.SetSizeRule(inkESizeRule.Fixed);
    collider.SetSize(PreviewZoomConfig.WardrobeColliderWidth(), 2000.0);
    collider.SetAnchor(inkEAnchor.Centered);
    collider.SetAnchorPoint(0.5, 0.5);
    collider.SetHAlign(inkEHorizontalAlign.Center);
    collider.SetVAlign(inkEVerticalAlign.Center);
    collider.SetMargin(new inkMargin(-250.0, 0.0, 0.0, 0.0));
    // The screen's own preview callbacks (drag rotation, hints) move from the image to it.
    collider.RegisterToCallback(n"OnPress", this, n"OnPreviewPress");
    collider.RegisterToCallback(n"OnEnter", this, n"OnPreviewHoverOver");
    collider.RegisterToCallback(n"OnLeave", this, n"OnPreviewHoverOut");
    collider.RegisterToCallback(n"OnEnter", this, n"OnPreviewZoomWardrobeEnter");
    collider.RegisterToCallback(n"OnLeave", this, n"OnPreviewZoomWardrobeLeave");
    collider.RegisterToCallback(n"OnRelative", this, n"OnPreviewZoomWardrobeRelative");
    GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnPreviewZoomWardrobeKey", true);

    this.m_pzWardrobe = true;
    this.m_pzWardrobeZoom = 0;
    this.m_pzWardrobeImage = image;
    this.m_pzWardrobeCollider = collider;
    this.m_pzWardrobeHovered = false;
    this.m_pzWardrobePanHeld = false;
    this.m_pzWardrobePad = new PreviewZoomPad();
    // Rotation input only while the cursor is over V.
    this.SetInputDisabled(true);

    // This runs inside Equipment-EX's own OnInitialize; finish once it has added its widgets.
    let player: wref<GameObject> = this.GetPlayerControlledObject();
    if IsDefined(player) {
        GameInstance.GetDelaySystem(player.GetGame()).DelayEventNextFrame(this, new PreviewZoomWardrobeEvent());
    }
    return result;
}

// The wardrobe screen sits under a widget named wardrobe, or holds Equipment-EX's vendor panel.
public func PreviewZoomIsWardrobe(root: ref<inkCompoundWidget>) -> Bool {
    let current: wref<inkWidget> = root;
    let depth: Int32 = 0;
    while IsDefined(current) && depth < 8 {
        if Equals(current.GetName(), n"wardrobe") { return true; }
        current = current.GetParentWidget();
        depth += 1;
    }
    return IsDefined(root.GetWidgetByPathName(n"wrapper/wrapper/vendorPanel"));
}

@addMethod(inkPreviewGameController)
protected cb func OnPreviewZoomWardrobeInit(evt: ref<PreviewZoomWardrobeEvent>) -> Bool {
    if !this.m_pzWardrobe { return false; }
    if IsDefined(this.m_pzWardrobeCollider) {
        let parent: wref<inkCompoundWidget> = this.m_pzWardrobeCollider.GetParentWidget() as inkCompoundWidget;
        if IsDefined(parent) { parent.ReorderChild(this.m_pzWardrobeCollider, parent.GetNumChildren()); }
    }
    this.PreviewZoomWardrobeCamera();
    return true;
}

@wrapMethod(inkPreviewGameController)
protected cb func OnUninitialize() -> Bool {
    if this.m_pzWardrobe {
        if IsDefined(this.m_pzWardrobeCollider) {
            this.m_pzWardrobeCollider.UnregisterFromCallback(n"OnPress", this, n"OnPreviewPress");
            this.m_pzWardrobeCollider.UnregisterFromCallback(n"OnEnter", this, n"OnPreviewHoverOver");
            this.m_pzWardrobeCollider.UnregisterFromCallback(n"OnLeave", this, n"OnPreviewHoverOut");
            this.m_pzWardrobeCollider.UnregisterFromCallback(n"OnEnter", this, n"OnPreviewZoomWardrobeEnter");
            this.m_pzWardrobeCollider.UnregisterFromCallback(n"OnLeave", this, n"OnPreviewZoomWardrobeLeave");
            this.m_pzWardrobeCollider.UnregisterFromCallback(n"OnRelative", this, n"OnPreviewZoomWardrobeRelative");
        }
        GameInstance.GetCallbackSystem().UnregisterCallback(n"Input/Key", this, n"OnPreviewZoomWardrobeKey");
        this.PreviewZoomWardrobeStopRepeat();
        this.SetInputDisabled(false);
        this.m_pzWardrobe = false;
        this.m_pzWardrobeHovered = false;
        this.m_pzWardrobePanHeld = false;
        this.m_pzWardrobeImage = null;
        this.m_pzWardrobeCollider = null;
        // Back on the inventory: reset its view, then PreviewView restores the saved zoom.
        let player: wref<GameObject> = this.GetPlayerControlledObject();
        if IsDefined(player) {
            let inventory: wref<gameuiInventoryGameController> = PreviewPosesState.Get(player.GetGame()).m_inventory;
            if IsDefined(inventory) {
                GameInstance.GetDelaySystem(player.GetGame()).DelayEventNextFrame(inventory, new PreviewZoomReturnEvent());
            }
        }
    }
    return wrappedMethod();
}

@addMethod(inkPreviewGameController)
protected cb func OnPreviewZoomWardrobeEnter(evt: ref<inkPointerEvent>) -> Bool {
    this.m_pzWardrobeHovered = true;
    this.SetInputDisabled(false);
    return false;
}

@addMethod(inkPreviewGameController)
protected cb func OnPreviewZoomWardrobeLeave(evt: ref<inkPointerEvent>) -> Bool {
    this.m_pzWardrobeHovered = false;
    this.m_pzWardrobePanHeld = false;
    this.SetInputDisabled(true);
    if IsDefined(this.m_pzWardrobePad) { this.m_pzWardrobePad.Clear(); }
    this.PreviewZoomWardrobeStopRepeat();
    return false;
}

@addMethod(inkPreviewGameController)
protected cb func OnPreviewZoomWardrobeRelative(evt: ref<inkPointerEvent>) -> Bool {
    if this.m_pzWardrobePanHeld && (evt.IsAction(n"mouse_x") || evt.IsAction(n"mouse_y")) {
        if this.m_pzWardrobeSkipMove {
            this.m_pzWardrobeSkipMove = false;
            return false;
        }
        PreviewZoomPan(this.m_pzWardrobeImage, evt);
        return false;
    }
    if !this.m_pzWardrobe || !evt.IsAction(n"mouse_wheel") || evt.GetAxisData() == 0.0 {
        return false;
    }
    let preview: wref<inkPuppetPreviewGameController> = this.PreviewMoveTarget();
    if !IsDefined(preview) || !preview.PreviewMoveWheel(evt, this.m_pzWardrobeImage) {
        this.PreviewZoomWardrobeStep(evt.GetAxisData() > 0.0 ? 1 : -1);
    }
    evt.Consume();
    return true;
}

@addMethod(inkPreviewGameController)
private cb func OnPreviewZoomWardrobeKey(evt: ref<KeyInputEvent>) -> Void {
    let key: EInputKey = evt.GetKey();
    let action: EInputAction = evt.GetAction();
    let active: Bool = this.m_pzWardrobe && this.m_pzWardrobeHovered;
    if PreviewZoomPad.IsThumb(key) {
        if !IsDefined(this.m_pzWardrobePad) { return; }
        let result: Int32 = this.m_pzWardrobePad.Key(key, action, active);
        if result == 2 {
            this.PreviewZoomWardrobeStopRepeat();
            this.PreviewZoomWardrobeReset();
        } else {
            if result != 0 {
                this.PreviewZoomWardrobeStep(result);
                this.PreviewZoomWardrobeStartRepeat(PreviewZoomConfig.RepeatDelay());
            }
        }
        return;
    }
    if Equals(key, PreviewZoomConfig.ResetKey()) {
        if Equals(action, EInputAction.IACT_Press) && active {
            this.PreviewZoomWardrobeReset();
        }
        return;
    }
    if Equals(key, PreviewZoomConfig.PanKey()) {
        if Equals(action, EInputAction.IACT_Press) {
            this.m_pzWardrobePanHeld = active;
            this.m_pzWardrobeSkipMove = active;
        } else {
            if Equals(action, EInputAction.IACT_Release) { this.m_pzWardrobePanHeld = false; }
        }
    }
}

@addMethod(inkPreviewGameController)
private func PreviewZoomWardrobeStep(direction: Int32) -> Void {
    this.m_pzWardrobeZoom = Clamp(this.m_pzWardrobeZoom + direction, 0, PreviewZoomConfig.Steps() - 1);
    this.PreviewZoomWardrobeCamera();
}

@addMethod(inkPreviewGameController)
public func PreviewZoomWardrobeCamera() -> Void {
    let player: wref<GameObject> = this.GetPlayerControlledObject();
    let camera: wref<inkInventoryPuppetPreviewGameController> = IsDefined(player) ? PreviewPosesState.Get(player.GetGame()).m_cameraPreview : null;
    if !IsDefined(camera) {
        PreviewViewLog("wardrobe: no inventory puppet preview to zoom");
        return;
    }
    camera.QueueEvent(PreviewZoomCameraEvent(this.m_pzWardrobeZoom));
}

@addMethod(inkPreviewGameController)
private func PreviewZoomWardrobeReset() -> Void {
    if IsDefined(this.m_pzWardrobeImage) {
        let margin: inkMargin = this.m_pzWardrobeImage.GetMargin();
        margin.left = PreviewZoomConfig.WardrobeLeft();
        margin.top = PreviewZoomConfig.WardrobeTop();
        this.m_pzWardrobeImage.SetMargin(margin);
    }
    this.m_pzWardrobePanHeld = false;
    this.m_pzWardrobeZoom = 0;
    this.PreviewZoomWardrobeCamera();
    let preview: wref<inkPuppetPreviewGameController> = this.PreviewMoveTarget();
    if IsDefined(preview) { preview.PreviewMoveReset(this.m_pzWardrobeImage); }
}

@addMethod(inkPreviewGameController)
private func PreviewZoomWardrobeStartRepeat(delay: Float) -> Void {
    this.PreviewZoomWardrobeStopRepeat();
    this.m_pzWardrobeRepeat = PreviewZoomTimer(this.GetRootWidget(), delay);
    this.m_pzWardrobeRepeat.RegisterToCallback(inkanimEventType.OnFinish, this, n"OnPreviewZoomWardrobeRepeat");
}

@addMethod(inkPreviewGameController)
private func PreviewZoomWardrobeStopRepeat() -> Void {
    if IsDefined(this.m_pzWardrobeRepeat) {
        this.m_pzWardrobeRepeat.UnregisterFromAllCallbacks(inkanimEventType.OnFinish);
        this.m_pzWardrobeRepeat.Stop();
        this.m_pzWardrobeRepeat = null;
    }
}

@addMethod(inkPreviewGameController)
protected cb func OnPreviewZoomWardrobeRepeat(proxy: ref<inkAnimProxy>) -> Bool {
    this.m_pzWardrobeRepeat = null;
    if !this.m_pzWardrobe || !this.m_pzWardrobeHovered || !IsDefined(this.m_pzWardrobePad)
        || this.m_pzWardrobePad.m_hold == 0 {
        return false;
    }
    this.PreviewZoomWardrobeStep(this.m_pzWardrobePad.m_hold);
    this.PreviewZoomWardrobeStartRepeat(PreviewZoomConfig.RepeatInterval());
    return true;
}

// The wardrobe's preview: this controller when it is one, else the one PreviewPoses tracks.
@addMethod(inkPreviewGameController)
private func PreviewMoveTarget() -> wref<inkPuppetPreviewGameController> {
    let preview: wref<inkPuppetPreviewGameController> = this as inkPuppetPreviewGameController;
    if IsDefined(preview) && IsDefined(preview.GetGamePuppet()) {
        return preview;
    }
    return PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).m_preview;
}
