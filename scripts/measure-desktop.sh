#!/usr/bin/env bash
# Layer 1 — "DE/WM justified with data" (assignment A.3).
# Measures idle memory and number of processes of the current graphical session.
#
# Procedure (repeat for each environment, right after logging in, nothing else open
# except ONE terminal running this script):
#   1. startx                       -> i3     -> ./scripts/measure-desktop.sh i3
#   2. NEON_SESSION=xfce startx  -> XFCE   -> ./scripts/measure-desktop.sh xfce
# Results are appended to docs/evidence/desktop/measurements.csv
set -euo pipefail

LABEL="${1:?usage: $0 <label e.g. i3|xfce> [samples] [interval_s]}"
SAMPLES="${2:-5}"
INTERVAL="${3:-10}"
SETTLE=60

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_DIR/docs/evidence/desktop"
CSV="$OUT_DIR/measurements.csv"
mkdir -p "$OUT_DIR"
[[ -f $CSV ]] || echo "timestamp,host,label,sample,mem_used_mib,mem_available_mib,procs_total,procs_user,user_rss_mib,user_pss_mib" > "$CSV"

kb() { awk -v k="$1:" '$1==k {print $2}' /proc/meminfo; }

echo "Waiting ${SETTLE}s for the session to settle (do not touch anything)..."
sleep "$SETTLE"

for ((i = 1; i <= SAMPLES; i++)); do
    total=$(kb MemTotal); avail=$(kb MemAvailable)
    used_mib=$(( (total - avail) / 1024 ))
    avail_mib=$(( avail / 1024 ))
    procs_total=$(find /proc -maxdepth 1 -regex '/proc/[0-9]+' | wc -l)
    procs_user=$(ps -u "$USER" --no-headers | wc -l)
    rss_mib=$(ps -u "$USER" -o rss= | awk '{s+=$1} END {printf "%d", s/1024}')
    # PSS (proportional set size) splits shared pages among the processes sharing them,
    # so it does not double count shared libraries the way RSS does.
    pss_mib=$(for p in $(pgrep -u "$USER"); do
                  awk '/^Pss:/ {print $2}' "/proc/$p/smaps_rollup" 2>/dev/null
              done | awk '{s+=$1} END {printf "%d", s/1024}')
    echo "$(date --iso-8601=seconds),$(cat /etc/hostname),$LABEL,$i,$used_mib,$avail_mib,$procs_total,$procs_user,$rss_mib,$pss_mib" | tee -a "$CSV"
    ((i < SAMPLES)) && sleep "$INTERVAL"
done

# Snapshot of the session's process tree, for the justification document
ps -u "$USER" -o pid,ppid,rss,comm --sort=-rss > "$OUT_DIR/processes-$LABEL-$(cat /etc/hostname).txt"
free -m > "$OUT_DIR/free-$LABEL-$(cat /etc/hostname).txt"
echo "Saved to ${CSV#"$REPO_DIR"/} and docs/evidence/desktop/{processes,free}-$LABEL-*.txt"
