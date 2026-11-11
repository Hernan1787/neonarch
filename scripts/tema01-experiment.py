#!/usr/bin/env python3
"""
Topic 1 — scheduling experiment (run with sudo: the real-time part needs root).

  A. Fair class (EEVDF): three CPU-bound loops pinned to the SAME core (CPU 0)
     with nice 0, 5 and 10. We measure the CPU time each one gets from
     /proc/<pid>/stat (utime+stime) and compare it with the share predicted by
     the kernel weight table sched_prio_to_weight[] (nice 0=1024, 5=335, 10=110).
  B. Real-time vs fair: one SCHED_FIFO (priority 10) loop and one normal loop
     on CPU 0. FIFO always wins; the normal loop only runs thanks to RT
     throttling (/proc/sys/kernel/sched_rt_runtime_us = 950000 of 1000000 us).

Each experiment is repeated RUNS times. Output: docs/evidence/tema-01/
Usage:  sudo python3 scripts/tema01-experiment.py
"""
import os
import statistics
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "docs", "evidence", "tema-01")
RUNS = int(os.environ.get("RUNS", "3"))
SECONDS = int(os.environ.get("SECONDS_PER_RUN", "20"))
CPU = 0
CLK = os.sysconf("SC_CLK_TCK")
WEIGHT = {0: 1024, 5: 335, 10: 110}          # kernel/sched/core.c sched_prio_to_weight[]
LOOP = ["sh", "-c", "while :; do :; done"]


def ticks(pid):
    with open(f"/proc/{pid}/stat") as f:
        s = f.read()
    rest = s[s.rindex(")") + 2:].split()
    return int(rest[11]) + int(rest[12])


def spawn(nice=0, fifo_prio=None):
    def setup():
        os.sched_setaffinity(0, {CPU})                       # sched_setaffinity(2)
        if fifo_prio is not None:
            os.sched_setscheduler(0, os.SCHED_FIFO, os.sched_param(fifo_prio))
        else:
            os.setpriority(os.PRIO_PROCESS, 0, nice)          # setpriority(2)
    return subprocess.Popen(LOOP, preexec_fn=setup)


def measure(procs):
    t0 = {p.pid: ticks(p.pid) for p in procs}
    start = time.monotonic()
    time.sleep(SECONDS)
    el = time.monotonic() - start
    res = {p.pid: (ticks(p.pid) - t0[p.pid]) / CLK / el * 100 for p in procs}
    for p in procs:
        p.kill(); p.wait()
    return res


def main():
    if os.geteuid() != 0:
        sys.exit("run with sudo (SCHED_FIFO needs root)")
    os.makedirs(OUT, exist_ok=True)
    env = {
        "kernel": os.uname().release,
        "sched_rt_runtime_us": open("/proc/sys/kernel/sched_rt_runtime_us").read().strip(),
        "sched_rt_period_us": open("/proc/sys/kernel/sched_rt_period_us").read().strip(),
        "sched_autogroup_enabled": open("/proc/sys/kernel/sched_autogroup_enabled").read().strip(),
        "cpus": os.cpu_count(),
    }
    print("environment:", env)

    # ---------------- A. nice values in the fair class ----------------
    rows_a = []
    for run in range(1, RUNS + 1):
        procs = {n: spawn(nice=n) for n in (0, 5, 10)}
        r = measure(list(procs.values()))
        total = sum(r.values())
        for n, p in procs.items():
            rows_a.append((run, n, r[p.pid], 100 * r[p.pid] / total))
        print(f"A run {run}: " + "  ".join(f"nice {n}: {r[p.pid]:.1f}%" for n, p in procs.items()))
    with open(os.path.join(OUT, "a-nice-shares.csv"), "w") as f:
        f.write("run,nice,cpu_percent_of_core,share_percent\n")
        for row in rows_a:
            f.write("%d,%d,%.2f,%.2f\n" % row)

    # ---------------- B. SCHED_FIFO vs SCHED_OTHER ----------------
    rows_b = []
    for run in range(1, RUNS + 1):
        normal = spawn(nice=0)
        rt = spawn(fifo_prio=10)
        r = measure([normal, rt])
        rows_b.append((run, r[rt.pid], r[normal.pid]))
        print(f"B run {run}: FIFO {r[rt.pid]:.1f}%   OTHER {r[normal.pid]:.1f}%")
    with open(os.path.join(OUT, "b-fifo-vs-other.csv"), "w") as f:
        f.write("run,fifo_cpu_percent,other_cpu_percent\n")
        for row in rows_b:
            f.write("%d,%.2f,%.2f\n" % row)

    # ---------------- summary ----------------
    wsum = sum(WEIGHT.values())
    lines = ["# Topic 1 results", "", f"Environment: `{env}`", "",
             f"## A. Three CPU-bound loops on CPU {CPU}, {SECONDS} s × {RUNS} runs", "",
             "| nice | weight | expected share | measured share (mean ± sd) |", "|---|---|---|---|"]
    for n in (0, 5, 10):
        sh = [r[3] for r in rows_a if r[1] == n]
        sd = statistics.stdev(sh) if len(sh) > 1 else 0
        lines.append(f"| {n} | {WEIGHT[n]} | {100 * WEIGHT[n] / wsum:.1f} % | {statistics.mean(sh):.1f} ± {sd:.1f} % |")
    fifo = [r[1] for r in rows_b]; other = [r[2] for r in rows_b]
    rt_budget = 100 * int(env["sched_rt_runtime_us"]) / int(env["sched_rt_period_us"])
    lines += ["", f"## B. SCHED_FIFO (prio 10) vs SCHED_OTHER (nice 0) on CPU {CPU}", "",
              "| class | expected | measured (mean of runs) |", "|---|---|---|",
              f"| SCHED_FIFO | ≤ {rt_budget:.0f} % (RT throttling) | {statistics.mean(fifo):.1f} % |",
              f"| SCHED_OTHER | ≥ {100 - rt_budget:.0f} % | {statistics.mean(other):.1f} % |"]
    text = "\n".join(lines) + "\n"
    with open(os.path.join(OUT, "summary.md"), "w") as f:
        f.write(text)
    print("\n" + text)
    uid = int(os.environ.get("SUDO_UID", "0")); gid = int(os.environ.get("SUDO_GID", "0"))
    for name in os.listdir(OUT):                     # give the files back to the normal user
        os.chown(os.path.join(OUT, name), uid, gid)


if __name__ == "__main__":
    main()
