#!/usr/bin/env python3
"""Builds a TEST-ONLY copy of the WardrobeTabs scripts that times the hover handlers.

    python3 -I tools/harness/instrument.py <scripts dir> <out project dir>

<scripts dir> is a WardrobeTabs folder (mod/r6/scripts/WardrobeTabs, or one exported from a
commit with `git archive`). The output is a project-shaped folder (mod/r6/scripts/WardrobeTabs
plus tools/compile-check.sh) so the compile check can run on it before it is installed.

OnWardrobeTabsHoverOver / OnWardrobeTabsHoverOut (hover in and out of buttons, slot rows, body
tiles and group heads) are renamed and called from timed wrappers. Every 20 hover events the
mod logs `timing: hover n=.. avg=.. max=.. ms` to the CET gamelog. The clock is
OverlayMapNative_NowMs() (dev setup only; EngineTime holds one value per frame).
"""
import os, re, shutil, sys

src, out = sys.argv[1], sys.argv[2]
project = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
dest = os.path.join(out, "mod/r6/scripts/WardrobeTabs")
shutil.rmtree(out, ignore_errors=True)
shutil.copytree(src, dest)
os.makedirs(os.path.join(out, "tools"))
shutil.copy(os.path.join(project, "tools/compile-check.sh"), os.path.join(out, "tools"))

path = os.path.join(dest, "WardrobeTabs.reds")
text = open(path).read()
for side in ("Over", "Out"):
    old = "protected cb func OnWardrobeTabsHover%s(" % side
    assert text.count(old) == 1, old
    text = text.replace(old, "private func WardrobeTabsTimedHover%s(" % side)
open(path, "w").write(text)

open(os.path.join(dest, "WardrobeTabsTiming.reds"), "w").write('''// TEST BUILD ONLY (tools/harness/instrument.py): hover handler timing. Never ship.
module EquipmentEx

// The compile check leaves OverlayMapNative's scripts out; the fallback only keeps it compiling
// (EngineTime cannot time work inside one frame, so its numbers are meaningless).
@if(ModuleExists("OverlayMapNative"))
public func WardrobeTabsNowMs() -> Float {
    return OverlayMapNative_NowMs();
}

@if(!ModuleExists("OverlayMapNative"))
public func WardrobeTabsNowMs() -> Float {
    return EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance())) * 1000.0;
}

@addField(WardrobeScreenController)
public let m_wtTimeCount: Int32;

@addField(WardrobeScreenController)
public let m_wtTimeTotal: Float;

@addField(WardrobeScreenController)
public let m_wtTimeMax: Float;

@addMethod(inkPreviewGameController)
private func WardrobeTabsHoverTimed(start: Float) -> Void {
    let screen: ref<WardrobeScreenController> = this as WardrobeScreenController;
    if !IsDefined(screen) {
        return;
    }
    let spent: Float = WardrobeTabsNowMs() - start;
    screen.m_wtTimeCount += 1;
    screen.m_wtTimeTotal += spent;
    screen.m_wtTimeMax = MaxF(screen.m_wtTimeMax, spent);
    if screen.m_wtTimeCount >= 20 {
        ModLog(n"WardrobeTabs", "timing: hover n=" + ToString(screen.m_wtTimeCount)
            + " avg=" + FloatToStringPrec(screen.m_wtTimeTotal / Cast<Float>(screen.m_wtTimeCount), 3)
            + " max=" + FloatToStringPrec(screen.m_wtTimeMax, 3) + " ms");
        screen.m_wtTimeCount = 0;
        screen.m_wtTimeTotal = 0.0;
        screen.m_wtTimeMax = 0.0;
    }
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeTabsHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    let start: Float = WardrobeTabsNowMs();
    let result: Bool = this.WardrobeTabsTimedHoverOver(evt);
    this.WardrobeTabsHoverTimed(start);
    return result;
}

@addMethod(inkPreviewGameController)
protected cb func OnWardrobeTabsHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    let start: Float = WardrobeTabsNowMs();
    let result: Bool = this.WardrobeTabsTimedHoverOut(evt);
    this.WardrobeTabsHoverTimed(start);
    return result;
}
''')
print(dest)
