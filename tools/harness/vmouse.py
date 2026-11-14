#!/usr/bin/env python3
"""Virtual mouse + keyboard over /dev/uinput, driven by commands written to a FIFO.

Run:   python3 -I vmouse.py
Send:  echo "move 100 -20; click" > $HARNESS_RUN/mcmd

Commands (';' or newline separated):
  move <dx> <dy>        relative motion (split into steps of at most 40)
  click [left|right]    press and release
  wheel <n>             wheel notches (+ up, - down)
  key <name> [ms]       tap a key (a-z, 0-9, enter, esc, backspace, space, tab, i)
  type <text>           types lowercase letters, digits and spaces
  wait <ms>
"""
import fcntl, os, struct, time

HERE = os.environ.get("HARNESS_RUN") or os.path.dirname(os.path.abspath(__file__))
os.makedirs(HERE, exist_ok=True)
FIFO = os.path.join(HERE, "mcmd")
LOG = os.path.join(HERE, "vmouse.log")

EV_SYN, EV_KEY, EV_REL = 0, 1, 2
REL_X, REL_Y, REL_WHEEL = 0, 1, 8
BTN_LEFT, BTN_RIGHT = 0x110, 0x111
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_RELBIT = 0x40045564, 0x40045565, 0x40045566
UI_DEV_CREATE, UI_DEV_DESTROY = 0x5501, 0x5502

KEYS = {"esc": 1, "backspace": 14, "tab": 15, "enter": 28, "space": 57}
for i, c in enumerate("1234567890"):
    KEYS[c] = 2 + i
for row, start in (("qwertyuiop", 16), ("asdfghjkl", 30), ("zxcvbnm", 44)):
    for i, c in enumerate(row):
        KEYS[c] = start + i


def log(msg):
    with open(LOG, "a") as f:
        f.write(time.strftime("%H:%M:%S ") + msg + "\n")


def create():
    fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
    for ev in (EV_KEY, EV_REL, EV_SYN):
        fcntl.ioctl(fd, UI_SET_EVBIT, ev)
    for code in (REL_X, REL_Y, REL_WHEEL):
        fcntl.ioctl(fd, UI_SET_RELBIT, code)
    for code in [BTN_LEFT, BTN_RIGHT] + list(KEYS.values()):
        fcntl.ioctl(fd, UI_SET_KEYBIT, code)
    name = b"Virtual Test Mouse".ljust(80, b"\0")
    dev = name + struct.pack("<HHHHI", 0x03, 0x1234, 0x5678, 1, 0) + b"\0" * (4 * 64 * 4)
    os.write(fd, dev)
    fcntl.ioctl(fd, UI_DEV_CREATE)
    return fd


def emit(fd, etype, code, value):
    t = time.time()
    os.write(fd, struct.pack("llHHi", int(t), int((t % 1) * 1e6), etype, code, value))


def sync(fd):
    emit(fd, EV_SYN, 0, 0)


def tap(fd, code, ms=60):
    emit(fd, EV_KEY, code, 1); sync(fd)
    time.sleep(ms / 1000)
    emit(fd, EV_KEY, code, 0); sync(fd)


def run(fd, line):
    for cmd in line.replace("\n", ";").split(";"):
        parts = cmd.split(" ", 1)
        op = parts[0].strip().lower()
        if not op:
            continue
        arg = parts[1] if len(parts) > 1 else ""
        log("> " + cmd.strip())
        if op == "move":
            dx, dy = (int(v) for v in arg.split())
            while dx or dy:
                sx = max(-40, min(40, dx)); sy = max(-40, min(40, dy))
                emit(fd, EV_REL, REL_X, sx); emit(fd, EV_REL, REL_Y, sy); sync(fd)
                dx -= sx; dy -= sy
                time.sleep(0.008)
        elif op == "click":
            tap(fd, BTN_RIGHT if arg.strip() == "right" else BTN_LEFT, 70)
        elif op == "wheel":
            n = int(arg)
            for _ in range(abs(n)):
                emit(fd, EV_REL, REL_WHEEL, 1 if n > 0 else -1); sync(fd)
                time.sleep(0.05)
        elif op == "key":
            a = arg.split()
            tap(fd, KEYS[a[0].lower()], int(a[1]) if len(a) > 1 else 60)
        elif op == "type":
            for c in arg.lower():
                tap(fd, KEYS["space" if c == " " else c], 40)
                time.sleep(0.06)
        elif op == "wait":
            time.sleep(int(arg) / 1000)
        else:
            log("unknown command: " + op)


def main():
    if not os.path.exists(FIFO):
        os.mkfifo(FIFO)
    fd = create()
    log("mouse created")
    try:
        while True:
            with open(FIFO) as f:
                for line in f:
                    try:
                        run(fd, line)
                    except Exception as e:
                        log("error: %r" % e)
    finally:
        fcntl.ioctl(fd, UI_DEV_DESTROY)


if __name__ == "__main__":
    main()
