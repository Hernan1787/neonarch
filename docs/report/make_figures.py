#!/usr/bin/env python3
"""Build the report figures from the raw evidence in docs/evidence/ (reproducible)."""
import csv, glob, json, os, statistics as st
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.join(HERE, "..", "evidence")
OUT = os.path.join(HERE, "figures")
os.makedirs(OUT, exist_ok=True)

BLUE, ORANGE, AQUA = "#2a78d6", "#eb6834", "#1baf7a"
REF = "#b9b8b2"            # reference / expected values (neutral)
INK, INK2, GRID = "#0b0b0b", "#52514e", "#e6e5e0"
plt.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 8.5, "axes.edgecolor": GRID,
    "axes.labelcolor": INK2, "xtick.color": INK2, "ytick.color": INK2, "text.color": INK,
    "axes.spines.top": False, "axes.spines.right": False, "axes.grid": True,
    "grid.color": GRID, "grid.linewidth": 0.6, "axes.axisbelow": True,
    "legend.frameon": False, "figure.dpi": 200, "savefig.bbox": "tight",
})

def bars(ax, x, h, color, w, label=None, fmt=None, err=None):
    b = ax.bar(x, h, w, color=color, label=label, edgecolor="white", linewidth=1.2,
               yerr=err, ecolor=INK2, capsize=2, error_kw={"linewidth": 0.8})
    if fmt:
        for i, (r, v) in enumerate(zip(b, h)):
            top = r.get_height() + (err[i] if err else 0)
            ax.annotate(fmt(v), (r.get_x() + r.get_width() / 2, top),
                        xytext=(0, 2), textcoords="offset points", ha="center", va="bottom",
                        fontsize=7.5, color=INK2)
    return b

def save(fig, name):
    fig.savefig(os.path.join(OUT, name)); plt.close(fig); print("wrote", name)

# --- Topic 1: share per nice value ------------------------------------------------
rows = list(csv.DictReader(open(f"{EV}/tema-01/a-nice-shares.csv")))
W = {0: 1024, 5: 335, 10: 110}
nices = [0, 5, 10]
exp = [100 * W[n] / sum(W.values()) for n in nices]
meas = [st.mean(float(r["share_percent"]) for r in rows if int(r["nice"]) == n) for n in nices]
fig, ax = plt.subplots(figsize=(3.4, 2.3))
x = range(3)
bars(ax, [i - 0.19 for i in x], exp, REF, 0.36, "expected (weights)", lambda v: f"{v:.1f}")
bars(ax, [i + 0.19 for i in x], meas, BLUE, 0.36, "measured (3 runs)", lambda v: f"{v:.1f}")
ax.set_xticks(list(x), [f"nice {n}" for n in nices]); ax.set_ylabel("share of CPU 0 (%)")
ax.set_ylim(0, 80); ax.legend(loc="upper right", fontsize=7.5)
save(fig, "t1-nice-shares.pdf")

# --- Topic 3: btrfs vs ext4 --------------------------------------------------------
def fio(fs, job):
    vals = []
    for p in sorted(glob.glob(f"{EV}/tema-03/fio/{fs}-{job}-*.json")):
        j = json.load(open(p))["jobs"][0]
        side = j["read"] if "read" in job else j["write"]
        vals.append((side["bw"] / 1024, side["iops"]))
    return vals
fig, (a1, a2) = plt.subplots(1, 2, figsize=(6.4, 2.4), gridspec_kw={"wspace": 0.38})
for ax, jobs, idx, ylabel, fmt in ((a1, ["seqread", "seqwrite"], 0, "MiB/s (1 MiB blocks)", lambda v: f"{v:.0f}"),
                                   (a2, ["randread", "randwrite"], 1, "IOPS (4 KiB blocks)", lambda v: f"{v/1000:.1f}k")):
    for k, (fs, c) in enumerate((("btrfs", BLUE), ("ext4", ORANGE))):
        m = [st.mean(v[idx] for v in fio(fs, j)) for j in jobs]
        sd = [st.stdev(v[idx] for v in fio(fs, j)) for j in jobs]
        bars(ax, [i + (k - 0.5) * 0.38 for i in range(2)], m, c, 0.36, fs, fmt, sd)
    ax.set_xticks([0, 1], [j.replace("seq", "seq. ").replace("rand", "random ") for j in jobs])
    ax.set_ylabel(ylabel); ax.margins(y=0.15)
a1.legend(ncol=2, loc="lower center", bbox_to_anchor=(1.12, 1.02), fontsize=7.5)
save(fig, "t3-fio.pdf")

# --- Topic 4: CPUQuota -------------------------------------------------------------
fig, ax = plt.subplots(figsize=(3.4, 2.2))
for name, c, lab in (("without-quota", ORANGE, "no quota"), ("with-quota", BLUE, "CPUQuota=20%")):
    r = list(csv.DictReader(open(f"{EV}/tema-04/cpu-{name}.csv")))
    ax.plot([int(x["second"]) for x in r], [int(x["cpu_percent_of_one_core"]) for x in r],
            color=c, linewidth=2, label=lab, marker="o", markersize=2.5)
ax.axhline(20, color=INK2, linewidth=0.8, linestyle=(0, (3, 2)))
ax.set_xlabel("second of the CPU burn"); ax.set_ylabel("CPU of the cgroup (% of a core)")
ax.set_ylim(0, 115); ax.legend(loc="center right", fontsize=7.5)
save(fig, "t4-cpuquota.pdf")

# --- Topic 7: boot phases ----------------------------------------------------------
rows = list(csv.DictReader(open(f"{EV}/tema-07/boot-times.csv")))
variants = [("before", "default (zstd)"), ("after", "lz4, no fsck"), ("slim", "zstd, no fsck/kms")]
phases = [("kernel", BLUE), ("initrd", ORANGE), ("userspace", AQUA)]
fig, ax = plt.subplots(figsize=(6.4, 1.9))
for i, (lab, name) in enumerate(variants):
    left = 0
    sel = [r for r in rows if r["label"] == lab]
    for ph, c in phases:
        v = st.mean(float(r[ph]) for r in sel)
        ax.barh(i, v, left=left, color=c, height=0.55, edgecolor="white", linewidth=1.5,
                label=ph if i == 0 else None)
        left += v
    tot = [float(r["total"]) for r in sel]
    ax.annotate(f"{st.mean(tot):.2f} ± {st.stdev(tot):.2f} s", (left, i), xytext=(4, 0),
                textcoords="offset points", va="center", fontsize=7.5, color=INK2)
ax.set_yticks(range(3), [n for _, n in variants]); ax.invert_yaxis()
ax.set_xlabel("seconds from kernel start (mean of 3 boots)"); ax.set_xlim(0, 6)
ax.grid(axis="y", visible=False)
ax.legend(ncol=3, loc="lower center", bbox_to_anchor=(0.45, 1.0), fontsize=7.5)
save(fig, "t7-boot.pdf")

# --- Layer 1: desktop --------------------------------------------------------------
rows = list(csv.DictReader(open(f"{EV}/desktop/measurements.csv")))
fig, ax = plt.subplots(figsize=(3.4, 2.2))
metrics = [("mem_used_mib", "system used\nmemory"), ("user_pss_mib", "session PSS")]
for k, (lab, c) in enumerate((("i3", BLUE), ("xfce", ORANGE))):
    m = [st.mean(float(r[key]) for r in rows if r["label"] == lab) for key, _ in metrics]
    bars(ax, [i + (k - 0.5) * 0.38 for i in range(2)], m, c, 0.36, "i3" if lab == "i3" else "XFCE",
         lambda v: f"{v:.0f}")
ax.set_xticks([0, 1], [n for _, n in metrics]); ax.set_ylabel("MiB (mean of 5 samples)")
ax.margins(y=0.15); ax.legend(loc="upper right", fontsize=7.5)
save(fig, "desktop.pdf")
