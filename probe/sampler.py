#!/usr/bin/env python3
"""Samples the game's per-thread CPU, disk reads, page faults and GPU memory around each
inventory open. The CET probe touches marker.txt when the hub starts opening; this script
then writes the surrounding samples to probe/sampler.log."""
import datetime
import os
import subprocess
import sys
import time

MARKER = os.path.expanduser(
    "~/.local/share/Steam/steamapps/common/Cyberpunk 2077/bin/x64/plugins/"
    "cyber_engine_tweaks/mods/InventoryOpenProbe/marker.txt")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sampler.log")
INTERVAL = 0.1
BEFORE, AFTER = 0.5, 8.0


def find_game():
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            with open(f"/proc/{pid}/comm") as f:
                if f.read().startswith("Cyberpunk2077"):
                    return int(pid)
        except OSError:
            pass
    return None


def read_threads(pid):
    threads = {}
    for tid in os.listdir(f"/proc/{pid}/task"):
        try:
            with open(f"/proc/{pid}/task/{tid}/stat") as f:
                raw = f.read()
            name = raw[raw.index("(") + 1:raw.rindex(")")]
            fields = raw[raw.rindex(")") + 2:].split()
            threads[tid] = (name, fields[0], int(fields[11]), int(fields[12]), int(fields[9]))
        except (OSError, ValueError):
            pass
    return threads


def read_io(pid):
    try:
        with open(f"/proc/{pid}/io") as f:
            for line in f:
                if line.startswith("read_bytes:"):
                    return int(line.split()[1])
    except OSError:
        pass
    return 0


def marker_mtime():
    try:
        return os.stat(MARKER).st_mtime
    except OSError:
        return 0.0


def main(run_for=3600):
    deadline = time.time() + run_for
    pid = None
    while pid is None and time.time() < deadline:
        pid = find_game()
        if pid is None:
            time.sleep(2)
    if pid is None:
        return

    gpu = subprocess.Popen(
        ["nvidia-smi", "--query-gpu=memory.used,utilization.gpu", "--format=csv,noheader,nounits", "-lms", "200"],
        stdout=subprocess.PIPE, text=True)
    try:
        os.set_blocking(gpu.stdout.fileno(), False)
        gpu_now = "?"

        tick = os.sysconf("SC_CLK_TCK")
        samples = []
        prev, prev_io = read_threads(pid), read_io(pid)
        last_marker = marker_mtime()
        pending = []

        with open(OUT, "a") as out:
            out.write(f"# sampler started {datetime.datetime.now():%Y-%m-%d %H:%M:%S}, game pid {pid}\n")
            out.flush()
            while time.time() < deadline and os.path.exists(f"/proc/{pid}"):
                time.sleep(INTERVAL)
                now = time.time()
                try:
                    chunk = gpu.stdout.read()
                    if chunk:
                        gpu_now = chunk.strip().splitlines()[-1]
                except (OSError, TypeError):
                    pass
                try:
                    cur, cur_io = read_threads(pid), read_io(pid)
                except OSError:
                    break
                busy = []
                for tid, (name, state, ut, st, majflt) in cur.items():
                    old = prev.get(tid)
                    if not old:
                        continue
                    du, ds, df = ut - old[2], st - old[3], majflt - old[4]
                    if du or ds or df:
                        busy.append((du + ds, name, du * 1000 // tick, ds * 1000 // tick, df, state))
                busy.sort(reverse=True)
                samples.append((now, busy[:6], (cur_io - prev_io) // 1024, gpu_now, len(cur)))
                samples = [s for s in samples if s[0] > now - BEFORE - AFTER - 2]
                prev, prev_io = cur, cur_io

                m = marker_mtime()
                if m != last_marker:
                    last_marker = m
                    pending.append(m)
                while pending and now >= pending[0] + AFTER:
                    t0 = pending.pop(0)
                    out.write(f"=== hub open at {datetime.datetime.fromtimestamp(t0):%H:%M:%S.%f} ===\n")
                    out.write("  t(ms)  diskKB  gpu(MiB,util%)  threads  busiest threads: name user/sys ms [majflt] state\n")
                    for ts, top, kb, g, n in samples:
                        if t0 - BEFORE <= ts <= t0 + AFTER:
                            tops = "  ".join(f"{nm} {u}/{s}" + (f" [{f}]" if f else "") + f" {stt}"
                                             for _, nm, u, s, f, stt in top)
                            out.write(f"{(ts - t0) * 1000:7.0f} {kb:7d}  {g:>12}  {n:4d}  {tops}\n")
                    out.write("\n")
                    out.flush()
    finally:
        gpu.terminate()
        try:
            gpu.wait(timeout=5)
        except subprocess.TimeoutExpired:
            gpu.kill()
            gpu.wait()
        gpu.stdout.close()


if __name__ == "__main__":
    main(float(sys.argv[1]) if len(sys.argv) > 1 else 3600)
