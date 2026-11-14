#!/usr/bin/env python3
"""Virtual Xbox 360 pad over /dev/uinput, driven by commands written to a FIFO.

Run:   python3 -I vpad.py            (keeps the pad alive until killed)
Send:  echo "tap A; wait 300; tap B" > $HARNESS_RUN/cmd

Commands (separated by ';' or newlines):
  tap <BTN> [ms]        press and release (default 80 ms held)
  down <BTN> / up <BTN>
  stick <lx|ly|rx|ry> <-1..1>   (ly/ry: -1 = up)
  dpad <up|down|left|right> [ms]
  trigger <lt|rt> <0..1>
  wait <ms>
Buttons: A B X Y LB RB BACK START GUIDE LS RS
"""
import fcntl, os, struct, sys, time

HERE = os.environ.get("HARNESS_RUN") or os.path.dirname(os.path.abspath(__file__))
os.makedirs(HERE, exist_ok=True)
FIFO = os.path.join(HERE, "cmd")
LOG = os.path.join(HERE, "vpad.log")

EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
SYN_REPORT = 0
BTN = {"A": 0x130, "B": 0x131, "X": 0x133, "Y": 0x134, "LB": 0x136, "RB": 0x137,
       "BACK": 0x13a, "START": 0x13b, "GUIDE": 0x13c, "LS": 0x13d, "RS": 0x13e}
ABS_X, ABS_Y, ABS_Z, ABS_RX, ABS_RY, ABS_RZ, ABS_HAT0X, ABS_HAT0Y = 0, 1, 2, 3, 4, 5, 0x10, 0x11
STICK = {"lx": ABS_X, "ly": ABS_Y, "rx": ABS_RX, "ry": ABS_RY}
TRIG = {"lt": ABS_Z, "rt": ABS_RZ}

UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_ABSBIT = 0x40045564, 0x40045565, 0x40045567
UI_DEV_CREATE, UI_DEV_DESTROY = 0x5501, 0x5502


def log(msg):
    with open(LOG, "a") as f:
        f.write(time.strftime("%H:%M:%S ") + msg + "\n")


def create():
    fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
    fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
    fcntl.ioctl(fd, UI_SET_EVBIT, EV_ABS)
    fcntl.ioctl(fd, UI_SET_EVBIT, EV_SYN)
    for code in BTN.values():
        fcntl.ioctl(fd, UI_SET_KEYBIT, code)
    absmax, absmin, absfuzz, absflat = [0] * 64, [0] * 64, [0] * 64, [0] * 64
    for code in (ABS_X, ABS_Y, ABS_RX, ABS_RY):
        fcntl.ioctl(fd, UI_SET_ABSBIT, code)
        absmin[code], absmax[code], absfuzz[code], absflat[code] = -32768, 32767, 16, 128
    for code in (ABS_Z, ABS_RZ):
        fcntl.ioctl(fd, UI_SET_ABSBIT, code)
        absmin[code], absmax[code] = 0, 255
    for code in (ABS_HAT0X, ABS_HAT0Y):
        fcntl.ioctl(fd, UI_SET_ABSBIT, code)
        absmin[code], absmax[code] = -1, 1
    name = b"Microsoft X-Box 360 pad".ljust(80, b"\0")
    dev = name + struct.pack("<HHHHI", 0x03, 0x045E, 0x028E, 0x0114, 0)
    dev += struct.pack("<64i", *absmax) + struct.pack("<64i", *absmin)
    dev += struct.pack("<64i", *absfuzz) + struct.pack("<64i", *absflat)
    os.write(fd, dev)
    fcntl.ioctl(fd, UI_DEV_CREATE)
    return fd


def emit(fd, etype, code, value):
    t = time.time()
    os.write(fd, struct.pack("llHHi", int(t), int((t % 1) * 1e6), etype, code, value))


def sync(fd):
    emit(fd, EV_SYN, SYN_REPORT, 0)


def run(fd, line):
    for cmd in line.replace("\n", ";").split(";"):
        parts = cmd.split()
        if not parts:
            continue
        op, args = parts[0].lower(), parts[1:]
        log("> " + " ".join(parts))
        if op in ("tap", "down", "up"):
            code = BTN[args[0].upper()]
            if op in ("tap", "down"):
                emit(fd, EV_KEY, code, 1); sync(fd)
            if op == "tap":
                time.sleep((int(args[1]) if len(args) > 1 else 80) / 1000)
            if op in ("tap", "up"):
                emit(fd, EV_KEY, code, 0); sync(fd)
        elif op == "stick":
            v = max(-1.0, min(1.0, float(args[1])))
            emit(fd, EV_ABS, STICK[args[0].lower()], int(v * 32767)); sync(fd)
        elif op == "trigger":
            emit(fd, EV_ABS, TRIG[args[0].lower()], int(float(args[1]) * 255)); sync(fd)
        elif op == "dpad":
            axis, val = {"up": (ABS_HAT0Y, -1), "down": (ABS_HAT0Y, 1),
                         "left": (ABS_HAT0X, -1), "right": (ABS_HAT0X, 1)}[args[0].lower()]
            emit(fd, EV_ABS, axis, val); sync(fd)
            time.sleep((int(args[1]) if len(args) > 1 else 80) / 1000)
            emit(fd, EV_ABS, axis, 0); sync(fd)
        elif op == "wait":
            time.sleep(int(args[0]) / 1000)
        else:
            log("unknown command: " + op)


def main():
    if not os.path.exists(FIFO):
        os.mkfifo(FIFO)
    fd = create()
    log("pad created")
    try:
        while True:
            with open(FIFO) as f:
                for line in f:
                    try:
                        run(fd, line)
                    except Exception as e:  # keep the pad alive on a bad command
                        log("error: %r" % e)
    finally:
        fcntl.ioctl(fd, UI_DEV_DESTROY)
        os.close(fd)


if __name__ == "__main__":
    main()
