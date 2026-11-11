#!/usr/bin/env python3
"""
Topic 7 — record the boot time of the CURRENT boot.
Run it once after each boot (3 boots before the optimisation with label
"before", 3 boots after with label "after"):
    ./scripts/tema07-boot-measure.py before
It appends one row per boot (deduplicated by /proc/sys/kernel/random/boot_id)
to docs/evidence/tema-07/boot-times.csv and saves blame / critical-chain /
plot for the first boot of each label. Then prints a before/after table.
"""
import csv, os, re, statistics, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "docs", "evidence", "tema-07")
CSV = os.path.join(OUT, "boot-times.csv")
PHASES = ["firmware", "loader", "kernel", "initrd", "userspace", "total"]


def seconds(txt):
    """'1min 2.345s' / '850ms' / '3.2s' -> float seconds"""
    total = 0.0
    for num, unit in re.findall(r"([\d.]+)(min|ms|s|us)", txt):
        total += float(num) * {"min": 60, "s": 1, "ms": 1e-3, "us": 1e-6}[unit]
    return total


def parse(out):
    line = next(l for l in out.splitlines() if l.startswith("Startup finished"))
    vals = {ph: seconds(v) for v, ph in re.findall(r"([\dminus.\s]+?)\s*\((\w+)\)", line)}
    vals["total"] = seconds(line.split("=")[-1])
    return vals


def run(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def main():
    label = sys.argv[1] if len(sys.argv) > 1 else "before"
    os.makedirs(OUT, exist_ok=True)
    boot_id = open("/proc/sys/kernel/random/boot_id").read().strip()
    out = run("systemd-analyze", "time")
    if "Startup finished" not in out:
        sys.exit("boot not finished yet (systemd-analyze time): wait a few seconds and retry")
    vals = parse(out)
    rows = list(csv.DictReader(open(CSV))) if os.path.exists(CSV) else []
    if any(r["boot_id"] == boot_id for r in rows):
        print("this boot is already recorded; reboot and run again")
    else:
        new = not rows
        with open(CSV, "a", newline="") as f:
            w = csv.writer(f)
            if new:
                w.writerow(["label", "boot_id"] + PHASES)
            w.writerow([label, boot_id] + ["%.3f" % vals.get(p, 0.0) for p in PHASES])
        rows.append({"label": label, "boot_id": boot_id, **{p: str(vals.get(p, 0.0)) for p in PHASES}})
        print(f"recorded boot {boot_id[:8]} as '{label}': {out.strip().splitlines()[0]}")
        if sum(r["label"] == label for r in rows) == 1:
            for name, cmd in [("blame", ["systemd-analyze", "blame", "--no-pager"]),
                              ("critical-chain", ["systemd-analyze", "critical-chain", "--no-pager"]),
                              ("time", ["systemd-analyze", "time"])]:
                open(os.path.join(OUT, f"{name}-{label}.txt"), "w").write(run(*cmd))
            open(os.path.join(OUT, f"plot-{label}.svg"), "w").write(run("systemd-analyze", "plot"))
    # summary table
    labels = sorted({r["label"] for r in rows}, key=lambda l: (l != "before", l))
    lines = ["| phase | " + " | ".join(f"{l} (mean of {sum(r['label']==l for r in rows)} boots)" for l in labels) + " |",
             "|---" * (len(labels) + 1) + "|"]
    for p in PHASES:
        cells = []
        for l in labels:
            v = [float(r[p]) for r in rows if r["label"] == l]
            cells.append(f"{statistics.mean(v):.2f} s")
        lines.append(f"| {p} | " + " | ".join(cells) + " |")
    table = "\n".join(lines)
    open(os.path.join(OUT, "summary.md"), "w").write(table + "\n")
    print(table)


if __name__ == "__main__":
    main()
