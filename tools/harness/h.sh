#!/usr/bin/env bash
# In-game test harness: a virtual Xbox pad and a virtual mouse/keyboard over /dev/uinput
# (vpad.py, vmouse.py, fed through FIFOs), screenshots with spectacle and the game's logs.
# Recovered from the 1.0.4 quick-close session, where it reproduced and verified that fix.
#
#   tools/harness/h.sh start              start the virtual pad and mouse (idempotent)
#   tools/harness/h.sh stop               remove them
#   tools/harness/h.sh launch             launch the game, wait for the script compile, print errors
#   tools/harness/h.sh pad "<cmds>"       pad commands (see vpad.py), game focused first
#   tools/harness/h.sh mouse "<cmds>"     mouse/keyboard commands (see vmouse.py)
#   tools/harness/h.sh goto X Y [click]   move the pointer to screen X,Y (closed loop), click
#   tools/harness/h.sh sweep X Y DX DY N  hover N points from X,Y in steps of DX,DY
#   tools/harness/h.sh shot NAME          screenshot (full + game area at 60%) into $HARNESS_RUN/shots
#   tools/harness/h.sh mark               remember the gamelog position
#   tools/harness/h.sh log [PATTERN]      WardrobeTabs gamelog lines since the mark
#   tools/harness/h.sh running            exit 0 while the game runs
#
# HARNESS_RUN (default $XDG_RUNTIME_DIR/wardrobe-harness) holds the FIFOs, logs and shots.
# The pointer moves through the uinput mouse: xdotool's moves do not reach the game.
# Needs write access to /dev/uinput, xdotool, spectacle and ImageMagick (magick).
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
export HARNESS_RUN="${HARNESS_RUN:-${XDG_RUNTIME_DIR:-/tmp}/wardrobe-harness}"
GAME="${GAME:-$HOME/.local/share/Steam/steamapps/common/Cyberpunk 2077}"
GAMELOG="$GAME/bin/x64/plugins/cyber_engine_tweaks/gamelog.log"
mkdir -p "$HARNESS_RUN/shots"

focus() {
    local w
    w=$(xdotool search --name "^Cyberpunk 2077 \(C\)" 2>/dev/null | head -1)
    [ -n "$w" ] && xdotool windowactivate "$w" 2>/dev/null
    true
}

goto() {
    local tx=$1 ty=$2 i dx dy X Y SCREEN WINDOW
    for i in $(seq 1 20); do
        eval "$(xdotool getmouselocation --shell)"
        dx=$((tx - X)); dy=$((ty - Y))
        [ ${dx#-} -le 2 ] && [ ${dy#-} -le 2 ] && break
        # Halve big moves: pointer acceleration overshoots.
        [ ${dx#-} -gt 6 ] && dx=$((dx / 2))
        [ ${dy#-} -gt 6 ] && dy=$((dy / 2))
        echo "move $dx $dy" > "$HARNESS_RUN/mcmd"; sleep 0.12
    done
    if [ "${3:-}" = click ]; then sleep 0.25; echo "click" > "$HARNESS_RUN/mcmd"; sleep 0.3; fi
}

case "${1:-}" in
start)
    pgrep -f "tools/harness/vpad.py" >/dev/null || (setsid nohup python3 -I "$HERE/vpad.py" >/dev/null 2>&1 &)
    pgrep -f "tools/harness/vmouse.py" >/dev/null || (setsid nohup python3 -I "$HERE/vmouse.py" >/dev/null 2>&1 &)
    sleep 1.5
    grep -c "X-Box 360 pad\|Virtual Test Mouse" /proc/bus/input/devices
    ;;
stop)
    pkill -f "tools/harness/vpad.py"; pkill -f "tools/harness/vmouse.py"; true
    ;;
launch)
    touch "$HARNESS_RUN/launchmark"
    (setsid nohup steam -applaunch 1091500 >/dev/null 2>&1 &)
    L="$GAME/r6/logs/redscript_rCURRENT.log"
    start=$(date +%s)
    until [ "$L" -nt "$HARNESS_RUN/launchmark" ] && grep -q "Compilation complete\|REDScript compilation has failed" "$L"; do
        sleep 3
        [ $(( $(date +%s) - start )) -gt 300 ] && { echo "no compile result after 300 s"; exit 1; }
    done
    if grep -q "ERROR" "$L"; then grep -A3 "ERROR" "$L" | head -40; echo "COMPILE FAILED"; exit 1; fi
    echo "compiled"
    ;;
pad)
    focus; echo "$2" > "$HARNESS_RUN/cmd"
    ;;
mouse)
    focus; echo "$2" > "$HARNESS_RUN/mcmd"
    ;;
goto)
    focus; goto "$2" "$3" "${4:-}"
    eval "$(xdotool getmouselocation --shell)"; echo "at $X,$Y"
    ;;
sweep)
    focus
    x=$2; y=$3
    for n in $(seq 1 "$6"); do goto "$x" "$y"; sleep 0.15; x=$((x + $4)); y=$((y + $5)); done
    ;;
shot)
    spectacle -b -n -f -o "$HARNESS_RUN/shots/$2.png" 2>/dev/null
    magick "$HARNESS_RUN/shots/$2.png" -crop 2560x1440+440+0 -resize 60% "$HARNESS_RUN/shots/$2g.png"
    echo "$HARNESS_RUN/shots/$2g.png"
    ;;
mark)
    wc -l < "$GAMELOG" > "$HARNESS_RUN/logmark"
    ;;
log)
    from=$(cat "$HARNESS_RUN/logmark" 2>/dev/null || echo 0)
    tail -n +"$((from + 1))" "$GAMELOG" | grep -a "WardrobeTabs" | grep -a -E "${2:-.}"
    ;;
running)
    pgrep -f "Cyberpunk2077\.exe" >/dev/null
    ;;
*)
    sed -n '2,22p' "$0"; exit 1
    ;;
esac
