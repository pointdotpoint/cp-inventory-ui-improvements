// PreviewMove: modifier + mouse wheel moves and turns V on the inventory and wardrobe preview,
// with PhotoModeUIImprovements' default keys:
//   Shift + wheel            X (left/right)    Shift + Alt + wheel         yaw
//   Ctrl + wheel             Y (nearer/farther) Ctrl + Alt + wheel         pitch
//   Alt + wheel              Z (up/down)       Ctrl + Shift + Alt + wheel  roll
//   Ctrl + Shift + wheel     step (PreviewMoveConfig ladder, metres and degrees together)
// The wheel arrives through PreviewZoom's handlers (PreviewZoom.reds), so this works with the
// cursor over V, where the plain wheel zooms. PreviewZoom's reset (V) puts V back.
//
// The preview puts the puppet back where its scene places it every frame, so writing the
// puppet's transform (Codeware's SetWorldTransform) was undone at once. Turns use the
// preview's native Rotate (yaw, as drag rotation does) and RotateVector (pitch, roll; vanilla's
// item preview passes yaw in z and pitch in y). Moves act on the image that shows V's render,
// as dragging with the middle mouse button does: X and Z shift its margin, Y scales it.

public abstract class PreviewMoveConfig {
    // 0 X, 1 Y, 2 Z, 3 step, 4 yaw, 5 pitch, 6 roll; -1 nothing (plain wheel: PreviewZoom zooms).
    public static func Action(shift: Bool, ctrl: Bool, alt: Bool) -> Int32 {
        if shift && ctrl && alt { return 6; }
        if ctrl && alt { return 5; }
        if shift && alt { return 4; }
        if shift && ctrl { return 3; }
        if shift { return 0; }
        if ctrl { return 1; }
        if alt { return 2; }
        return -1;
    }

    // Steps by rung, metres and degrees per notch. Switches rather than arrays: arrays returned
    // by static functions came back empty at runtime in this setup.
    public static func Rungs() -> Int32 = 10
    public static func DefaultRung() -> Int32 = 5

    public static func Metres(rung: Int32) -> Float {
        switch rung {
            case 0: return 0.001;
            case 1: return 0.002;
            case 2: return 0.005;
            case 3: return 0.01;
            case 4: return 0.02;
            case 5: return 0.05;
            case 6: return 0.1;
            case 7: return 0.25;
            case 8: return 0.5;
        }
        return 1.0;
    }

    public static func Degrees(rung: Int32) -> Float {
        switch rung {
            case 0: return 0.1;
            case 1: return 0.2;
            case 2: return 0.5;
            case 3: return 1.0;
            case 4: return 2.0;
            case 5: return 5.0;
            case 6: return 10.0;
            case 7: return 15.0;
            case 8: return 20.0;
        }
        return 30.0;
    }

    // Image margin units per metre of X or Z.
    public static func UnitsPerMetre() -> Float = 1000.0

    public static func MinScale() -> Float = 0.25
    public static func MaxScale() -> Float = 3.0
}

@addField(inkPuppetPreviewGameController)
private let m_pmRung: Int32;

@addField(inkPuppetPreviewGameController)
private let m_pmRungSet: Bool;

// Pitch and roll turned so far, undone by PreviewZoom's reset.
@addField(inkPuppetPreviewGameController)
private let m_pmPitch: Float;

@addField(inkPuppetPreviewGameController)
private let m_pmRoll: Float;

// The first pitch or roll is read back once, to log whether the puppet preview honours it.
@addField(inkPuppetPreviewGameController)
private let m_pmChecked: Bool;

@addField(inkPuppetPreviewGameController)
private let m_pmCheckBefore: EulerAngles;

@addField(inkPuppetPreviewGameController)
private let m_pmCheckProxy: ref<inkAnimProxy>;

// True when the wheel event was a move (the caller consumes it instead of zooming).
// image: the widget showing V's render on the current screen.
@addMethod(inkPuppetPreviewGameController)
public func PreviewMoveWheel(evt: ref<inkPointerEvent>, image: wref<inkWidget>) -> Bool {
    if !evt.IsAction(n"mouse_wheel") || evt.GetAxisData() == 0.0 {
        return false;
    }
    let action: Int32 = PreviewMoveConfig.Action(evt.IsShiftDown(), evt.IsControlDown(), evt.IsAltDown());
    if action < 0 {
        return false;
    }
    if !this.m_pmRungSet {
        this.m_pmRung = PreviewMoveConfig.DefaultRung();
        this.m_pmRungSet = true;
    }
    let sign: Float = evt.GetAxisData() > 0.0 ? 1.0 : -1.0;
    if action == 3 {
        this.m_pmRung = Clamp(this.m_pmRung + (sign > 0.0 ? 1 : -1), 0, PreviewMoveConfig.Rungs() - 1);
        PreviewViewLog("move V step " + FloatToStringPrec(PreviewMoveConfig.Metres(this.m_pmRung), 3) + " m / "
            + FloatToStringPrec(PreviewMoveConfig.Degrees(this.m_pmRung), 1) + " deg");
        return true;
    }
    let metres: Float = PreviewMoveConfig.Metres(this.m_pmRung) * sign;
    let degrees: Float = PreviewMoveConfig.Degrees(this.m_pmRung) * sign;
    switch action {
        case 0:
        case 2:
            if IsDefined(image) {
                let margin: inkMargin = image.GetMargin();
                let units: Float = metres * PreviewMoveConfig.UnitsPerMetre();
                if action == 0 {
                    margin.left += units;
                } else {
                    margin.top -= units;
                }
                image.SetMargin(margin);
            }
            break;
        case 1:
            if IsDefined(image) {
                let scale: Vector2 = image.GetScale();
                let next: Float = ClampF(scale.X * (1.0 + metres), PreviewMoveConfig.MinScale(), PreviewMoveConfig.MaxScale());
                image.SetScale(new Vector2(next, next));
            }
            break;
        case 4:
            this.Rotate(degrees);
            break;
        case 5:
            this.PreviewMoveTurn(degrees, 0.0);
            break;
        case 6:
            this.PreviewMoveTurn(0.0, degrees);
            break;
    }
    return true;
}

@addMethod(inkPuppetPreviewGameController)
private func PreviewMoveTurn(pitch: Float, roll: Float) -> Void {
    let puppet: wref<gamePuppet> = this.GetGamePuppet();
    if !this.m_pmChecked && IsDefined(puppet) {
        this.m_pmChecked = true;
        this.m_pmCheckBefore = Quaternion.ToEulerAngles(puppet.GetWorldOrientation());
        this.m_pmCheckProxy = this.PreviewMoveTimer(0.25);
        this.m_pmCheckProxy.RegisterToCallback(inkanimEventType.OnFinish, this, n"OnPreviewMoveCheck");
    }
    this.m_pmPitch += pitch;
    this.m_pmRoll += roll;
    this.RotateVector(new Vector3(roll, pitch, 0.0));
}

// Menus run while the game is paused, so a one-shot ink animation is the timer.
@addMethod(inkPuppetPreviewGameController)
private func PreviewMoveTimer(duration: Float) -> ref<inkAnimProxy> {
    let interpolator: ref<inkAnimTransparency> = new inkAnimTransparency();
    interpolator.SetDuration(duration);
    interpolator.SetStartTransparency(1.0);
    interpolator.SetEndTransparency(1.0);
    let definition: ref<inkAnimDef> = new inkAnimDef();
    definition.AddInterpolator(interpolator);
    return this.GetRootWidget().PlayAnimation(definition);
}

@addMethod(inkPuppetPreviewGameController)
protected cb func OnPreviewMoveCheck(proxy: ref<inkAnimProxy>) -> Bool {
    let puppet: wref<gamePuppet> = this.GetGamePuppet();
    if !IsDefined(puppet) {
        return false;
    }
    let after: EulerAngles = Quaternion.ToEulerAngles(puppet.GetWorldOrientation());
    PreviewViewLog("move V: first pitch/roll turned the puppet from pitch " + ToString(this.m_pmCheckBefore.Pitch) + " roll "
        + ToString(this.m_pmCheckBefore.Roll) + " to pitch " + ToString(after.Pitch) + " roll " + ToString(after.Roll));
    return true;
}

// PreviewZoom's reset: undo pitch and roll and the image's scale. PreviewZoom resets the margin.
@addMethod(inkPuppetPreviewGameController)
public func PreviewMoveReset(image: wref<inkWidget>) -> Void {
    if this.m_pmPitch != 0.0 || this.m_pmRoll != 0.0 {
        this.RotateVector(new Vector3(-this.m_pmRoll, -this.m_pmPitch, 0.0));
        this.m_pmPitch = 0.0;
        this.m_pmRoll = 0.0;
    }
    if IsDefined(image) {
        image.SetScale(new Vector2(1.0, 1.0));
    }
}
