#!/usr/bin/env bash
# =============================================================================
# Topic 4 — evidence for neon-health.service
#   1. unit status, cgroup tree, effective limits
#   2. CPUQuota: CPU used by the cgroup while the daemon burns CPU,
#      first WITH the 20 % quota, then WITHOUT it (runtime override)
#   3. MemoryMax: provoke an OOM kill inside the cgroup and show the restart
#   4. Restart policy: SIGKILL the main process and show the restart
# Output: docs/evidence/tema-04/
# Usage:  ./scripts/tema04-measure.sh        (asks for sudo)
# =============================================================================
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_DIR/docs/evidence/tema-04"
UNIT=neon-health.service
mkdir -p "$OUT"
sudo -v

hdr() { printf '\n\e[1;36m==> %s\e[0m\n' "$*"; }
save() { local f="$1"; shift; { echo "\$ $*"; "$@" 2>&1 || true; } > "$OUT/$f"; echo "  saved $f"; }

sudo systemctl is-active --quiet "$UNIT" || sudo systemctl start "$UNIT"
sleep 2

hdr "1. Unit, cgroup and limits"
save status.txt          systemctl status "$UNIT" --no-pager
save cgls.txt            systemd-cgls --no-pager -u "$UNIT"
save limits.txt          systemctl show "$UNIT" -p ControlGroup -p CPUQuotaPerSecUSec -p MemoryMax -p MemorySwapMax -p Restart -p RestartUSec -p User -p DynamicUser -p NRestarts
save timer.txt           systemctl list-timers neon-health-report.timer --no-pager
save ps-user.txt         ps -o user,pid,ppid,rss,cmd -C python3

cgdir() { echo "/sys/fs/cgroup$(systemctl show -p ControlGroup --value "$UNIT")"; }
usage() { awk '/^usage_usec/ {print $2}' "$(cgdir)/cpu.stat"; }

# measure <label> : burn 30 s and sample the cgroup CPU usage every second
measure() {
    local label="$1" csv="$OUT/cpu-$1.csv" u1 u2 pct
    echo "second,cpu_percent_of_one_core" > "$csv"
    sudo systemctl kill -s SIGUSR1 "$UNIT"
    sleep 1
    for s in $(seq 1 25); do
        u1=$(usage); sleep 1; u2=$(usage)
        pct=$(( (u2 - u1) / 10000 ))          # usec used in 1 s -> % of one core
        echo "$s,$pct" >> "$csv"
        printf '  [%s] t=%2ss  CPU=%3s%%\n' "$label" "$s" "$pct"
    done
    sleep 5   # let the 30 s burn finish
}

hdr "2a. CPU burn WITH CPUQuota=20%"
measure with-quota

hdr "2b. CPU burn WITHOUT quota (temporary runtime override)"
sudo systemctl set-property --runtime "$UNIT" CPUQuota=
measure without-quota
sudo systemctl set-property --runtime "$UNIT" CPUQuota=20%
save limits-restored.txt systemctl show "$UNIT" -p CPUQuotaPerSecUSec

avg() { awk -F, 'NR>1 {s+=$2; n++} END {printf "%.1f", s/n}' "$1"; }
A=$(avg "$OUT/cpu-with-quota.csv"); B=$(avg "$OUT/cpu-without-quota.csv")

restarts() { systemctl show -p NRestarts --value "$UNIT"; }
wait_restart() {   # wait until NRestarts grows past $1 and the unit is active again
    for _ in $(seq 1 40); do
        [[ $(restarts) -gt $1 ]] && systemctl is-active --quiet "$UNIT" && return 0
        sleep 1
    done
    return 1
}

hdr "3. MemoryMax=64M: provoke an OOM kill"
R0=$(restarts); SINCE=$(date '+%Y-%m-%d %H:%M:%S')
sudo systemctl kill -s SIGUSR2 "$UNIT"
wait_restart "$R0" && echo "  restarted (NRestarts $R0 -> $(restarts))" || echo "  NOT restarted"
save oom-journal.txt     journalctl -u "$UNIT" --since "$SINCE" --no-pager -o short-precise
R1=$(restarts)

hdr "4. Restart policy: SIGKILL the main process"
SINCE=$(date '+%Y-%m-%d %H:%M:%S')
sudo systemctl kill -s SIGKILL "$UNIT"
wait_restart "$R1" && echo "  restarted (NRestarts $R1 -> $(restarts))" || echo "  NOT restarted"
save kill-journal.txt    journalctl -u "$UNIT" --since "$SINCE" --no-pager -o short-precise
R2=$(restarts)

hdr "Summary"
{
    echo "| Test | Result |"
    echo "|---|---|"
    echo "| Mean CPU while burning, CPUQuota=20% | ${A} % of one core |"
    echo "| Mean CPU while burning, no quota | ${B} % of one core |"
    echo "| OOM kill at MemoryMax=64M | restarted, NRestarts ${R0} -> ${R1} |"
    echo "| SIGKILL of main process | restarted, NRestarts ${R1} -> ${R2} |"
} | tee "$OUT/summary.md"
echo "Evidence in docs/evidence/tema-04/. Commit it with: git add docs/evidence/tema-04 && git commit -m 'Topic 4: measurements'"
