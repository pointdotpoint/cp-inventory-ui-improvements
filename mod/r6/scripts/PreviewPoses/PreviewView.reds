// PreviewView: remembers how V is framed on the inventory and wardrobe screens (zoom and
// position) and restores it the next time the screen opens. Stored in the save game next to
// the pose (persistent fields on PreviewPosesState). Wardrobe inherits Inventory's zoom.
//
// Zoom and position belong to PreviewZoom.reds, which this file reads and writes:
// - inventory: zoom step gameuiInventoryGameController.m_pzZoom (camera setup 12 + step),
//   position = margin of paperDoll/canvas/preview;
// - wardrobe: zoom step inkPreviewGameController.m_pzWardrobeZoom, position = margin of
//   m_pzWardrobeImage.
//
// Pan and rotation are sampled while the screen is open, because by the time a screen's
// OnUninitialize runs its preview widgets are already gone. PreviewZoom resets the view during the
// first frames after opening, so restoring waits a few frames and sampling starts after that.
//
// Inventory rotation is stored as a starting yaw; wardrobe keeps its front view.

public class PreviewViewZoomRestoreEvent extends Event {}

@addField(gameuiInventoryGameController)
private let m_pvAutomaticReset: Bool;

// Save input immediately: polling can miss the last wheel tick before closing.
@addMethod(gameuiInventoryGameController)
private func PreviewViewSaveZoom() -> Void {
    let state: ref<PreviewPosesState> = PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame());
    state.m_invZoom = this.m_pzZoom;
    state.m_invZoomValid = true;
}

@addMethod(gameuiInventoryGameController)
private func PreviewViewRestoreZoom() -> Void {
    let state: ref<PreviewPosesState> = PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame());
    if !this.PreviewViewInDefaultMode() || (!state.m_invZoomValid && !state.m_invViewValid) { return; }
    this.m_pzZoom = Clamp(state.m_invZoom, 0, 11);
    let cameraEvent: ref<gameuiPuppetPreview_SetCameraSetupEvent> = new gameuiPuppetPreview_SetCameraSetupEvent();
    cameraEvent.setupIndex = Cast<Uint32>(12 + this.m_pzZoom);
    this.QueueEvent(cameraEvent);
}

@wrapMethod(gameuiInventoryGameController)
private final func StartModeTransitionAnimation(opt displayData: InventoryItemDisplayData) -> Void {
    wrappedMethod(displayData);
    // Run after every wrapper has finished resetting the default-mode camera.
    GameInstance.GetDelaySystem(this.GetPlayerControlledObject().GetGame()).DelayEventNextFrame(this, new PreviewViewZoomRestoreEvent());
}

@addMethod(gameuiInventoryGameController)
protected cb func OnPreviewViewZoomRestore(evt: ref<PreviewViewZoomRestoreEvent>) -> Bool {
    let state: ref<PreviewPosesState> = PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame());
    if state.m_inventory != this { return false; }
    this.PreviewViewRestoreZoom();
    return true;
}

public class PreviewViewRestoreEvent extends Event {
    public let pass: Int32;
    public let generation: Int32;
}

public func PreviewViewLog(message: String) -> Void {
    ModLog(n"PreviewPoses", message);
}

@addField(inkPuppetPreviewGameController)
public let m_pvSampling: Bool;

@addField(inkPuppetPreviewGameController)
public let m_pvPoll: ref<inkAnimProxy>;

@addField(inkPuppetPreviewGameController)
private let m_pvRestoreGeneration: Int32;

@addField(inkPuppetPreviewGameController)
private let m_pvInitialYaw: Float;

@addField(inkPuppetPreviewGameController)
private let m_pvYawReady: Bool;

// Confirmed in game: setting yawDefault before the preview initializes sets V's starting
// rotation; -125 (the vanilla default) shows V from the front.
@wrapMethod(inkPreviewGameController)
protected cb func OnInitialize() -> Bool {
    let preview: ref<inkPuppetPreviewGameController> = this as inkPuppetPreviewGameController;
    if IsDefined(preview) && (preview.PreviewViewIsInventory() || preview.PreviewViewIsWardrobe()) {
        this.yawDefault = -125.0;
        if preview.PreviewViewIsInventory() {
            let player: wref<GameObject> = this.GetPlayerControlledObject();
            if IsDefined(player) {
                let state: ref<PreviewPosesState> = PreviewPosesState.Get(player.GetGame());
                if state.m_invRotationValid {
                    this.yawDefault = state.m_invYaw;
                }
            }
        }
    }
    return wrappedMethod();
}

@addMethod(inkPuppetPreviewGameController)
private func PreviewViewIsWardrobe() -> Bool {
    return this.IsA(n"EquipmentEx.WardrobeScreenController");
}

@addMethod(inkPuppetPreviewGameController)
private func PreviewViewIsInventory() -> Bool {
    return IsDefined(this as inkInventoryPuppetPreviewGameController);
}

@addMethod(gameuiInventoryGameController)
public func PreviewViewSurface() -> wref<inkWidget> {
    let paperDoll: ref<inkCompoundWidget> = inkWidgetRef.Get(this.m_paperDollWidget) as inkCompoundWidget;
    return IsDefined(paperDoll) ? paperDoll.GetWidgetByPathName(n"canvas/preview") : null;
}

@addMethod(gameuiInventoryGameController)
public func PreviewViewInDefaultMode() -> Bool {
    return Equals(this.m_mode, InventoryModes.Default);
}

@wrapMethod(gameuiInventoryGameController)
protected cb func OnSetUserData(userData: ref<IScriptable>) -> Bool {
    let result: Bool = wrappedMethod(userData);
    PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).m_inventory = this;
    GameInstance.GetDelaySystem(this.GetPlayerControlledObject().GetGame()).DelayEventNextFrame(this, new PreviewViewZoomRestoreEvent());
    return result;
}

@wrapMethod(inkPuppetPreviewGameController)
protected cb func OnPreviewInitialized() -> Bool {
    let result: Bool = wrappedMethod();
    if this.PreviewViewIsInventory() || this.PreviewViewIsWardrobe() {
        this.m_pvRestoreGeneration += 1;
        this.m_pvSampling = false;
        this.m_pvYawReady = false;
        if IsDefined(this.m_pvPoll) {
            this.m_pvPoll.UnregisterFromAllCallbacks(inkanimEventType.OnEndLoop);
            this.m_pvPoll.Stop();
            this.m_pvPoll = null;
        }
        let evt: ref<PreviewViewRestoreEvent> = new PreviewViewRestoreEvent();
        evt.generation = this.m_pvRestoreGeneration;
        GameInstance.GetDelaySystem(this.GetPlayerControlledObject().GetGame()).DelayEventNextFrame(this, evt);
    }
    return result;
}

@wrapMethod(inkPreviewGameController)
protected cb func OnUninitialize() -> Bool {
    let preview: ref<inkPuppetPreviewGameController> = this as inkPuppetPreviewGameController;
    if IsDefined(preview) {
        preview.m_pvRestoreGeneration += 1;
        preview.m_pvSampling = false;
    }
    if IsDefined(preview) && preview.PreviewViewIsWardrobe() {
        PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame()).ReleaseScreen(this);
    }
    if IsDefined(preview) && IsDefined(preview.m_pvPoll) {
        preview.m_pvPoll.UnregisterFromAllCallbacks(inkanimEventType.OnEndLoop);
        preview.m_pvPoll.Stop();
        preview.m_pvPoll = null;
    }
    wrappedMethod();
}

@addMethod(inkPuppetPreviewGameController)
protected cb func OnPreviewViewRestore(evt: ref<PreviewViewRestoreEvent>) -> Bool {
    // A closed or reinitialized preview must not restart a queued restoration chain.
    if evt.generation != this.m_pvRestoreGeneration { return false; }
    // Let PreviewZoom finish its own reset first; it applies over the first couple of frames.
    if evt.pass < 3 {
        let next: ref<PreviewViewRestoreEvent> = new PreviewViewRestoreEvent();
        next.pass = evt.pass + 1;
        next.generation = evt.generation;
        GameInstance.GetDelaySystem(this.GetPlayerControlledObject().GetGame()).DelayEventNextFrame(this, next);
        return true;
    }

    let state: ref<PreviewPosesState> = PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame());
    if this.PreviewViewIsWardrobe() {
        if this.m_pzWardrobe {
            let inventory: wref<gameuiInventoryGameController> = state.m_inventory;
            if IsDefined(inventory) {
                this.m_pzWardrobeZoom = inventory.m_pzZoom;
                let surface: wref<inkWidget> = inventory.PreviewViewSurface();
                if IsDefined(surface) && IsDefined(this.m_pzWardrobeImage) {
                    this.m_pzWardrobeImage.SetRenderTransformPivot(0.5, 0.5);
                    this.m_pzWardrobeImage.SetScale(surface.GetScale());
                }
            }
            this.PreviewZoomWardrobeCamera();
            if state.m_wardViewValid && IsDefined(this.m_pzWardrobeImage) {
                let margin: inkMargin = this.m_pzWardrobeImage.GetMargin();
                margin.left = state.m_wardLeft;
                margin.top = state.m_wardTop;
                this.m_pzWardrobeImage.SetMargin(margin);
            }
            PreviewViewLog("restored wardrobe view zoom=" + ToString(this.m_pzWardrobeZoom) + " left=" + ToString(state.m_wardLeft) + " top=" + ToString(state.m_wardTop));
        }
    } else {
        let inventory: wref<gameuiInventoryGameController> = state.m_inventory;
        if IsDefined(inventory) && inventory.PreviewViewInDefaultMode() {
            inventory.PreviewViewRestoreZoom();
            let surface: wref<inkWidget> = inventory.PreviewViewSurface();
            if state.m_invViewValid && IsDefined(surface) {
                let margin: inkMargin = surface.GetMargin();
                margin.left = state.m_invLeft;
                margin.top = state.m_invTop;
                surface.SetMargin(margin);
            }
            PreviewViewLog("restored inventory view zoom=" + ToString(state.m_invZoom) + " left=" + ToString(state.m_invLeft) + " top=" + ToString(state.m_invTop)
                + " surface=" + ToString(IsDefined(surface)));
        }
    }

    let puppet: wref<gamePuppet> = this.GetGamePuppet();
    if IsDefined(puppet) {
        let angles: EulerAngles = Quaternion.ToEulerAngles(puppet.GetWorldOrientation());
        this.m_pvInitialYaw = angles.Yaw;
        this.m_pvYawReady = true;
    }
    if this.PreviewViewIsInventory() {
        PreviewViewLog("inventory rotation initialized yaw=" + ToString(this.yawDefault));
    }
    this.PreviewViewStartPolling();
    return true;
}

@addMethod(inkPuppetPreviewGameController)
private func PreviewViewStartPolling() -> Void {
    let interpolator: ref<inkAnimTransparency> = new inkAnimTransparency();
    interpolator.SetDuration(0.25);
    interpolator.SetStartTransparency(1.0);
    interpolator.SetEndTransparency(1.0);
    let definition: ref<inkAnimDef> = new inkAnimDef();
    definition.AddInterpolator(interpolator);
    let options: inkAnimOptions;
    options.loopType = inkanimLoopType.Cycle;
    options.loopInfinite = true;
    this.m_pvPoll = this.GetRootWidget().PlayAnimationWithOptions(definition, options);
    this.m_pvPoll.RegisterToCallback(inkanimEventType.OnEndLoop, this, n"OnPreviewViewPoll");
    this.m_pvSampling = true;
}

// Records the current view so it is ready whenever the screen closes.
@addMethod(inkPuppetPreviewGameController)
protected cb func OnPreviewViewPoll(proxy: ref<inkAnimProxy>) -> Bool {
    if !this.m_pvSampling {
        return false;
    }
    let state: ref<PreviewPosesState> = PreviewPosesState.Get(this.GetPlayerControlledObject().GetGame());
    if this.PreviewViewIsWardrobe() {
        if this.m_pzWardrobe && IsDefined(this.m_pzWardrobeImage) {
            let margin: inkMargin = this.m_pzWardrobeImage.GetMargin();
            state.m_wardZoom = this.m_pzWardrobeZoom;
            state.m_wardLeft = margin.left;
            state.m_wardTop = margin.top;
            state.m_wardViewValid = true;
        }
    } else {
        this.PreviewViewCaptureInventory(state);
    }
    return true;
}

// Also called before Inventory releases its widgets, to capture the final adjustment.
@addMethod(inkPuppetPreviewGameController)
public func PreviewViewCaptureInventory(state: ref<PreviewPosesState>) -> Void {
    let inventory: wref<gameuiInventoryGameController> = state.m_inventory;
    if !this.m_pvSampling || !this.PreviewViewIsInventory() || !IsDefined(inventory)
        || !inventory.PreviewViewInDefaultMode() {
        return;
    }
    let surface: wref<inkWidget> = inventory.PreviewViewSurface();
    if IsDefined(surface) {
        let margin: inkMargin = surface.GetMargin();
        state.m_invLeft = margin.left;
        state.m_invTop = margin.top;
        state.m_invViewValid = true;
    }
    let puppet: wref<gamePuppet> = this.GetGamePuppet();
    if IsDefined(puppet) && this.m_pvYawReady {
        let angles: EulerAngles = Quaternion.ToEulerAngles(puppet.GetWorldOrientation());
        let delta: Float = angles.Yaw - this.m_pvInitialYaw;
        // Euler yaw wraps at +/-180 degrees. Keep the equivalent shortest delta.
        if delta > 180.0 {
            delta -= 360.0;
        } else {
            if delta < -180.0 { delta += 360.0; }
        }
        state.m_invYaw = this.yawDefault + delta;
        state.m_invRotationValid = true;
    }
}
