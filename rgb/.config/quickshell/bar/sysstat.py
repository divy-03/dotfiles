#!/usr/bin/env python3
"""Emit one JSON line every ~2s: total CPU %, RAM, and the top processes.

Processes are grouped by name (so a browser's dozens of helpers count as one),
CPU is a real delta between samples (not ps's lifetime average), and memory is
the sum of RSS. Read straight from /proc, so there is nothing to fork per tick.
"""
import json, os, sys, time

CLK = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
NCPU = os.cpu_count() or 1
INTERVAL = float(sys.argv[1]) if len(sys.argv) > 1 else 2.0
TOP = 5


def cpu_times():
    f = open("/proc/stat").readline().split()[1:]
    v = list(map(int, f))
    return sum(v), v[3] + (v[4] if len(v) > 4 else 0)  # total, idle+iowait


def procs():
    out = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat") as fh:
                s = fh.read()
            # comm may contain spaces/parens: split around the last ')'
            r = s.rindex(")")
            name = s[s.index("(") + 1:r]
            f = s[r + 2:].split()
            ticks = int(f[11]) + int(f[12])
            rss = int(f[21]) * PAGE
            try:  # full name is nicer than the 15-char comm for long names
                with open(f"/proc/{pid}/comm") as c:
                    name = c.read().strip() or name
            except OSError:
                pass
            out[pid] = (name, ticks, rss)
        except (OSError, ValueError, IndexError):
            continue
    return out


def meminfo():
    m = {}
    with open("/proc/meminfo") as fh:
        for line in fh:
            k, v = line.split(":", 1)
            m[k] = int(v.split()[0]) * 1024
    total = m["MemTotal"]
    return total, total - m["MemAvailable"]


prev_t, prev_i = cpu_times()
prev_p = procs()
prev_time = time.monotonic()
while True:
    time.sleep(INTERVAL)
    now = time.monotonic()
    t, i = cpu_times()
    cur = procs()
    dt = now - prev_time
    cpu = 100.0 * (1 - (i - prev_i) / max(t - prev_t, 1))

    cpu_by, mem_by = {}, {}
    for pid, (name, ticks, rss) in cur.items():
        mem_by[name] = mem_by.get(name, 0) + rss
        if pid in prev_p and prev_p[pid][0] == name:
            d = (ticks - prev_p[pid][1]) / CLK / dt * 100.0  # % of one core
            cpu_by[name] = cpu_by.get(name, 0.0) + d

    total, used = meminfo()
    top_cpu = sorted(cpu_by.items(), key=lambda x: -x[1])[:TOP]
    top_mem = sorted(mem_by.items(), key=lambda x: -x[1])[:TOP]
    print(json.dumps({
        "cpu": round(cpu, 1),
        "cores": NCPU,
        "memUsed": used,
        "memTotal": total,
        "topCpu": [{"name": n, "v": round(v, 1)} for n, v in top_cpu],
        "topMem": [{"name": n, "v": b} for n, b in top_mem],
    }), flush=True)
    prev_t, prev_i, prev_p, prev_time = t, i, cur, now
