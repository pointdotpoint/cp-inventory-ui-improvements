// Experiment: can the hub menu show the game world instead of its engine-drawn backdrop?
//
// The red/teal backdrop is identical at every location, and no inventory or hub widget
// draws it, so it comes from the engine's hub-menu mode (inkMenuLayer_SetMenuModeEvent).
// The pause menu uses PauseMenu mode and only dims the visible world itself.
//
// Off by default: nothing changes until a mode is chosen from the CET console while a hub
// menu is open. The choice lasts until the game restarts and is reapplied on each open.
//   Game.GetScriptableSystemsContainer():Get("HubWorldBackdropTest"):Apply(2, false)
// Modes: 0 vanilla, 1 hub mode off, 2 hub mode off + pause mode on, 3 pause mode on too.
// The second argument turns the engine's background blur on or off.

public class HubWorldBackdropTest extends ScriptableSystem {
    private let m_hub: wref<MenuHubGameController>;
    private let m_mode: Int32;
    private let m_blur: Bool;
    private let m_hubModeOff: Bool;
    private let m_pauseModeOn: Bool;
    private let m_blurOn: Bool;

    public static func Get(game: GameInstance) -> ref<HubWorldBackdropTest> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"HubWorldBackdropTest") as HubWorldBackdropTest;
    }

    public func Attach(hub: ref<MenuHubGameController>) -> Void {
        this.m_hub = hub;
        this.m_hubModeOff = false;
        this.m_pauseModeOn = false;
        this.m_blurOn = false;
        this.Sync();
    }

    public func Apply(mode: Int32, blur: Bool) -> Void {
        this.m_mode = mode;
        this.m_blur = blur;
        if !IsDefined(this.m_hub) {
            ModLog(n"HubWorldBackdropTest", "mode " + IntToString(mode) + " stored; open a hub menu to apply it");
            return;
        }
        this.Sync();
    }

    // Send only the transitions needed to reach the chosen mode.
    private func Sync() -> Void {
        let hub: ref<MenuHubGameController> = this.m_hub;
        if !IsDefined(hub) {
            return;
        }
        let hubOff: Bool = this.m_mode == 1 || this.m_mode == 2;
        if NotEquals(hubOff, this.m_hubModeOff) {
            hub.HubWorldBackdropSend(inkMenuMode.HubMenu, hubOff ? inkMenuState.Disabled : inkMenuState.Enabled);
            this.m_hubModeOff = hubOff;
        }
        let pauseOn: Bool = this.m_mode == 2 || this.m_mode == 3;
        if NotEquals(pauseOn, this.m_pauseModeOn) {
            hub.HubWorldBackdropSend(inkMenuMode.PauseMenu, pauseOn ? inkMenuState.Enabled : inkMenuState.Disabled);
            this.m_pauseModeOn = pauseOn;
        }
        if NotEquals(this.m_blur, this.m_blurOn) {
            PopupStateUtils.SetBackgroundBlur(hub, this.m_blur);
            this.m_blurOn = this.m_blur;
        }
        ModLog(n"HubWorldBackdropTest", "applied mode " + IntToString(this.m_mode) + (this.m_blur ? " with blur" : " without blur"));
    }

    // Undo our extra state before the hub sends its own HubMenu Disabled.
    public func Detach() -> Void {
        let hub: ref<MenuHubGameController> = this.m_hub;
        if IsDefined(hub) {
            if this.m_pauseModeOn {
                hub.HubWorldBackdropSend(inkMenuMode.PauseMenu, inkMenuState.Disabled);
            }
            if this.m_blurOn {
                PopupStateUtils.SetBackgroundBlur(hub, false);
            }
        }
        this.m_hubModeOff = false;
        this.m_pauseModeOn = false;
        this.m_blurOn = false;
        this.m_hub = null;
    }
}

@addMethod(MenuHubGameController)
public func HubWorldBackdropSend(mode: inkMenuMode, state: inkMenuState) -> Void {
    let evt: ref<inkMenuLayer_SetMenuModeEvent> = new inkMenuLayer_SetMenuModeEvent();
    evt.Init(mode, state);
    this.QueueBroadcastEvent(evt);
}

@wrapMethod(MenuHubGameController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();
    HubWorldBackdropTest.Get(this.GetPlayerControlledObject().GetGame()).Attach(this);
    return result;
}

@wrapMethod(MenuHubGameController)
protected cb func OnUninitialize() -> Bool {
    HubWorldBackdropTest.Get(this.GetPlayerControlledObject().GetGame()).Detach();
    return wrappedMethod();
}
