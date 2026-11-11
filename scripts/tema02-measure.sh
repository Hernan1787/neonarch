#!/usr/bin/env bash
# =============================================================================
# Topic 2 — memory pressure WITH and WITHOUT zram
# For each scenario stress-ng allocates (MemAvailable + 1.5 GiB) for 60 s, so the
# kernel must page out. We record vmstat every second (si/so = KiB swapped in/out),
# the deltas of /proc/vmstat (pswpin, pswpout, pgmajfault), the zram ratio and the
# work done by stress-ng (bogo ops/s). The OOM killer is looked for in the journal.
#   scenario "zram":   zram (prio 100) + swapfile (prio 10)
#   scenario "nozram": zram disabled (swapoff /dev/zram0), only the swapfile on disk
# Output: docs/evidence/tema-02/
# =============================================================================
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_DIR/docs/evidence/tema-02"; mkdir -p "$OUT"
DUR=${DUR:-60}
sudo -v
vmval() { awk -v k="$1" '$1==k {print $2}' /proc/vmstat; }

run_scenario() {
    local name=$1
    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null; sleep 3
    swapon --show > "$OUT/$name-swaps.txt"
    local avail_kib target_mib since
    avail_kib=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    target_mib=$(( avail_kib / 1024 + 1536 ))
    echo "== $name: allocating ${target_mib} MiB for ${DUR}s (MemAvailable $((avail_kib/1024)) MiB)"
    local in0 out0 maj0
    in0=$(vmval pswpin); out0=$(vmval pswpout); maj0=$(vmval pgmajfault)
    since=$(date '+%Y-%m-%d %H:%M:%S')
    vmstat -n 1 "$((DUR + 5))" > "$OUT/$name-vmstat.txt" &
    local vpid=$!
    stress-ng --vm 2 --vm-bytes "$((target_mib / 2))M" --vm-keep --timeout "${DUR}s" \
              --metrics-brief > "$OUT/$name-stressng.txt" 2>&1
    grep -h zram /proc/swaps > /dev/null 2>&1 && for z in /sys/block/zram*; do
        echo "$(basename "$z") mm_stat: $(cat "$z/mm_stat")"; done > "$OUT/$name-zram.txt"
    wait "$vpid"
    local din dout dmaj ops oom
    din=$(( $(vmval pswpin) - in0 )); dout=$(( $(vmval pswpout) - out0 )); dmaj=$(( $(vmval pgmajfault) - maj0 ))
    ops=$(awk '/stress-ng: (info|metrc).*vm / {for(i=1;i<=NF;i++) if($i ~ /^[0-9.]+$/) v=$i} END{print v}' "$OUT/$name-stressng.txt")
    oom=$(journalctl -k --since "$since" --no-pager | grep -ci "out of memory")
    echo "| $name | $din | $dout | $dmaj | ${ops:-?} | $oom |" >> "$OUT/summary.md"
    echo "   swap-in $din pages, swap-out $dout pages, major faults $dmaj, OOM kills $oom"
}

echo "| scenario | pswpin (pages) | pswpout (pages) | major faults | stress-ng vm bogo ops/s | OOM kills |" > "$OUT/summary.md"
echo "|---|---|---|---|---|---|" >> "$OUT/summary.md"
run_scenario zram
sudo swapoff /dev/zram0
run_scenario nozram
sudo systemctl restart systemd-zram-setup@zram0.service
swapon --show
cat "$OUT/summary.md"
