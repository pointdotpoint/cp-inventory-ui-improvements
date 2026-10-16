// This directory must sort after VFocus: redscript resolves added methods before wrappers.
import BetterVZoomWardrobe.*

@wrapMethod(gameuiInventoryGameController)
private func BetterVZoomInventoryGamepadZoom(zoomIn: Bool) -> Void {
    wrappedMethod(zoomIn);
    this.PreviewViewSaveZoom();
}

@wrapMethod(gameuiInventoryGameController)
private func BetterVZoomResetView() -> Void {
    wrappedMethod();
    if !this.m_pvAutomaticReset { this.PreviewViewSaveZoom(); }
}

@wrapMethod(gameuiInventoryGameController)
protected cb func OnBetterVZoomRestoreInventoryViewEvent(evt: ref<BetterVZoomRestoreInventoryViewEvent>) -> Bool {
    // VFocus uses the same reset for explicit input and automatic Wardrobe return.
    this.m_pvAutomaticReset = true;
    let result: Bool = wrappedMethod(evt);
    this.m_pvAutomaticReset = false;
    this.PreviewViewRestoreZoom();
    return result;
}

@wrapMethod(gameuiInventoryGameController)
protected cb func OnBetterVZoomPuppetRelative(evt: ref<inkPointerEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    if result { this.PreviewViewSaveZoom(); }
    return result;
}

