#!/usr/bin/env python3
"""Summarise fio JSON files named <fs>-<job>-<run>.json into a Markdown table."""
import glob, json, os, statistics, sys

out = sys.argv[1]
data = {}
for path in glob.glob(os.path.join(out, "*-*-*.json")):
    fs, job, _ = os.path.basename(path)[:-5].split("-")
    with open(path) as f:
        j = json.load(f)["jobs"][0]
    side = j["read"] if "read" in job else j["write"]
    data.setdefault((job, fs), []).append((side["bw"] / 1024, side["iops"], side["clat_ns"]["mean"] / 1000))

jobs = ["seqread", "seqwrite", "randread", "randwrite"]
print("| Workload | FS | MiB/s (mean ± sd of runs) | IOPS | mean latency (µs) | runs |")
print("|---|---|---|---|---|---|")
for job in jobs:
    for fs in ("btrfs", "ext4"):
        r = data.get((job, fs))
        if not r:
            continue
        mbs = statistics.mean(x[0] for x in r)
        iops = statistics.mean(x[1] for x in r)
        lat = statistics.mean(x[2] for x in r)
        sd = statistics.stdev(x[0] for x in r) if len(r) > 1 else 0
        print(f"| {job} | {fs} | {mbs:.1f} ± {sd:.1f} | {iops:.0f} | {lat:.0f} | {len(r)} |")
