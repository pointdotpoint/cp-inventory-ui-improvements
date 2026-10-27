#!/usr/bin/env bash
# Compiles the game's installed scripts plus this project's mods in a throwaway staging
# copy, using the game's own compiler under Wine. Nothing in the game folder is written.
# Usage: tools/compile-check.sh [--minimal]   (exit code 0 = compiles)
#   --minimal: only the mod's hard requirements (Equipment-EX, Codeware, ArchiveXL, TweakXL),
#   none of the other installed script mods (Mod Settings, Virtual Atelier, ...): what a
#   player with a bare setup compiles.
set -euo pipefail

GAME="${GAME:-$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

MINIMAL=0
[ "${1:-}" = "--minimal" ] && MINIMAL=1

mkdir -p "$STAGE/r6/scripts/_plugins" "$STAGE/r6/cache" "$STAGE/engine/tools"
if [ "$MINIMAL" = 1 ]; then
    cp -r "$GAME/r6/scripts/EquipmentEx" "$STAGE/r6/scripts/"
    PLUGINS="ArchiveXL/Scripts Codeware/Scripts TweakXL/Scripts"
else
    cp -r "$GAME/r6/scripts/." "$STAGE/r6/scripts/"
    rm -rf "$STAGE/r6/scripts/WardrobeTabs"
    PLUGINS="PhotoModeEx/Scripts ArchiveXL/Scripts Codeware/Scripts mod_settings TweakXL/Scripts"
fi
# RED4ext plugins hand their scripts to the compiler separately; fold them in here.
for dir in $PLUGINS; do
    name="${dir%%/*}"
    [ -d "$GAME/red4ext/plugins/$dir" ] || continue
    mkdir -p "$STAGE/r6/scripts/_plugins/$name"
    cp "$GAME/red4ext/plugins/$dir"/*.reds "$STAGE/r6/scripts/_plugins/$name/"
done
cp -r "$PROJECT/mod/r6/scripts/." "$STAGE/r6/scripts/"
cp "$GAME/r6/cache/final.redscripts" "$STAGE/r6/cache/"
cp "$GAME/engine/tools/"* "$STAGE/engine/tools/"

cd "$STAGE"
WINEDEBUG=-all wine engine/tools/scc.exe -compile "$(winepath -w "$STAGE/r6/scripts" 2>/dev/null)" >/dev/null 2>&1 || true

LOG="$STAGE/r6/logs/redscript_rCURRENT.log"
if grep -q "Compilation complete" "$LOG" && ! grep -q "ERROR" "$LOG"; then
    echo "OK: compiles"
else
    grep -E "ERROR" -A5 "$LOG" | sed 's|Z:\\tmp\\[^ ]*scripts\\||' | head -80
    echo "FAILED"
    exit 1
fi
