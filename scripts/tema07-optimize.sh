#!/usr/bin/env bash
# =============================================================================
# Topic 7 — boot-time optimisation (idempotent). Apply AFTER recording 3 "before" boots.
#  1. systemd-boot menu timeout 3 s -> 1 s          (shows up in the "loader" phase)
#     (hold SPACE while the VM starts to still get the menu for the rescue demo)
#     NOTE: on VirtualBox systemd-boot leaves no LoaderTime* EFI variables, so the
#     loader phase is not measurable here; the measured optimisation is the initramfs:
#  2. initramfs compression zstd -> lz4             (lz4 decompresses faster: "kernel"/"initrd" phases)
#  3. drop the "fsck" hook: the root is btrfs and fsck.btrfs is a no-op, so it only adds work
#     both via a drop-in /etc/mkinitcpio.conf.d/ instead of editing mkinitcpio.conf
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
WANT='# NeonArch Topic 7: faster initramfs (lz4 decompresses faster; no fsck hook on btrfs)
COMPRESSION="lz4"
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems)'
if [[ "$(cat "$CONF" 2>/dev/null)" == "$WANT" ]]; then
    echo "[ok]      initramfs already lz4 without fsck"
else
    grep -E '^HOOKS=' /etc/mkinitcpio.conf | tee "$OUT/hooks-before.txt"
    sudo mkdir -p /etc/mkinitcpio.conf.d
    printf '%s\n' "$WANT" | sudo tee "$CONF" >/dev/null
    sudo mkinitcpio -P 2>&1 | tee "$OUT/mkinitcpio-after.txt"
    echo "[changed] initramfs rebuilt: lz4, no fsck hook"
fi
sudo ls -l /boot/initramfs-linux.img | tee "$OUT/initramfs-after.txt"
sudo cat /boot/loader/loader.conf "$CONF" | tee "$OUT/optimisation-config.txt"
echo "Now reboot 3 times and run ./scripts/tema07-boot-measure.py after after each boot."
