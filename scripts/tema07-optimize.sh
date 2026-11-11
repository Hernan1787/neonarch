#!/usr/bin/env bash
# =============================================================================
# Topic 7 — boot-time optimisation (idempotent). Apply AFTER recording 3 "before" boots.
#  1. systemd-boot menu timeout 3 s -> 1 s          (shows up in the "loader" phase)
#     (hold SPACE while the VM starts to still get the menu for the rescue demo)
#  2. initramfs compression zstd -> lz4             (lz4 decompresses faster: "kernel"/"initrd" phases)
#     via a drop-in /etc/mkinitcpio.conf.d/ instead of editing mkinitcpio.conf
# =============================================================================
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_DIR/docs/evidence/tema-07"; mkdir -p "$OUT"
sudo -v
sudo ls -l /boot/initramfs-linux.img | tee "$OUT/initramfs-before.txt"

if sudo grep -q '^timeout[[:space:]]\+1$' /boot/loader/loader.conf; then
    echo "[ok]      loader timeout already 1 s"
else
    sudo sed -i 's/^timeout.*/timeout 1/' /boot/loader/loader.conf
    echo "[changed] loader timeout -> 1 s"
fi

pacman -Q lz4 >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm lz4
CONF=/etc/mkinitcpio.conf.d/10-neonarch.conf
if [[ -f $CONF ]] && grep -q 'COMPRESSION="lz4"' "$CONF"; then
    echo "[ok]      initramfs already lz4"
else
    sudo mkdir -p /etc/mkinitcpio.conf.d
    echo 'COMPRESSION="lz4"   # NeonArch Topic 7: faster decompression at boot' | sudo tee "$CONF" >/dev/null
    sudo mkinitcpio -P
    echo "[changed] initramfs rebuilt with lz4"
fi
sudo ls -l /boot/initramfs-linux.img | tee "$OUT/initramfs-after.txt"
sudo cat /boot/loader/loader.conf "$CONF" | tee "$OUT/optimisation-config.txt"
echo "Now reboot 3 times and run ./scripts/tema07-boot-measure.py after after each boot."
