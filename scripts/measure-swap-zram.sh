#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$(cat /etc/hostname)"
EVID="$REPO_DIR/docs/evidence/tema2-$HOST"
DOC="$REPO_DIR/docs/tema2-swap-zram.md"
mkdir -p "$EVID"

RAM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
WORKERS=1
VM_BYTES_MB=1800
SWAP_SIZE=2
DURATION=180

c_hd=$'\e[1;38;2;0;240;255m'; c_ok=$'\e[32m'; c_0=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$c_hd" "$*" "$c_0"; }
ok()   { printf '  %s[ok]%s %s\n' "$c_ok" "$c_0" "$*"; }

step "0. Preflight"
[[ -f /etc/arch-release ]] || { echo "Not Arch"; exit 1; }
[[ $EUID -ne 0 ]] || { echo "Run as normal user, not root"; exit 1; }
sudo -v
ok "RAM=${RAM_MB} MB  workers=$WORKERS  vm-bytes=${VM_BYTES_MB}M  swapfile=${SWAP_SIZE}G  duration=${DURATION}s"

step "1. Install tools"
sudo pacman -S --needed --noconfirm zram-generator stress-ng procps-ng
ok "tools installed"

step "2. Create swapfile in @swap"
if [[ ! -f /swap/swapfile ]]; then
    sudo btrfs filesystem mkswapfile --size "${SWAP_SIZE}G" /swap/swapfile
fi
sudo swapon /swap/swapfile 2>/dev/null || true
grep -q '^/swap/swapfile' /etc/fstab || \
    echo '/swap/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab >/dev/null
ok "swapfile active"

step "3. Configure zram-generator"
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
sudo systemctl daemon-reload
sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
sudo systemctl enable systemd-zram-setup@zram0.service >/dev/null 2>&1 || true
ok "zram0 configured"

measure() {
    local label="$1"
    step "Measuring '$label'"
    vmstat -w 2 $((DURATION/2 + 10)) > "$EVID/evidencia-vmstat-$label-zram.txt" &
    local vmpid=$!
    sleep 2
    stress-ng --vm "$WORKERS" --vm-bytes "${VM_BYTES_MB}M" --vm-keep \
        --timeout "${DURATION}s" --metrics-brief \
        | tee "$EVID/evidencia-stress-ng-$label-zram.txt"
    wait "$vmpid" || true
    {
        echo "=== free -h ==="; free -h
        echo; echo "=== swapon ==="; swapon --show
        echo; echo "=== /proc/swaps ==="; cat /proc/swaps
        echo; echo "=== zramctl ==="; zramctl || true
    } > "$EVID/evidencia-free-$label-zram.txt"
    ok "evidence saved for '$label'"
}

step "4a. Baseline: disable zram"
sudo swapoff /dev/zram0 2>/dev/null || true
sleep 1
if swapon --show | grep -q zram; then echo "ERROR: zram still active"; exit 1; fi
swapon --show | tee "$EVID/evidencia-swapon-sin-zram.txt"
measure sin

step "4b. Re-enable zram"
sudo swapon --priority 100 /dev/zram0
sleep 1
if ! swapon --show | grep -q zram; then echo "ERROR: zram not active"; exit 1; fi
swapon --show | tee "$EVID/evidencia-swapon-con-zram.txt"
measure con

step "5. Build comparison table"
extract_vmstat() {
    awk '
        NR==2 { for(i=1;i<=NF;i++){ if($i=="si")si=i; if($i=="so")so=i; if($i=="wa")wa=i } }
        NR>2 && $1 ~ /^[0-9]+$/ { SI+=$si; SO+=$so; WA+=$wa; n++ }
        END { if(n) printf "%.1f %.1f %.1f %d\n", SI/n, SO/n, WA/n, n; else print "0 0 0 0" }
    ' "$1"
}
extract_bogo() {
    awk '
        /bogo ops\/s/        { for(i=1;i<=NF;i++) if($i=="ops/s"){ last=$(i-1) } }
        /^stress-ng: metrc:/ { last=$5 }
        END { print (last==""?0:last) }
    ' "$1"
}
read -r si_s so_s wa_s n_s < <(extract_vmstat "$EVID/evidencia-vmstat-sin-zram.txt")
read -r si_c so_c wa_c n_c < <(extract_vmstat "$EVID/evidencia-vmstat-con-zram.txt")
bogo_s=$(extract_bogo "$EVID/evidencia-stress-ng-sin-zram.txt")
bogo_c=$(extract_bogo "$EVID/evidencia-stress-ng-con-zram.txt")

cat > "$DOC" <<EOF
# Tema 2 — Swap + zram evidence ($HOST)

Generated: $(date -Iseconds)
VM RAM: ${RAM_MB} MB · workers: $WORKERS · vm-bytes: ${VM_BYTES_MB}M · duration: ${DURATION}s
Swapfile: /swap/swapfile (${SWAP_SIZE}G, NOCOW) · zram0: ram/2, zstd, prio 100

## Comparison

| Metric | Without zram | With zram | Interpretation |
|---|---|---|---|
| vmstat samples | $n_s | $n_c | |
| avg \`si\` (KB/s) | $si_s | $si_c | swap-in; lower is better |
| avg \`so\` (KB/s) | $so_s | $so_c | swap-out; lower is better |
| avg \`wa\` (%) | $wa_s | $wa_c | I/O wait; lower is better |
| stress-ng bogo ops/s | $bogo_s | $bogo_c | throughput; higher is better |

## Conclusion

With zram, the kernel swaps to compressed RAM (priority 100) before the btrfs
swapfile. This reduces disk I/O and I/O wait and increases stress-ng throughput.

## Evidence
See \`docs/evidence/tema2-$HOST/\`.
EOF

ok "wrote $DOC"
printf '  si: %s→%s  so: %s→%s  wa: %s→%s  bogo: %s→%s\n' \
    "$si_s" "$si_c" "$so_s" "$so_c" "$wa_s" "$wa_c" "$bogo_s" "$bogo_c"
