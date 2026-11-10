// Wardrobe UI Improvements: repairs the inventory after a quick wardrobe close.
//
// Equipment-EX opens its wardrobe inside the inventory with ShowWardrobeScreen, which plays the
// inventory's default_wrapper_outro and drops the animation handle; HideWardrobeScreen plays
// default_wrapper_Intro without stopping it (vanilla's StartModeTransitionAnimation calls
// GotoEndAndStop on the outro first). Opening the wardrobe stalls the game, so a close right after
// the opening lands while the outro still runs, the outro ends last, and the inventory's panels
// (the RELATED links with the WARDROBE button above all) stay faded out and unclickable until the
// inventory is rebuilt. Reproduced in game in 1.0.4 with a click then Esc 0.3 s later, and with
// A then B on a pad.
//
// Equipment-EX's own methods cannot be wrapped (they are script-defined), but vanilla's OnBack,
// which it wraps to close the wardrobe, can. After a close, the inventory checks the Intro's
// targets once its animations are over; any still faded means the outro won, and the Intro is
// played again. A wardrobe widget left behind while Equipment-EX counts it as closed (its fade-out
// never finished) is removed, since ShowWardrobeScreen refuses to open while one exists.

@addField(gameuiInventoryGameController)
private let m_wtCloseCheck: ref<inkAnimProxy>;

@addField(gameuiInventoryGameController)
private let m_wtCloseChecks: Int32;

@wrapMethod(gameuiInventoryGameController)
protected cb func OnBack(userData: ref<IScriptable>) -> Bool {
    let wasOpen: Bool = this.m_wardrobeReady && IsDefined(this.GetChildWidgetByPath(n"wardrobe"));
    let result: Bool = wrappedMethod(userData);
    if wasOpen && !this.m_wardrobeReady {
        this.m_wtCloseChecks = 0;
        this.WardrobeTabsScheduleCloseCheck();
    }
    return result;
}

@wrapMethod(gameuiInventoryGameController)
protected cb func OnUninitialize() -> Bool {
    if IsDefined(this.m_wtCloseCheck) {
        this.m_wtCloseCheck.Stop();
        this.m_wtCloseCheck = null;
    }
    return wrappedMethod();
}

// A timer on the inventory's clock: an animation that changes nothing.
@addMethod(gameuiInventoryGameController)
private func WardrobeTabsScheduleCloseCheck() -> Void {
    if IsDefined(this.m_wtCloseCheck) {
        this.m_wtCloseCheck.Stop();
    }
    let interpolator: ref<inkAnimTransparency> = new inkAnimTransparency();
    interpolator.SetDuration(1.0);
    interpolator.SetStartTransparency(1.0);
    interpolator.SetEndTransparency(1.0);
    let definition: ref<inkAnimDef> = new inkAnimDef();
    definition.AddInterpolator(interpolator);
    this.m_wtCloseCheck = this.GetRootWidget().PlayAnimation(definition);
    this.m_wtCloseCheck.RegisterToCallback(inkanimEventType.OnFinish, this, n"OnWardrobeTabsCloseCheck");
}

@addMethod(gameuiInventoryGameController)
protected cb func OnWardrobeTabsCloseCheck(anim: ref<inkAnimProxy>) -> Bool {
    this.m_wtCloseCheck = null;
    // Reopened in the meantime, or another inventory mode: nothing to repair.
    if this.m_wardrobeReady || NotEquals(this.m_mode, InventoryModes.Default) {
        return false;
    }
    if IsDefined(this.GetChildWidgetByPath(n"wardrobe")) {
        this.GetRootCompoundWidget().RemoveChildByName(n"wardrobe");
        ModLog(n"WardrobeTabs", "Quick wardrobe close: removed a wardrobe left behind");
    }
    // Equipment-EX hides the paperdoll when its slide to the wardrobe's place ends
    // (OnPaperDollSlideComplete), even if the wardrobe has closed by then.
    if !inkWidgetRef.IsVisible(this.m_paperDollWidget) {
        inkWidgetRef.SetVisible(this.m_paperDollWidget, true);
        ModLog(n"WardrobeTabs", "Quick wardrobe close: paperdoll left hidden; shown again");
    }
    let faded: String = this.WardrobeTabsFadedIntroTarget();
    if NotEquals(faded, "") {
        this.m_wtCloseChecks += 1;
        ModLog(n"WardrobeTabs", "Quick wardrobe close: inventory panel " + faded + " left faded; replaying its intro (" + ToString(this.m_wtCloseChecks) + ")");
        let links: ref<inkWidget> = WardrobeTabsWidgetAt(this.GetRootCompoundWidget(), "1.9");
        if IsDefined(links) {
            links.SetVisible(true);
        }
        this.PlayLibraryAnimation(n"default_wrapper_Intro");
        // Check once more after the replay; give up after three tries.
        if this.m_wtCloseChecks < 3 {
            this.WardrobeTabsScheduleCloseCheck();
        }
    }
    return true;
}

// The widgets default_wrapper_Intro fades in (index paths from the root, read from
// inventory_screen_animations.inkanim); the first one still below full opacity, or "".
@addMethod(gameuiInventoryGameController)
private func WardrobeTabsFadedIntroTarget() -> String {
    let paths: array<String> = [
        "1.1.1", "1.1.0.0", "1.2.1", "1.2.0.0", "1.3.1", "1.3.0.0", "1.4.1", "1.4.0.0",
        "1.5.1", "1.5.0.0", "1.9.0", "1.9.1.0", "1.9.1.1", "1.9.1.2", "1.9.1.3", "1.9.1.4",
        "1.7.2", "1.7.1", "1.8.3", "1.8.1", "1.9"
    ];
    let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
    for path in paths {
        let widget: ref<inkWidget> = WardrobeTabsWidgetAt(root, path);
        // Hidden widgets are skipped (Equipment-EX hides two of the RELATED buttons), except the
        // RELATED list itself ("1.9", menuLinks): in game it was found hidden at opacity 0 after
        // the outro won, though no script hides it.
        if IsDefined(widget) && (widget.IsVisible() || Equals(path, "1.9")) && widget.GetOpacity() < 0.99 {
            return path + " (" + NameToString(widget.GetName()) + ")";
        }
    }
    return "";
}

public func WardrobeTabsWidgetAt(root: ref<inkCompoundWidget>, path: String) -> ref<inkWidget> {
    let widget: ref<inkWidget> = root;
    let parts: array<String> = StrSplit(path, ".");
    for part in parts {
        let compound: ref<inkCompoundWidget> = widget as inkCompoundWidget;
        let index: Int32 = StringToInt(part);
        if !IsDefined(compound) || index >= compound.GetNumChildren() {
            return null;
        }
        widget = compound.GetWidgetByIndex(index);
    }
    return widget;
}
